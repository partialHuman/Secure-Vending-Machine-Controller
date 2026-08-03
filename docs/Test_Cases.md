# Test Cases

## Overview

The Secure Vending Machine Controller was verified using a directed self-checking testbench. Each test targets a specific functional requirement of the design. The testbench automatically compares the DUT response with the expected result and reports each test as **PASS** or **FAIL**.

---

# Test Case Summary

| Test ID | Test Name | Objective | Expected Result |
|---------|-----------|-----------|-----------------|
| TC-01 | Reset Verification | Verify proper DUT initialization | DUT returns to idle state with cleared balance |
| TC-02 | Coin Payment | Verify successful coin transaction | Product dispensed successfully |
| TC-03 | Note Payment | Verify successful note transaction | Product dispensed successfully |
| TC-04 | RFID Payment | Verify successful RFID transaction | Product dispensed successfully |
| TC-05 | Card Payment | Verify successful card transaction | Product dispensed successfully |
| TC-06 | UPI Payment | Verify successful UPI transaction | Product dispensed successfully |
| TC-07 | Wallet Payment | Verify successful wallet transaction | Product dispensed successfully |
| TC-08 | Mixed Transactions | Verify different payment methods sequentially | All transactions complete successfully |
| TC-09 | Duplicate Transaction | Verify duplicate transaction detection | ERR_DUPLICATE generated |
| TC-10 | CRC Error | Verify CRC validation | ERR_CRC generated |
| TC-11 | Stock Depletion | Verify inventory decrement | Product quantity decreases after each purchase |
| TC-12 | Out of Stock | Verify stock availability check | ERR_STOCK generated |
| TC-13 | Back-to-Back Transactions | Verify consecutive transactions | All transactions processed correctly |
| TC-14 | Timeout | Verify timeout handling | STATUS_TIMEOUT generated |

---

# Detailed Test Cases

## TC-01 Reset Verification

### Objective

Verify that the controller initializes correctly after reset.

### Procedure

- Assert reset
- Wait several clock cycles
- Release reset

### Expected Result

- Balance = 0
- Controller enters idle state
- No dispense signal
- No refund

---

## TC-02 Coin Payment

### Objective

Verify successful purchase using coin payment.

### Procedure

- Select product
- Insert sufficient coin amount
- Wait for transaction completion

### Expected Result

- STATUS_SUCCESS
- ERR_NONE
- Dispense asserted
- Inventory decremented

---

## TC-03 Note Payment

### Objective

Verify successful purchase using note payment.

### Expected Result

- STATUS_SUCCESS
- Product dispensed
- Inventory updated

---

## TC-04 RFID Payment

### Objective

Verify successful RFID transaction.

### Expected Result

- STATUS_SUCCESS
- No error
- Product dispensed

---

## TC-05 Card Payment

### Objective

Verify successful card transaction.

### Expected Result

- STATUS_SUCCESS
- Product dispensed

---

## TC-06 UPI Payment

### Objective

Verify successful UPI transaction.

### Expected Result

- STATUS_SUCCESS
- Product dispensed

---

## TC-07 Wallet Payment

### Objective

Verify successful digital wallet transaction.

### Expected Result

- STATUS_SUCCESS
- Product dispensed

---

## TC-08 Mixed Transactions

### Objective

Verify controller operation with multiple payment methods.

### Procedure

Execute transactions using:

- Coin
- Note
- RFID
- Card
- UPI
- Wallet

### Expected Result

Each payment mode completes successfully.

---

## TC-09 Duplicate Transaction

### Objective

Verify duplicate transaction detection.

### Procedure

- Send valid transaction
- Repeat same Transaction ID

### Expected Result

- STATUS_FAILED
- ERR_DUPLICATE

---

## TC-10 CRC Error

### Objective

Verify CRC validation.

### Procedure

Corrupt transaction CRC before processing.

### Expected Result

- STATUS_FAILED
- ERR_CRC

---

## TC-11 Stock Depletion

### Objective

Verify inventory update after successful purchases.

### Procedure

Purchase the same product repeatedly.

### Expected Result

- Quantity decreases after each purchase.

---

## TC-12 Out of Stock

### Objective

Verify out-of-stock detection.

### Procedure

Attempt to purchase an unavailable product.

### Expected Result

- STATUS_FAILED
- ERR_STOCK

---

## TC-13 Back-to-Back Transactions

### Objective

Verify processing of consecutive transactions.

### Procedure

Execute multiple transactions without long delays.

### Expected Result

Every transaction completes correctly.

---

## TC-14 Timeout

### Objective
Verify timeout detection.

### Procedure

Allow a transaction to exceed the timeout period.

### Expected Result

- STATUS_TIMEOUT
- ERR_TIMEOUT

---

# Test Coverage Matrix

| Feature | Test Case |
|----------|-----------|
| Reset | TC-01 |
| Coin Payment | TC-02 |
| Note Payment | TC-03 |
| RFID Payment | TC-04 |
| Card Payment | TC-05 |
| UPI Payment | TC-06 |
| Wallet Payment | TC-07 |
| Mixed Payment Processing | TC-08 |
| Duplicate Detection | TC-09 |
| CRC Validation | TC-10 |
| Inventory Update | TC-11 |
| Stock Detection | TC-12 |
| Consecutive Transactions | TC-13 |
| Timeout Handling | TC-14 |

---

# Verification Outcome

| Total Test Cases | Passed | Failed | Pass Rate |
|-----------------:|-------:|-------:|----------:|
| 44 | 44 | 0 | 100% |

---

# Conclusion

All planned directed verification scenarios were executed successfully. The self-checking testbench automatically validated the DUT responses, and every implemented feature—including payment processing, security checks, inventory management, and timeout handling—passed verification with a **100% pass rate**.