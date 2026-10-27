# Verification Results

## Overview

The Secure Vending Machine Controller was verified using a SystemVerilog directed self-checking verification environment. All planned verification scenarios were executed successfully using the Vivado XSIM simulator. The testbench automatically generated reports, verified DUT responses, and collected performance statistics.

---

# Simulation Environment

| Parameter | Value |
|-----------|-------|
| Simulator | Vivado XSIM |
| Verification Language | SystemVerilog |
| Verification Method | Directed Self-Checking |
| Assertions | Enabled |
| Testbench | tb_mixed_payment.sv |

---

# Verification Summary

| Metric | Result |
|--------|-------:|
| Total Tests Executed | 44 |
| Tests Passed | 44 |
| Tests Failed | 0 |
| Pass Percentage | 100% |

---

# Payment Method Verification

| Payment Method | Status |
|----------------|--------|
| Coin | ✅ Verified |
| Note | ✅ Verified |
| RFID | ✅ Verified |
| Card | ✅ Verified |
| UPI | ✅ Verified |
| Wallet | ✅ Verified |

---

# Functional Verification

The following controller functions were successfully verified.

| Feature | Status |
|----------|--------|
| Reset Operation | ✅ PASS |
| Coin Payment | ✅ PASS |
| Note Payment | ✅ PASS |
| RFID Payment | ✅ PASS |
| Card Payment | ✅ PASS |
| UPI Payment | ✅ PASS |
| Wallet Payment | ✅ PASS |
| Mixed Transactions | ✅ PASS |
| Duplicate Transaction Detection | ✅ PASS |
| CRC Error Detection | ✅ PASS |
| Timeout Detection | ✅ PASS |
| Inventory Update | ✅ PASS |
| Out-of-Stock Detection | ✅ PASS |
| Back-to-Back Transactions | ✅ PASS |

---

# Generated Reports

The verification environment automatically generated the following reports.

| Report | Description |
|---------|-------------|
| mixed_payment_report.csv | Detailed transaction log |
| simulation_summary.csv | Overall simulation statistics |
| payment_statistics.csv | Payment method analysis |
| inventory_report.csv | Final inventory status |
| error_statistics.csv | Error distribution |
| verification_report.html | Browser-based verification report |
| simulation.log | Simulation execution log |

---

# Assertions

The following assertions were evaluated during simulation.

| Assertion | Result |
|-----------|--------|
| Response outputs contain no unknown values | ✅ PASS |
| Inventory decremented after successful dispense | ✅ PASS |
| Balance cleared after transaction completion | ✅ PASS |
| Legal transaction completion | ✅ PASS |

---

# Latency Statistics

| Metric | Value |
|--------|------:|
| Minimum Latency | *9* |
| Average Latency | *12.24* |
| Maximum Latency | *9* |

> Replace the values above with the numbers reported in `simulation_summary.csv`.

---

# Error Statistics

| Error Type | Count |
|------------|------:|
| CRC Error | *1* |
| Duplicate Transaction | *1* |
| Timeout | *1* |
| Out of Stock | *3* |
| Insufficient Balance | *0* |

---

# Final Inventory Status

| Product ID | Price | Remaining Quantity | Status |
|-----------:|------:|-------------------:|--------|
| 0 | 10 | *15* | Available |
| 1 | 15 | *17* | Available |
| 2 | 20 | *18* | Available |
| 3 | 25 | *18* | Available |
| 4 | 30 | *0* | Out of Stock |

Update the table with the values from `inventory_report.csv`.

---

# Waveform Gallery

Representative waveform screenshots are available in the `waveforms/screenshots/` directory.

| Screenshot | Description |
|------------|-------------|
| 01_controller_operation.png | Working of controller |
| 02_payment_behav.png | All transaction Methods |
| 03_errors_behav.png | All error transaction |
| 04_inventory_behav.png | Inventory update |

---

# Repository Outputs

```text
reports/
├── mixed_payment_report.csv
├── simulation_summary.csv
├── payment_statistics.csv
├── inventory_report.csv
├── error_statistics.csv
├── verification_report.html
└── simulation.log
```

---

# Conclusion

The Secure Vending Machine Controller successfully passed all directed verification scenarios. The self-checking verification environment validated payment processing, security checks, inventory management, timeout handling, and response generation while automatically producing detailed reports and statistics. The verification campaign achieved a **100% pass rate**, demonstrating that the implemented functionality behaves as expected under the executed test scenarios.