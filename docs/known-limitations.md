# Known Limitations

Applies to v1.0.0 - v1.0.2 unless stated. **Defect** = behavior the maintainers intend to fix (a fix is a MINOR release, see `release-process.md`). **By design** = deliberate scope of this project. The testbenches print `SVM_KNOWN_LIMITATION: KL-xxx` when they observe one; run with `SVM_STRICT_KL=1` to turn those observations into failures.

| ID | Title | Type | Since | Impact | Workaround | Status in v1.1.0 |
|---|---|---|---|---|---|---|
| KL-001 | Overpayment change is not returned | **Resolved** | v1.0.0 | In v1.1.0 (D-004), change is calculated as `current_balance - price` upon successful purchase and returned in `response.refund`. Exact payment returns 0 change. | None needed | **Resolved in v1.1.0** |
| KL-002 | Timeout forfeits balance and response pulse two clocks wide | **Resolved** | v1.0.0 | In v1.1.0, timeout routes active transactions through `REFUND` to `COMPLETE`, capturing customer balance into `response.refund` (KL-002A). `response_valid` pulse normalized to strictly one clock cycle (KL-002B). | None needed | **Resolved in v1.1.0** |
| KL-003 | Reset discards state | By design (to be reviewed) | v1.0.0 | Reset drops any balance and in-flight transaction with **no response and no refund**, and restores all stock to 20 and all prices to (ID+1)x10. If `rst` can be driven by an untrusted party, it can erase balances and refill stock counters. | Treat `rst` as trusted; do not reset mid-transaction | Decision D-006 |
| KL-004 | Undefined `payment_type` 6 and 7 are accepted | **Resolved** | v1.0.0 | In v1.1.0 (D-008), payment types > `WALLET` (`3'd5`) are rejected with `ERR_INVALID_PAYMENT` (`8'd8`) before balance or timeout engagement. | None needed | **Resolved in v1.1.0** |
| KL-005 | Only product IDs 0 to PRODUCT_COUNT-1 are sellable | By design | v1.0.0 | `PRODUCT_COUNT = 5`. IDs >= PRODUCT_COUNT return `ERR_INVALID_PRODUCT`. The inventory table is built for 32 entries, so entries 5-31 exist in memory but are unreachable. Parameterized in v1.0.3. | - | Decision D-005 |
| KL-006 | CRC protects one internal path only | By design | v1.0.0 | CRC-8 (poly 0x07, init 0, MSB-first, 40-bit payload) is generated and checked inside the design over the interface-to-security-engine path. The external request carries no CRC/parity. It detects accidental corruption; it is not a MAC. `ERR_CRC` cannot be produced through the request port. | Protect external bus upstream | Out of scope |
| KL-007 | Duplicate detection is weak and unreachable from the port | By design | v1.0.0 | Only the immediately preceding transaction ID is compared, IDs are assigned inside the design, and reset restarts them at 1. There is no replay protection and `ERR_DUPLICATE` cannot be produced through the request port. | - | Out of scope |
| KL-008 | Held-high `request_valid` repeats the purchase | By design (valid/ready) | v1.0.1 | The request has no ID. If `request_valid` stays high after acceptance, the same request is accepted again when `request_ready` returns (RTL-005). | Deassert `request_valid` after the accepting edge | By design |
| KL-009 | Verification is directed simulation only | By design | v1.0.0 | Simulation is directed with comprehensive self-checking regression (914 checks across 9 testbenches) and mutation testing (18/18 killed). No formal proofs bound to DUT. | Run regression suite | Enhanced in v1.1.0 |
| KL-010 | No implementation evidence | By design | v1.0.0 | No synthesis, constraints, timing, utilization or hardware result exists. The hierarchical reference was removed in v1.0.3 (D-109). | - | v1.2.0 (IMP-001) |

## Architectural & Protocol Disambiguations (v1.1.0)

- **Push-Only Response Interface:** The controller top level provides no `response_ready` backpressure input from the host. The response interface is push-only (`response_valid` pulse accompanying `response`). The host must capture the response on the single clock cycle `response_valid` is asserted.
- **RTL-006 Zero-Amount Disambiguation:** In v1.1.0 (D-009), zero-amount requests are rejected with `ERR_INVALID_AMOUNT` (`8'd9`), distinguishing amount validation from insufficient balance (`ERR_BALANCE = 8'd5`). Zero-amount validation is evaluated prior to card authentication limit checks.

## What this project does **not** claim

- Real payment authentication (no PIN, CVV, expiry, bank authorization; the requester's `amount` is trusted).
- Cryptographic integrity or protection against a malicious requester.
- Synthesizability, timing closure or FPGA/hardware operation.
- Formal verification or exhaustive coverage.
