# Verification Methodology — v1.0.1 Post-Audit Hardening

## Overview

The Secure Vending Machine Controller was verified using an upgraded **SystemVerilog directed self-checking verification environment**. Following a hardware security audit, the verification strategy was significantly hardened to validate the **Option A Valid/Ready Handshake Protocol**, ensure robust **response-to-request transaction tracking**, verify **pipeline immunity under in-flight contention**, and detect edge-case security vulnerabilities.

The verification environment automatically executes predefined and contention scenarios, validates DUT responses against an active transaction scoreboard, evaluates SystemVerilog assertions, collects performance statistics, and generates detailed verification reports.

---

# 1. Handshake Protocol & Driver Methodology (Option A)

The v1.0.1 architecture establishes an explicit valid/ready request handshake at the top level:

- **Signal Definition:**
  - `request_valid`: Driven by the requester.
  - `request_ready`: Driven by the controller.
- **Contract:**
  A request transaction transfer occurs strictly on the rising clock edge (`posedge clk`) where **both `request_valid` and `request_ready` are asserted (`1'b1`)**.
- **Driver Rules:**
  1. Stimulus is driven half a clock period ahead of the clock edge (on `negedge clk`).
  2. While `request_ready == 0`, the driver holds `request_valid == 1` and preserves all request payload fields (`payment_type`, `amount`, `product_id`) unchanged.
  3. The driver asserts a finite timeout watchdog (100 clock cycles) to detect deadlocks.
  4. Upon observing the accepting edge (`posedge clk iff request_ready`), the driver immediately deasserts `request_valid = 1'b0` on the subsequent `negedge clk` to prevent unintended duplicate transaction initiation.

---

# 2. Response-to-Request Association & Scoreboard

Previous testbench revisions suffered from a data race: `wait_response` and `check_result` read `request.product_id` and `request.amount` directly off the input request bus when a response arrived. If the driver had already placed a new pending request on the bus, the response checker compared against the wrong transaction.

### Active Transaction Tracking Architecture
```systemverilog
typedef struct packed {
    payment_t                       payment_type;
    logic [BALANCE_WIDTH-1:0]       amount;
    logic [PRODUCT_ID_WIDTH-1:0]    product_id;
    logic [31:0]                    inv_before;
    logic [BALANCE_WIDTH-1:0]       bal_before;
} active_txn_t;

active_txn_t active_txn;
```

- **Sampling:** On the exact accepting clock edge (`request_valid && request_ready`), `active_txn` captures the transaction payload along with the pre-transaction inventory (`qty_mem`) and balance (`current_balance`).
- **Isolation:** The response checker evaluates `resp.status`, `resp.error`, `resp.dispense`, `resp.refund`, and inventory decrement strictly against `active_txn`.
- **Response Clearing:** On entry to `wait_response`, `resp` is zero-initialized and trailing `response_valid` pulses from preceding cycles are flushed (`while (response_valid) @(posedge clk);`), eliminating stale data reuse.

---

# 3. Directed Contention Test Suite (Category 13)

To validate pipeline robustness and resolve audit finding F-01, five directed subtests were implemented:

1. **Subtest 13A (Baseline Handshake):**
   Submits an ordinary transaction; verifies exactly one acceptance event; verifies response, inventory decrement, and return to IDLE.
2. **Subtest 13B (In-Flight Contention):**
   Submits Txn 1 (CARD, 20, P1); while Txn 1 is in-flight, presents distinct Txn 2 (UPI, 30, P2); verifies `request_ready == 0` throughout execution; asserts that Txn 2 is not admitted into `payment_interface`; verifies Txn 1 completes cleanly; observes Txn 2 accepted on return to IDLE; verifies both responses and independent inventory updates.
3. **Subtest 13C (Multiple Sequential Contention Requests):**
   Sequentially exercises WALLET (P3), NOTE (P0), and RFID (P1); validates that each transaction executes with exactly one acceptance, one dispense, and correct inventory decrement.
4. **Subtest 13D (Payload Stability and Loss Checks):**
   Starts background transaction (COIN P0); presents blocked request (CARD P1) with `request_valid == 1` while `request_ready == 0`; checks payload stability across clock cycles; verifies that the blocked request is not lost and is accepted upon background completion.
5. **Subtest 13E (Reset and Recovery):**
   Verifies `request_ready == 0` during active reset; tests mid-transaction reset (balance cleared, controller forced to IDLE); verifies clean recovery transaction immediately post-reset.

---

# 4. Dedicated Security Testbench (`tb_handshake_security.sv`)

A standalone self-checking security testbench verifies design-level security rules:
- **Reset Gating:** No request accepted while `rst == 1`.
- **In-Flight Contention:** Level-sensitive security engine immunity (no duplicate error false-triggers).
- **Security Rule `ERR_AUTH`:** CARD transactions with amount > 5000 rejected with `ERR_AUTH`.
- **Security Rule `ERR_INVALID_PRODUCT`:** Requests with `product_id >= PRODUCT_COUNT` (5) rejected with `ERR_INVALID_PRODUCT`.
- **Security Rule `ERR_BALANCE`:** Requests with `amount == 0` rejected with `ERR_BALANCE`.
- **Recovery:** Clean transaction recovery after aborted transactions.

---

# 5. Regression Suite Execution

The test suite is automated via `scripts/run_regression.tcl`.

```bash
vivado -mode batch -source scripts/run_regression.tcl
```

### Regression Summary

```text
================ REGRESSION SUMMARY ================
tb_mixed_payment      PASS  SVM_TB_RESULT: PASS total=69 passed=69 failed=0 tb_errors=0
tb_coin_only          PASS  SVM_TB_RESULT: PASS total=101 passed=101 failed=0 tb_errors=0
tb_card_only          PASS  SVM_TB_RESULT: PASS total=101 passed=101 failed=0 tb_errors=0
tb_handshake_security PASS  SVM_TB_RESULT: PASS total=56 passed=56 failed=0 tb_errors=0
====================================================
RESULT: PASS
```

- Total checks across regression: **327**
- Total failures: **0**
- Testbench errors: **0**
- Overall pass rate: **100%**
