# Reconciled Decision Register — v1.0.3

**Project:** Secure Vending Machine Controller (v1.0.3 Patch Release)  
**Baseline Tag:** `v1.0.2` (Commit: `6f7ab63bd007580f287de0fb42985b9cfbd770c0`)  
**Approval Milestone:** Approved by Maintainer on 2026-11-17 / 2026-11-18 (Conditional on N=33 evidence; condition now satisfied)  
**Implementation Phase Status:** **Phase 2 NOT YET BEGUN** (Awaiting explicit maintainer authorization to open Phase 2)

---

## 1. Decision Status Summary Table

| ID | Topic | Recommendation | Technical Evidence | Technical Status | Maintainer Approval Status | Final Status |
|---|---|---|---|---|---|---|
| **D-101** | Rename package count constant | **Accept:** `PRODUCT_COUNT` → `PRODUCT_COUNT_DEFAULT` (=5); add `PRODUCT_COUNT_MAX = 2**PRODUCT_ID_WIDTH` (=32) | Two unlinked definitions confirmed in audit (`transaction_pkg.sv:17`, `inventory_manager.sv:4`); ripples limited to 3 TB loops and ~6 doc lines | Verified | **Approved** | **Ready** |
| **D-102** | Reject invalid counts (0, 33) | **Accept Mechanism 2:** Undefined module instantiation in unselected generate branch (`PRODUCT_COUNT_OUT_OF_RANGE_see_docs`) | **Vivado 2018.2 Empirical Evidence:** Probe A ($error) fails (downgraded to warning, exit 0). Probe B rejects N=0 (exit 1, VRFC 10-2063). Extra Probe B rejects N=33 (exit 1, VRFC 10-2063). Valid N=5 and N=32 elaborate cleanly (exit 0) | Verified (Probes A, B, B-N33) | **Approved** (Approved conditional on N=33; condition verified) | **Ready** |
| **D-103** | Inventory table depth & clamp | **Accept:** Depth = configured count; elaboration-safe `PC_SAFE` clamp prevents illegal array bounds | Probe E verified relevant SystemVerilog language features (package constant functions, `$size`, `$bits`, out-of-range reads on unpacked arrays, hierarchical localparam access). Actual `inventory_manager` array depth and parameter propagation have not been verified in RTL and are Phase 2 verification requirements | Language features verified (Probe E); RTL depth pending Phase 2 | **Approved** | **Ready** |
| **D-104** | Internal ready naming | **Accept (Limited):** Controller `arbiter_ready` → `idle`; interface `arbiter_ready` → `accept_ready`; delete unused top wire; keep arbiter's own output; no external ports renamed | Repo-wide search confirmed zero references in TB/Tcl/constraints | Verified | **Approved** (Within stated limits) | **Ready** |
| **D-105** | `temp_sum` refactor | **Defer:** Retain current logic in `balance_manager.sv`; no behavior-preservation claim without tool issue | Timing not re-analysed; unnecessary churn | Preserved | **Approved (Deferral confirmed)** | **Deferred** |
| **D-106** | Manifest update logic | **Accept:** Controlled bootstrap; runner update becomes strictly merge-only; legacy counts (102/102/220/73) preserved | Audit of `run_regression.tcl:292-297` confirmed destructive overwrite risk without merge logic | Verified | **Approved** | **Ready** |
| **D-107** | Count 32 support | **Accept:** Count 32 is valid (IDs 0–31 sellable; `ERR_INVALID_PRODUCT` unreachable by design) | Probe D confirmed `2**W` parameter math; Probe B N=32 control elaborated cleanly | Verified | **Approved** | **Ready** |
| **D-108** | Invalid inventory ID behavior | **Accept:** Out-of-range reads return safe zero outputs; invalid writes and decrements are ignored | Probes D and E demonstrated isolated guarded-index and out-of-range read behavior in standalone probe modules. Actual `inventory_manager` invalid-access behavior has not yet been tested in RTL; direct unit tests in `tb_inventory_manager.sv` (including per-entry memory snapshots before and after invalid operations) are Phase 2 verification requirements | Language features verified (Probes D/E); RTL unit test pending Phase 2 | **Approved** | **Ready** |
| **D-109** | Remove `debug_state` | **Accept:** Remove unused hierarchical wire and assignment from `rtl/top.sv` | Repo-wide search found only `top.sv:91,308` and KL-010 doc text | Verified | **Approved** | **Ready** |
| **D-110** | Remove dead security registers | **Accept:** Remove unused declarations `security_ok_reg`, `security_error_reg` | Scan of `security_engine.sv:32-33` confirmed dead declarations | Verified | **Approved** | **Ready** |
| **D-111** | Regression runner improvements | **Accept:** Add negative-test path checking `xelab` exit code 1 and error `VRFC 10-2063`; add new TBs to `valid_tbs`; make manifest update merge-only | Runner code audit and probe execution semantics verified | Verified | **Approved** | **Ready** |
| **D-112** | Historical doc banners | **Accept:** Add a one-line historical banner to legacy docs (`Results.md`, `Verification_Methodology.md`); do not rewrite historical files | Audit identified historical references to `PRODUCTS = 32` | Verified | **Approved** | **Ready** |
| **D-113** | Base commit for maintenance | **Accept:** Base `maintenance/v1.0.3` on v1.0.2 Git tag commit `6f7ab63bd007580f287de0fb42985b9cfbd770c0` | `v1_0_2-source.zip` embedded commit matches tag target exactly | Verified | **Approved** | **Ready** |
| **D-114** | `CITATION.cff` update timing | **Defer:** Update version and citation date only at release readiness, not during implementation | Avoid mid-development metadata churn | Preserved | **Approved (Deferral confirmed)** | **Deferred** |

---

## 2. Distinction of Evidence and Approval Status

* **Technical Evidence Status:** Measures whether toolchain experiments, source scans, or audits have confirmed the feasibility and safety of the proposed design choice. All active decisions (D-101..D-104, D-106..D-113) are technically verified.
* **Maintainer Approval Status:** Represents the formal governance signoff from the project maintainer. As recorded in this checkpoint, the maintainer has approved all rows (with D-102 approved conditional on N=33, which is now verified, and D-105/D-114 explicitly deferred).
* **Implementation Phase Boundary:** Approval of the Decision Register authorizes the technical specifications for Phase 2, but Phase 2 code implementation remains paused pending explicit maintainer authorization to open Phase 2.
