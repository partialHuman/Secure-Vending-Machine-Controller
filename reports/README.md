# reports/

This directory holds **release evidence**. The CSV, HTML, and log files in this directory are historical evidence from the **v1.0.0** simulation run (44 checks). They are preserved for historical continuity and auditability. **Do not quote them as results for v1.0.1 or v1.0.2.**

## Generating current v1.0.2 reports

```bash
SVM_REQUIRE_MANIFEST=1 vivado -mode batch -source scripts/run_regression.tcl
```

Reports are written to `build/reports/<testbench>/` (git-ignored); `build/PROVENANCE.txt` records date, OS, git commit, and tool version.

## Historical v1.0.0 reports (superseded)

The root CSV, HTML, and log files in `reports/` come from the v1.0.0 run (44 checks) and were left byte-for-byte unchanged in v1.0.1. They are kept only as history. Known problems in them:

- The `Time(ns)` columns and "Simulation Time ... ns" are in **picoseconds** (e.g. `4935000` is 4935 ns). Fixed in the v1.0.1+ testbench (`$timeformat`).
- `verification_coverage.csv` marked every feature PASS unconditionally, including "Back-to-Back Transactions", whose test only checked that the controller returned to IDLE. The final inventory (`15/17/18/18/0`) is consistent with the v1.0.0 defect in which a second request overwrote the one in flight (fixed in v1.0.1).
- The `CRC` column showed the CRC of the last packet that *passed* the security engine, so it was stale for rejected packets.
- Internal-check rows printed `000-` in the CRC column and `0` in the quantity columns; the HTML transaction table had a row with a missing cell and a meaningless "Total Transactions 100%" row.
- "Total Transactions 37" counted `check_result` calls, not DUT transactions.
- Latency was measured from before the request was driven (one clock more than from the accepting edge).
