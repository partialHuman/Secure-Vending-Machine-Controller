# Verification Results — v1.0.1 Post-Audit Hardening

## Overview

The Secure Vending Machine Controller has undergone comprehensive hardening and verification following a hardware security audit. The complete SystemVerilog verification suite was executed using the installed **Vivado 2018.2 XSIM** simulator.

All four testbenches in the regression suite passed with **zero failures and zero testbench errors**.

---

# 1. Regression Summary

| Testbench | Scope / Purpose | Total Checks | Passed | Failed | TB Errors | Result |
|---|---|---:|---:|---:|---:|:---:|
| `tb_mixed_payment` | All payment modes, sequential mix, security faults, stock depletion, and complete contention suite (13A-13E) | 69 | 69 | 0 | 0 | **PASS** |
| `tb_coin_only` | Dedicated coin channel, exact/over/under/zero payments, stress purchases, handshake back-to-back | 101 | 101 | 0 | 0 | **PASS** |
| `tb_card_only` | Dedicated card channel, auth checks, exact/over/under payments, stress purchases, handshake back-to-back | 101 | 101 | 0 | 0 | **PASS** |
| `tb_handshake_security` | Dedicated security suite: Option A contract, reset gating, in-flight contention, ERR_AUTH, ERR_INVALID_PRODUCT, ERR_BALANCE | 56 | 56 | 0 | 0 | **PASS** |
| **TOTAL** | **Full System Regression Suite** | **327** | **327** | **0** | **0** | **PASS** |

> All results were executed directly in Vivado 2018.2 via `scripts/run_regression.tcl`.

---

# 2. Handshake & Contention Suite (Category 13)

The previous unverified back-to-back test was replaced by five rigorous directed subtests verifying the Option A Valid/Ready handshake contract, active transaction tracking, pipeline immunity, and state recovery:

| Subtest | Scenario Tested | Key Invariants Verified | Status |
|---|---|---|:---:|
| **Subtest 13A** | Single Transaction Baseline | Synchronous posedge acceptance where `request_valid && request_ready`; full response and inventory verification; clean return to IDLE | **PASS** |
| **Subtest 13B** | Second Request Under Contention | Txn 1 (CARD, 20, P1) accepted; Txn 2 (UPI, 30, P2) presented while busy; `request_ready == 0` during execution; Txn 2 payload stable; Txn 1 completes cleanly; Txn 2 accepted on return to IDLE; both responses and inventory decrements verified | **PASS** |
| **Subtest 13C** | Multiple Sequential Contention Requests | Three distinct transactions (WALLET P3, NOTE P0, RFID P1) driven via Option A handshake; exactly one acceptance each; independent inventory decrements verified | **PASS** |
| **Subtest 13D** | Stability and Loss Prevention | Background Txn (COIN P0) started; blocked request (CARD P1) held with `request_valid == 1` while `request_ready == 0`; payload asserted unchanged across multiple cycles; blocked request accepted cleanly upon background completion; both responses verified | **PASS** |
| **Subtest 13E** | Reset Deassertion and Recovery | `request_ready == 0` during reset; IDLE restored on reset release; mid-transaction reset clears active balance to 0 and forces IDLE; clean post-reset recovery transaction verified | **PASS** |

---

# 3. Response-to-Request Association

Previous testbenches inferred product identity and pricing by reading `request.product_id` and `request.amount` directly off the input request bus when a response arrived. If the testbench updated `request` while a previous transaction was finishing, response validation was corrupted.

In v1.0.1, all testbenches implement disciplined single-outstanding-transaction scoreboards:
- The accepted transaction's `payment_type`, `amount`, `product_id`, pre-transaction inventory (`inv_before`), and pre-transaction balance (`bal_before`) are latched into an `active_txn` record on the exact posedge clk where `request_valid && request_ready == 1`.
- The response checker (`check_result` and `wait_response`) validates status, error code, dispense signal, refund amount, and inventory updates solely against `active_txn`.
- `resp` is explicitly cleared to `'0` upon entry to `wait_response`, and trailing `response_valid` pulses are flushed, preventing stale response reuse.

