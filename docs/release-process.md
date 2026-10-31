# Release Process

Semantic Versioning (`MAJOR.MINOR.PATCH`) with the project-specific rules below.

## 1. What is compatible

| Tier | Contents | Breaking change means |
|---|---|---|
| Stable | `top` port names/widths/directions; request/response struct layout and enum encodings; handshake rules in `Protocol Specification.md`; the `SVM_TB_RESULT:` marker; `scripts/run_regression.tcl` entry point | MAJOR |
| Provisional | `debug_*` outputs, report file names/columns, regression environment variables | MINOR with a changelog entry |
| Internal | Submodule ports, internal signals, `dut.u_*` hierarchical paths, testbench internals | Any release |

## 2. Version increments

| Change | Bump |
|---|---|
| Documentation, testbench, script changes; fixes that restore documented behavior without changing outputs for previously valid inputs | PATCH |
| Fix of a **known limitation listed as Defect** in `known-limitations.md` that changes outputs; additive port or enum value; new supported flow | MINOR (with a "Behavior change" entry) |
| Change of struct layout/width, enum encoding, port name/width, or protocol rule | MAJOR |

Rule: a behavior-changing fix may be MINOR only if the behavior was published as a Defect in an earlier release. A security correction follows the same table and always gets a "Security" entry.

Release candidates `-rc.N` are used only for behavior-changing MINOR/MAJOR releases. No alpha/beta tags. Engineering milestones (M-A...) are not versions.

## 3. Branches, tags, Releases

- `main` is always releasable; work in short-lived `fix/`, `feat/`, `docs/`, `ver/` branches merged by pull request.
- Tags are **annotated** (`git tag -a vX.Y.Z -m "..."`) on the reviewed commit and are **never moved, deleted or reused**. A wrong release is superseded by the next PATCH; edit the old Release notes, not the tag.
- A GitHub Release body = that version's changelog section + Known limitations + Compatibility; attach `regression-summary.txt`, the per-testbench logs, `PROVENANCE.txt` and the reports.
- Hotfix: branch from the tag (`hotfix/X.Y.Z+1`), add a test that fails before the fix, run the full gate, tag, publish.

## 4. Release gates

| # | Gate | Evidence |
|---|---|---|
| G1 | Fresh clone, run from a directory outside the repo: `vivado -mode batch -source scripts/run_regression.tcl` exits 0 | `build/regression-summary.txt` |
| G2 | Every testbench PASS and its check count equals `scripts/expected_checks.txt` (use `SVM_REQUIRE_MANIFEST=1`) | summary |
| G3 | A deliberately broken RTL copy fails the regression (mutation smoke test; verified for v1.0.2 candidate via inventory decrement mutation; must be rerun for any future release that modifies RTL or testbenches) | log |
| G4 | RTL change has a test; behavior change updates Protocol/known-limitations/changelog | PR |
| G5 | `reports/` regenerated from this commit; `PROVENANCE.txt` present; stale files removed | files |
| G6 | Numbers in README/verification copied from the summary; version strings consistent (`CHANGELOG.md`, `CITATION.cff`, protocol header); links valid | review |
| G7 | Known limitations and breaking/behavior changes recorded | changelog |
| G8 | Lint clean (once CI exists); synthesis evidence only if claimed | log |
| G9 | Annotated tag at the reviewed commit; assets attached | GitHub |

## 5. Checklist (copy into the release PR)

- [ ] Bump justified (PATCH / MINOR / MAJOR): ______; defect rule satisfied
- [ ] `[Unreleased]` changelog entries moved under the new version with a date
- [ ] G1-G9 evidence attached or marked N/A with a reason
- [ ] `CITATION.cff` `version` and `date-released` updated
- [ ] README status numbers pasted from `regression-summary.txt`
- [ ] `docs/verification.md` section 9 updated
- [ ] Tag created, pushed, Release published with assets and checksums
- [ ] Follow-up issues opened for anything deferred

## 6. Verification-results record (paste into `docs/verification.md` section 9)

```
Release: vX.Y.Z   Commit: <sha>   Date: YYYY-MM-DD
Tool: <xsim -version first line>   OS: <os>
Command: vivado -mode batch -source scripts/run_regression.tcl
| Testbench | Checks | Result |
Known limitations observed: <KL ids>
```
Numbers are pasted from `build/regression-summary.txt`, never typed.
