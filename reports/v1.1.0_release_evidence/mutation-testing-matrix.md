# v1.1.0 Mutation Testing Matrix & Results

- **Campaign Date:** 2026-11-21 / 2026-11-24
- **Tool:** Xilinx Vivado 2018.2 / XSIM
- **Total Mutations:** 18
- **Killed:** 18
- **Survived:** 0
- **Invalid:** 0
- **Mutation Score:** **100.0%** (18/18)

## 1. Summary by RTL Module

| Category | Target RTL File | Total | Killed | Survived | Score | Killer Suite |
|---|---|:---:|:---:|:---:|:---:|---|
| Balance Manager | `rtl/balance_manager.sv` | 5 | 5 | 0 | 100.0% | `tb_unit_balance` |
| Security Engine | `rtl/security_engine.sv` | 5 | 5 | 0 | 100.0% | `tb_unit_security` |
| Transaction Controller | `rtl/transaction_controller.sv` | 4 | 4 | 0 | 100.0% | `tb_unit_timeout` |
| Response Generator | `rtl/response_generator.sv` | 4 | 4 | 0 | 100.0% | `tb_unit_timeout` |
| **Total** | | **18** | **18** | **0** | **100.0%** | |

---

## 2. Detailed Mutation Catalog & Killing Evidence

| Mutation ID | Module | Injected Mutation Description | Expected Killer | Result | Detection Signature |
|:---|:---|:---|:---|:---:|:---|
| `MUT-BM-01` | `balance_manager.sv` | Off-by-one arithmetic in addition (`balance_sum = current_balance + amount_in + 1'b1`) | `tb_unit_balance` | **KILLED** | `Error: [BAL_TEST FAIL] BM-UNIT: Add 50 results in balance 50` |
| `MUT-BM-02` | `balance_manager.sv` | Overflow saturation disabled (`balance_sum[BALANCE_WIDTH]` check bypassed to allow wrap-around) | `tb_unit_balance` | **KILLED** | `Error: [BAL_TEST FAIL] BM-UNIT: Overflow flag asserted on 16-bit boundary` |
| `MUT-BM-03` | `balance_manager.sv` | Forced change refund to zero on successful purchase (`refund_amount <= '0` on `sub_en`) | `tb_unit_balance` | **KILLED** | `Error: [BAL_TEST FAIL] BM-UNIT: sub_en captures change (50-30=20)` |
| `MUT-BM-04` | `balance_manager.sv` | Forced refund to zero on transaction abort/timeout (`refund_amount <= '0` on `refund_en`) | `tb_unit_balance` | **KILLED** | `Error: [BAL_TEST FAIL] BM-UNIT: refund_en captures balance to refund_amount` |
| `MUT-BM-05` | `balance_manager.sv` | Premature balance clearing prior to refund capture (`refund_amount <= '0` on concurrent clear) | `tb_unit_balance` | **KILLED** | `Error: [BAL_TEST FAIL] BM-UNIT: refund_en captures balance to refund_amount` |
| `MUT-SE-01` | `security_engine.sv` | Bypassed payment type upper bound validation (accepted undefined type 6/7) | `tb_unit_security` | **KILLED** | `Error: [SEC_TEST FAIL] SEC-PT6: Type 6 rejected with ERR_INVALID_PAYMENT` |
| `MUT-SE-02` | `security_engine.sv` | Disabled zero-amount validation check (`amount == 0` check bypassed) | `tb_unit_security` | **KILLED** | `Error: [SEC_TEST FAIL] SEC-ZA: Amount 0 rejected with ERR_INVALID_AMOUNT` |
| `MUT-SE-03` | `security_engine.sv` | Bypassed CRC-8 verification check (packet passed despite CRC mismatch) | `tb_unit_security` | **KILLED** | `Error: [SEC_TEST FAIL] SEC-CRC: Corrupted CRC rejected with ERR_CRC` |
| `MUT-SE-04` | `security_engine.sv` | Bypassed duplicate transaction token check (accepted identical transaction ID) | `tb_unit_security` | **KILLED** | `Error: [SEC_TEST FAIL] SEC-DUP: Consecutive identical ID rejected with ERR_DUPLICATE` |
| `MUT-SE-05` | `security_engine.sv` | Bypassed product ID range check (accepted `product_id >= PRODUCT_COUNT`) | `tb_unit_security` | **KILLED** | `Error: [SEC_TEST FAIL] SEC-BOUND: Product ID 5 rejected with ERR_INVALID_PRODUCT` |
| `MUT-TC-01` | `transaction_controller.sv` | Bypassed timeout refund routing in `CHECK_BALANCE` (routed directly to `COMPLETE`) | `tb_unit_timeout` | **KILLED** | `Error: [TIMEOUT_TEST FAIL] TC-INT: Timeout refund is 50 (KL-002A resolved)` |
| `MUT-TC-02` | `transaction_controller.sv` | Suppressed timeout status/error code in `REFUND` state output logic | `tb_unit_timeout` | **KILLED** | `Error: [TIMEOUT_TEST FAIL] TC-INT: Status is STATUS_TIMEOUT` |
| `MUT-TC-03` | `transaction_controller.sv` | Permitted product dispense on timeout (`dispense_pulse <= 1'b1`) | `tb_unit_timeout` | **KILLED** | `Error: [TIMEOUT_TEST FAIL] TC-INT: Dispense is 0 on timeout` |
| `MUT-TC-04` | `transaction_controller.sv` | Reintroduced duplicate refund pulse in `COMPLETE` state (`refund_pulse <= 1'b1`) | `tb_unit_timeout` | **KILLED** | `Error: [TIMEOUT_TEST FAIL] TC-SEQ: Consecutive underpayment status (refund monitor)` |
| `MUT-RG-01` | `response_generator.sv` | Forced change refund to zero in output response packet (`refund_latched <= '0` on dispense) | `tb_unit_timeout` | **KILLED** | `Error: [TIMEOUT_TEST FAIL] TC-SEQ: Consecutive overpayment refund is 20` |
| `MUT-RG-02` | `response_generator.sv` | Suppressed timeout refund propagation in output response packet | `tb_unit_timeout` | **KILLED** | `Error: [TIMEOUT_TEST FAIL] TC-INT: Timeout refund is 50 (KL-002A resolved)` |
| `MUT-RG-03` | `response_generator.sv` | Stretched `response_valid` pulse width across multiple clock cycles (`complete \|\| response_valid`) | `tb_unit_timeout` | **KILLED** | `SVM_TB_RESULT: FAIL global watchdog expired` / pulse width check assertion |
| `MUT-RG-04` | `response_generator.sv` | Generated duplicate `response_valid` pulse on refund | `tb_unit_timeout` | **KILLED** | `Error: [TIMEOUT_TEST FAIL] TC-INT: Timeout refund is 50` / pulse width violation |

---

## 3. Verification Method & Isolation

All mutations were evaluated using an isolated scratch workspace environment with independent build targets. Each mutant was compiled and elaborated with standard Xilinx Vivado 2018.2 / XSIM toolchain commands, run against the corresponding killer testbench, and checked for exit codes and failure detection signatures.