---

# 4. Latency Statistics (`tb_mixed_payment`)

| Metric | Cycles | Real Time (ns) | Notes |
|---|---:|---:|---|
| Minimum Latency | 9 cycles | 90 ns | Fast-reject transactions (zero coin, invalid product) |
| Typical Latency | 10–12 cycles | 100–120 ns | Standard successful dispense & complete sequence |
| Maximum Latency | 27 cycles | 270 ns | FSM timeout watchdog transaction |

---

# 5. Inventory & Resource State

Final inventory quantities across all 5 products at the conclusion of `tb_mixed_payment`:

| Product ID | Unit Price | Initial Qty | Final Qty | Units Sold | Status |
|---:|---:|---:|---:|---:|---|
| 0 | 10 | 20 | 19 | 1 | Available (Post-Reset clean recovery) |
| 1 | 20 | 20 | 20 | 0 | Available |
| 2 | 30 | 20 | 20 | 0 | Available |
| 3 | 40 | 20 | 20 | 0 | Available |
| 4 | 50 | 20 | 20 | 0 | Available |

*(Note: Test 13E asserts mid-test synchronous reset, resetting inventory memory to initial 20 units; subsequent recovery transaction sold 1 unit of Product 0).*

---

# 6. Audit Findings & Remaining Architectural Risks

The following adjacent security issues and architectural observations were analyzed during this verification campaign:

1. **Top-Level `request_ready` Back-Pressure Gate (Resolved in v1.0.1):**
   The internal pipeline lacks per-stage backpressure: `security_engine` treats `out_valid` as a level, not a transfer handshake. The top-level gate `request_ready = !rst && controller_ready && !packet_valid && !out_valid && !security_done;` successfully guarantees that at most one transaction enters the pipeline. Contention tests confirm that presenting requests while busy results in zero pipeline corruption and zero duplicate/CRC false rejects.
2. **Overpayment Refund Limitation (Architectural Finding):**
   In `balance_manager.sv`, when `amount_in > required_amount`, the design computes `refund_amount = current_balance - required_amount;`. However, in `transaction_controller.sv`, successful purchases transition `CHECK_INVENTORY -> DISPENSE -> COMPLETE` without transitioning to `REFUND`. Consequently, `response_generator.sv` only attaches `refund_amount` if `refund == 1'b1`. Therefore, for successful overpayments, excess funds are not refunded in the response packet.
3. **Timeout Refund Limitation (Architectural Finding):**
   If a timeout fires before `secure_valid` pulses (i.e. before balance has been loaded into `balance_manager`), the customer receives `STATUS_TIMEOUT` with `refund = 0`. If balance had already been loaded, `refund_amount` is generated.
4. **Parameter Discrepancy (`PRODUCT_COUNT` vs `PRODUCTS`):**
   `transaction_pkg.sv` defines `PRODUCT_COUNT = 5`, while `inventory_manager.sv` is parameterized with `PRODUCTS = 32`. In `security_engine.sv`, incoming requests are checked against `packet.product_id >= PRODUCT_COUNT`. As verified by `tb_handshake_security`, product IDs 5 through 31 are rejected with `ERR_INVALID_PRODUCT`.
5. **Invalid Payment Encodings (Architectural Finding):**
   `payment_t` is a 3-bit enum with values 0 through 5 defined. Binary values 6 and 7 (`3'b110` and `3'b111`) are not checked in `security_engine.sv`. If driven, they pass security checks and enter the FSM as unrecognized payment modes.
6. **Duplicate Transaction Detection Scope:**
   `security_engine.sv` checks `packet.transaction_id == last_transaction_id`. This only detects immediate back-to-back identical IDs; historical duplicates or non-consecutive replays are not caught by this single register.

---

# 7. Verification Verdict

All required v1.0.1 audit fixes and verification enhancements are implemented and verified. The full regression suite achieves a **100% pass rate (327/327 checks)** under Vivado 2018.2 XSIM with complete integrity accounting.
