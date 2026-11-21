# Phase 0 — Baseline Audit for v1.0.3

Supersedes my earlier draft (written from pasted text, before the tagged archive was supplied).
**Status: audit only. Nothing in your repository, archive or working tree was modified.** The archive was extracted to a separate temporary directory.

## 1. Source identity

| Item | Value | How established |
|---|---|---|
| File | `v1_0_2-source.zip` | supplied |
| Size / files | 717,113 bytes / 69 files | `stat`, `find` |
| SHA-256 | `0145c92a96effcb7c74769e2e93ad5f1940b9232ac3f45768e1666f1cb514bdf` | `sha256sum` |
| Embedded commit id (zip comment written by `git archive`) | `6f7ab63bd007580f287de0fb42985b9cfbd770c0` | `unzip -z` — **equals the tag target in your prompt** |
| Integrity | `unzip -t` clean | tool output |
| `.git` in archive | none (as expected for `git archive`) | listing |
| Line endings | **all 51 text files are CRLF; 0 LF-only, 0 mixed** | byte scan |

What this does and does not prove: the embedded id shows the archive was exported from commit `6f7ab63…`. I **cannot run `git rev-parse "v1.0.2^{commit}"`**, so I cannot independently prove the annotated tag `v1.0.2` points there; that rests on your statement.

## 2. Git and working-tree state — NOT VERIFIED

My environment has no repository and no way to reach yours. None of the commands in prompt §8 could be run by me. Maintainer-supplied earlier observations (**treat as stale until re-run**):

| Item | Reported earlier |
|---|---|
| Branch / HEAD | `docs/release-readiness` / `5f9f96b15b7519f7710542fa7512fa8bca3e58f9` |
| Modified | `.gitignore` (genuine change) |
| Untracked | `planning/`, `reports/v1.0.0_snapshot/` |
| `rtl/top.sv` | transient "modified" cleared by `git update-index --refresh` (blob hashes matched) |

**Please run and send** (PowerShell, from the repository root):
```powershell
git status --short --branch; git diff --stat; git diff --cached --stat; git log --oneline -5
git tag -l -n; git rev-parse "v1.0.2^{commit}"; git rev-parse HEAD
git diff --stat v1.0.2 HEAD -- rtl tb scripts docs
```
The last line matters: it shows whether the branch you intend to base v1.0.3 on differs from the tag in any file this release touches (decision D-113).

### Archive vs live repository (what is knowable)
| Difference | Evidence |
|---|---|
| The tag has the v1.0.0 report files at `reports/` top level; your live tree reportedly has them moved/copied to untracked `reports/v1.0.0_snapshot/` | archive `reports/` listing vs your report |
| `docs/roadmap.md` in the tag still says "maintainer approval is pending for staging and release tagging" although the tag exists | roadmap L20, L24 |
| `planning/` exists only in the live tree | your report |
| Live branch HEAD is not the tag commit | your report |
Everything else about the live tree is **unknown to me**.

## 3. Files actually inspected

All 11 RTL files; all 4 testbenches (headers, helper tasks, every `qty_mem`/`price_mem`/`u_inventory_manager` use, product-ID tests); `scripts/run_regression.tcl` (all 303 lines), `expected_checks.txt`, `README.md`, `compile.tcl`/`simulate.tcl`/`run_all.tcl` (existence and reference search); `.gitignore`; `README.md`, `CHANGELOG.md`, `CITATION.cff`; `docs/` (Architecture, Protocol Specification, verification, known-limitations, roadmap, release-process; others by reference search only); `.github/`. Reports/images: listed, not analysed. **Not inspected:** the live repository, any Vivado output, any probe results (none supplied).

## 4. Confirmed from source

### 4.1 RTL is unchanged since v1.0.1
All 11 RTL files are identical to the v1.0.1 archive (compared with CR/LF stripped). So the v1.0.2 verification record applies to exactly this RTL.

### 4.2 Two unlinked product-count definitions
| Definition | Location | Consumers |
|---|---|---|
| `parameter int PRODUCT_COUNT = 5` | `transaction_pkg.sv:17` | `security_engine.sv:130` (`packet.product_id >= PRODUCT_COUNT`); `tb_mixed_payment.sv:1762,1771,1783`; docs |
| `parameter PRODUCTS = 32` | `inventory_manager.sv:4`; arrays `:51-52` `[0:PRODUCTS-1]`; reset loop `:66` | `top.sv:213` instantiates it **with no parameter override** |

