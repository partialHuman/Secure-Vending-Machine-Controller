# v1.1.0 Testbench Inventory & Gap Closure

| Testbench | Level | Checks | Primary Invariants Verified | Notes / Gap Closure |
|---|---|:---:|---|---|
| `tb_card_only` | System Integration | 102 | Dedicated card payments, authentication limits, overpayment change, zero payment | Aligned zero-amount assertion to `ERR_INVALID_AMOUNT` |
| `tb_coin_only` | System Integration | 102 | Coin payments, exact/over/under payments, stock depletion, stress purchases | Aligned zero-amount assertion to `ERR_INVALID_AMOUNT` |
| `tb_handshake_security` | System Integration | 220 | Option A valid/ready handshake, reset gating, contention, boundary values | Aligned zero-amount assertion to `ERR_INVALID_AMOUNT` |
| `tb_inventory_manager` | Unit / Subsystem | 65 | Price lookup, stock decrement, out-of-stock signaling, bounds checks | Inherited from v1.0.3 baseline |
| `tb_mixed_payment` | System Integration | 73 | Mixed payment types, duplicate tokens, CRC corruption, stock exhaustion | System-level integration regression |
| `tb_product_count` | Unit / Parameter | 133 | Dynamic catalog parameter sweep (PRODUCT_COUNT 1..32) | Parameterized architecture validation |
| `tb_unit_timeout` | Unit / Integration | 134 | Timeout balance refund (KL-002A), 1-cycle pulse monitor (KL-002B), boundary state transitions | Resolves Gap 4.1 (multi-cycle / edge transitions, balance non-inheritance) and Gap 4.2 (10-scenario monitor) |
| `tb_unit_security` | Unit | 19 | Direct stimulation of security engine: CRC error, duplicate token, zero-amount precedence, type 6/7 rejection | Pure port-level unit verification eliminating `force` |
| `tb_unit_balance` | Unit | 66 | Balance accumulation, overflow saturation, change subtraction (D-004), timeout refund, clear priority | Unit verification for balance manager |
| **Total Suite** | | **914** | | **9 passing testbenches + 2 passing negative elaboration tests** |
