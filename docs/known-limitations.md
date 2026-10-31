# Known Limitations

Applies to v1.0.0 - v1.0.2 unless stated. **Defect** = behavior the maintainers intend to fix (a fix is a MINOR release, see `release-process.md`). **By design** = deliberate scope of this project. The testbenches print `SVM_KNOWN_LIMITATION: KL-xxx` when they observe one; run with `SVM_STRICT_KL=1` to turn those observations into failures.

| ID | Title | Type | Since | Impact | Workaround | Planned |
|---|---|---|---|---|---|---|
| KL-001 | Overpayment change is not returned | **Defect** | v1.0.0 | After a successful purchase the balance is cleared, so `amount - price` is lost and `response.refund` is 0. Example: paying 50 for a price-30 product. | Pay the exact price | v1.1.0 (RTL-001) |
| KL-002 | Timeout forfeits the balance and the response pulse can be two clocks wide | **Defect** (latent) | v1.0.0 | On timeout `refund_reg` is forced to 0 and the balance is cleared by `complete`; `complete` is asserted for two clocks, so `response_valid` is high for two. The timer cannot expire through the public interface today (FSM completes ~7 clocks after the timer starts; timer is 20), so this is reachable only by forcing the FSM or shortening the timer. | None needed today | v1.1.0 (RTL-002) |
| KL-003 | Reset discards state | By design (to be reviewed) | v1.0.0 | Reset drops any balance and in-flight transaction with **no response and no refund**, and restores all stock to 20 and all prices to (ID+1)x10. If `rst` can be driven by an untrusted party, it can erase balances and refill stock counters. | Treat `rst` as trusted; do not reset mid-transaction | Decision D-006 |
| KL-004 | Undefined `payment_type` 6 and 7 are accepted | **Defect** | v1.0.0 | They are processed like any other type and can dispense. | Requesters must send only encodings 0-5 | v1.1.0 (RTL-003) |
| KL-005 | Only product IDs 0-4 are sellable | By design | v1.0.0 | `PRODUCT_COUNT = 5`. IDs 5-31 return `ERR_INVALID_PRODUCT`. The inventory table is built for 32 entries, so entries 5-31 exist but are unreachable. | - | Decision D-005 |
| KL-006 | CRC protects one internal path only | By design | v1.0.0 | CRC-8 (poly 0x07, init 0, MSB-first, 40-bit payload) is generated and checked inside the design over the interface-to-security-engine path. The external request carries no CRC/parity. It detects accidental corruption; it is not a MAC. `ERR_CRC` cannot be produced through the request port. | Protect the external bus upstream | Out of scope |
| KL-007 | Duplicate detection is weak and unreachable from the port | By design | v1.0.0 | Only the immediately preceding transaction ID is compared, IDs are assigned inside the design, and reset restarts them at 1. There is no replay protection and `ERR_DUPLICATE` cannot be produced through the request port. | - | Out of scope |
| KL-008 | Held-high `request_valid` repeats the purchase | By design (valid/ready) | v1.0.1 | The request has no ID. If `request_valid` stays high after acceptance, the same request is accepted again when `request_ready` returns. | Deassert `request_valid` after the accepting edge | Optional |
| KL-009 | Verification is directed simulation only | By design | v1.0.0 | No formal proof, no random testing, no assertions bound to the DUT. CRC, duplicate and timeout tests use `force` on internal signals because the conditions cannot be reached through the ports. The coin and card testbenches are near-duplicates, so their check counts overstate distinct coverage. | - | v1.1.0 (VER-002, VER-004, SEC-002) |
| KL-010 | No implementation evidence | By design | v1.0.0 | No synthesis, constraints, timing, utilization or hardware result exists. `rtl/top.sv` contains a hierarchical reference (`debug_state`) that may not synthesize in Vivado (unverified). The `debug_*` outputs expose internal balance/price/packet at the top boundary. | - | v1.2.0 (IMP-001) |

## What this project does **not** claim

- Real payment authentication (no PIN, CVV, expiry, bank authorization; the requester's `amount` is trusted).
- Cryptographic integrity or protection against a malicious requester.
- Synthesizability, timing closure or FPGA/hardware operation.
- Formal verification or exhaustive coverage.