- `product_id` in the inventory is hard-coded `[4:0]` (`inventory_manager.sv:16`), not `PRODUCT_ID_WIDTH`.
- `transaction_controller.sv` contains **no product-count use** → no change needed there (confirms the prompt's "do not parameterize unless needed").
- Inventory accesses are unguarded: write `:82,:89`, decrement `:95-96`, read `:127-134`. They are safe today only because depth is 32 (= full 5-bit range) **and** the security engine filters IDs. Nothing guards them locally.
- The literal `5` at `inventory_manager.sv:134` (`low_stock = qty <= 5`) is a low-stock **threshold**, not a product count; it must not be unified with the count.
- `secure_packet.product_id` only ever holds an ID that passed security (or `0` after reset), so invalid IDs cannot reach the inventory today. The guard is defense-in-depth, not a bug fix.

### 4.3 Reference search (RTL, TB, Tcl, docs; no constraint or project files exist)
| Identifier | References | Consequence |
|---|---|---|
| `arbiter_ready` | `top.sv:47` (unused wire), `:122` (interface connection), `:140` (arbiter output → unused wire), `:255` (controller); `transaction_controller.sv:30,395`; `payment_interface.sv:22,80`; `payment_arbiter.sv:11,29,54`; `docs/Architecture.md:29` | Three meanings; **no TB, Tcl script or constraint references it** → rename of controller/interface ports is safe. The arbiter's own output name stays meaningful. |
| `debug_state` | `top.sv:91` (declaration), `:308` (hierarchical assign); `docs/known-limitations.md` KL-010 text | **no other reference** → removal safe; KL-010 wording must be updated |
| `PRODUCT_COUNT` (package) | see 4.2; `docs/Architecture.md:27,31`, `Protocol Specification.md:87,157`, `known-limitations.md` KL-005, legacy `Results.md`/`Verification_Methodology.md` | rename ripple to 3 TB loops and ~6 doc lines |
| `PRODUCTS` | `inventory_manager.sv` only (+ legacy `Results.md:86-87`) | safe to replace |

### 4.4 Testbench hazards for shrinking the inventory table
| ID | Evidence | Effect if table depth becomes `PRODUCT_COUNT` |
|---|---|---|
| H-1 | `tb_handshake_security.sv:158` `send_request` reads `qty_mem[product]` for **every** request (called with IDs 10, 5, 31 at `:416,:520,:521`) | out-of-range read → X into `inv_before` (not checked, but may warn) |
| H-2 | `:227,:236` `run_case` reads `qty_mem[product]` before/after, for IDs 5 and 31 | `X == q_before` is false → **the "inventory change" check would fail with no RTL defect** |
| H-3 | `tb_mixed_payment.sv:1762,1771,1783` use the package name | compile error if renamed without editing |
| H-4 | hierarchical references into the inventory: 12 (coin), 12 (card), 15 (handshake), 34 (mixed) | instance and array names are **protected identifiers** |
| H-5 | coin/card TBs use only IDs 0–4 | unaffected |

### 4.5 Runner (`scripts/run_regression.tcl`) facts that constrain the plan
1. `valid_tbs` is hard-coded to the 4 legacy names (L40); `load_manifest` rejects any other manifest name (L100-102).
2. Manifest names must match `[a-zA-Z0-9_]+` (L94).
3. Step 2 requires `xvlog` **and** `xelab` to exit 0 before simulating (L240-241): there is **no path for an expected-failure test**.
4. **Defect risk for D-106:** `SVM_UPDATE_MANIFEST=1` rewrites the *entire* manifest from only the testbenches observed in that run (L292-297). A bootstrap run with `SVM_TBS=<new tb>` would **delete the legacy 102/102/220/73 entries**. The runner must be changed to merge, or bootstrap must be done by hand.
5. `parse_tb_result` demands exactly one `SVM_TB_RESULT` line and `xsim` exit 0 (L126-184); `SVM_ONLY_PROCS` hook (L187) allows unit-testing the procs.

### 4.6 Recorded baseline (maintainer evidence, **not reproduced by me**)
`docs/verification.md` records: Vivado 2018.2 XSIM (SW Build 2258646), Windows 11 Pro, 2026-10-31, `tb_coin_only 102`, `tb_card_only 102`, `tb_handshake_security 220`, `tb_mixed_payment 73` = **497/497 PASS**, summary SHA-256 `199e7b08…c0e7`. `scripts/expected_checks.txt` matches (CRLF). `tb_mixed_payment` reports `KL-002` observed. In an earlier pass I re-derived 73/102/102/220 statically from the testbench source; that shows source/manifest consistency, not a pass.

## 5. Not verified (and why)

| Item | Reason |
|---|---|
| Baseline regression result | no Vivado/Tcl in my environment |
| Git branch/HEAD/tag state | no repository |
| D-102 (Vivado 2018.2 elaboration-rejection behaviour) | **no probe results supplied**; none of the probe files exists as a result log |
| Any lint result | Vivado, Verilator, others unavailable |
| Actual array depth introspection (`$size`, `$bits`, OOB read) | needs probe E |

## 6. Static lint-oriented review (reading only; **no tool run**) and classification

Categories per prompt: **F** fix in v1.0.3 · **D** existing issue deferred · **T** requires tool verification · **O** out of scope. A heuristic script scan (usage counts, reset presence, `case` defaults, blocking-in-`always_ff`, multi-driver) supported the reading; its one multi-driver hit (`qty_mem`) is a false positive (a `<=` *comparison* at `inventory_manager.sv:134`; `qty_mem` is written only in the single `always_ff`).

| ID | Sev | File:line | Finding | Class | Handling |
|---|---|---|---|---|---|
| L-01 | Medium | `inventory_manager.sv:82,89,95-96,127-134` | Unguarded table access (array bounds) | **F** | local `id_valid` guard (Task A) |
| L-02 | Low | `top.sv:47,140` | Unused wire `arbiter_ready` | **F** | remove (Task B) |
| L-03 | Low | `top.sv:91,308` | `debug_state`: unused wire assigned through a hierarchical reference | **F** | remove if D-109 confirmed |
| L-04 | Low | `security_engine.sv:32-33` | `security_ok_reg`, `security_error_reg` declared, **never referenced** (new finding) | **F (needs D-110)** | remove declarations |
| L-05 | Low | `balance_manager.sv:39,98` | blocking `temp_sum =` in `always_ff` | **D / T** | defer per D-105; a lint tool would flag it, but its timing was not re-analysed |
| L-06 | Low | `transaction_controller.sv` output `case` (ends ~L368) | no `default`; `ERROR_STATE` unreachable. The next-state `case` (L185) has a default | **D** | no FSM change in a PATCH; document |
| L-07 | Low | `inventory_manager.sv:68` | `(i+1)*10` 32-bit → 16-bit implicit truncation (safe for ≤32 entries) | **D** | note only; a cast needs a syntax probe and changes nothing |
| L-08 | Info | `security_engine.sv:130` | 5-bit unsigned vs signed `int` compare (resolves unsigned; correct) | **T** | use unsigned effective count; confirm with lint |
| L-09 | Info | `top.sv:205,206,232,234` | unconnected `overflow`, `underflow`, `stock_available`; `low_stock`/`quantity` only feed debug outputs | **O** | debug/unreachable logic; changing would alter debug outputs |
| L-10 | Info | `payment_arbiter.sv` default branch | `packet_reg <= packet_reg` self-assignment | **O** | harmless |
| L-11 | Info | `transaction_pkg.sv` | `DATA_WIDTH`, `CRC_WIDTH`, `STATUS_WIDTH`, `ERROR_WIDTH` unreferenced outside the package; `command_t`, `inventory_entry_t` unused | **O** | package API; leave |
| L-12 | Info | all `always_ff` | every sequential block references `rst` (reset consistency OK by scan) | **T** | confirm with lint |
| L-13 | Info | `crc8.sv:4` | default `DATA_WIDTH = 32` while both instances override to 40 | **O** | leave |

Not established by tool (so **not claimed**): latch freedom, multiple-driver freedom, width-warning status, signedness warnings, synthesizability.

## 7. Phase 0 risks and dependencies

| Risk | Mitigation |
|---|---|
| Base commit ambiguity (tag vs `docs/release-readiness` HEAD) | D-113: maintainer chooses the base; patches are generated against the **tag** and re-based on request |
| Elaboration-rejection support unknown | probes A–E (see `probes/README.md`) before Phase 2 |
| Runner manifest-update behaviour can delete legacy entries | plan change R-1 (merge semantics) with a unit test via `SVM_ONLY_PROCS` |
| CRLF files: careless edits create whole-file diffs | patches generated with CRLF preserved; verify with `git diff --stat` |
| Check-count drift | 497 must reproduce exactly |

## 8. Phase 0 exit

D-102 is **unresolved** (no probe evidence) and no tool is available to me. Per prompt §5, Phase 2 must not begin until the probe results and the git state are provided and decisions are approved.
