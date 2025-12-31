cmd/cli/commands/account_deposit.go
cmd/cli/commands/account_withdraw.go
cmd/cli/commands/account_transfer.go
cmd/cli/commands/account_list.go
```

**Implementation Steps:**
1. Set up Cobra CLI framework
2. Implement each command
3. Add interactive mode
4. Add demo data generation
5. Test manually

**Usage Example:**
```bash
# Create account
./cli account create --name "Test Account" --tenant tenant-1

# Deposit
./cli account deposit --account acc-123 --amount 100.00 --currency USD

# Withdraw
./cli account withdraw --account acc-123 --amount 50.00 --currency USD

# Transfer
./cli account transfer --from acc-123 --to acc-456 --amount 25.00 --currency USD

# List accounts
./cli account list --tenant tenant-1

# Interactive mode
./cli account interactive
```

**Verification:**
- Manual testing of all commands
- Verify data in database

---

## Phase 5: Exchange Domain (Critical)

**Duration:** Weeks 9-11 (3 weeks)
**Goal:** Implement trading engine with order matching, liquidity pools, and market making
**Dependencies:** Phase 2 (Account), Phase 3 (Payment)

**PHP Reference:**
- `app/Domain/Exchange/` (144 files)
- 48 domain events
- 17 workflow activities
- 3 aggregates (Order, OrderBook, LiquidityPool)
- 3 projectors
- 5 workflows
- 3 sagas
- 2 external connectors (Binance, Kraken)

---

### Task 5.1: Order Value Objects

**Task ID:** P5-EXCHANGE-001

**Description:** Implement Order-related value objects (OrderType, OrderSide, OrderStatus, Price, Quantity)

**Priority:** Critical

**Estimated Complexity:** M (4-8h)

**Dependencies:**
- P1-SHARED-001 (Money)

**Acceptance Criteria:**
- [ ] OrderType enum (Market, Limit, Stop, StopLimit)
- [ ] OrderSide enum (Buy, Sell)
- [ ] OrderStatus enum (Pending, PartiallyFilled, Filled, Cancelled, Rejected)
- [ ] Price value object with currency pair
- [ ] Quantity value object with decimal precision
- [ ] TradingPair value object (base/quote currencies)
- [ ] Validation logic
- [ ] JSON marshaling/unmarshaling
- [ ] Unit tests (>90% coverage)

**Files to Create:**
```
internal/domain/exchange/valueobject/order_type.go
internal/domain/exchange/valueobject/order_side.go
internal/domain/exchange/valueobject/order_status.go
internal/domain/exchange/valueobject/price.go
internal/domain/exchange/valueobject/quantity.go
internal/domain/exchange/valueobject/trading_pair.go
internal/domain/exchange/valueobject/valueobject_test.go
```

**Implementation Steps:**
1. Define OrderType enum:
   ```go
   type OrderType string

   const (
       OrderTypeMarket    OrderType = "market"
       OrderTypeLimit     OrderType = "limit"
       OrderTypeStop      OrderType = "stop"
       OrderTypeStopLimit OrderType = "stop_limit"
   )

   func (ot OrderType) IsValid() bool {
       switch ot {
       case OrderTypeMarket, OrderTypeLimit, OrderTypeStop, OrderTypeStopLimit:
           return true
       }
       return false
   }
   ```

2. Define OrderSide:
   ```go
   type OrderSide string

   const (
       OrderSideBuy  OrderSide = "buy"
       OrderSideSell OrderSide = "sell"
   )
   ```

3. Define OrderStatus with state transitions:
   ```go
   type OrderStatus string

   const (
       OrderStatusPending         OrderStatus = "pending"
       OrderStatusPartiallyFilled OrderStatus = "partially_filled"
       OrderStatusFilled          OrderStatus = "filled"
       OrderStatusCancelled       OrderStatus = "cancelled"
       OrderStatusRejected        OrderStatus = "rejected"
   )

   func (os OrderStatus) CanTransitionTo(newStatus OrderStatus) bool {
       // Define valid state transitions
       validTransitions := map[OrderStatus][]OrderStatus{
           OrderStatusPending: {
               OrderStatusPartiallyFilled,
               OrderStatusFilled,
               OrderStatusCancelled,
               OrderStatusRejected,
           },
           OrderStatusPartiallyFilled: {
               OrderStatusFilled,
               OrderStatusCancelled,
           },
       }

       allowed, ok := validTransitions[os]
       if !ok {
           return false
       }

       for _, status := range allowed {
           if status == newStatus {
               return true
           }
       }
       return false
   }
   ```

4. Define Price:
   ```go
   type Price struct {
       Amount       decimal.Decimal
       TradingPair  TradingPair
   }

   func NewPrice(amount decimal.Decimal, pair TradingPair) (Price, error) {
       if amount.LessThanOrEqual(decimal.Zero) {
           return Price{}, ErrInvalidPrice
       }
       return Price{Amount: amount, TradingPair: pair}, nil
   }
   ```

5. Define Quantity with asset precision
6. Define TradingPair (e.g., BTC/USD)
7. Write comprehensive tests

**Testing:**
```go
func TestOrderTypeValidation(t *testing.T) {
    assert.True(t, OrderTypeMarket.IsValid())
    assert.True(t, OrderTypeLimit.IsValid())
    assert.False(t, OrderType("invalid").IsValid())
}

func TestOrderStatusTransitions(t *testing.T) {
    // Valid transition
    assert.True(t, OrderStatusPending.CanTransitionTo(OrderStatusPartiallyFilled))

    // Invalid transition
    assert.False(t, OrderStatusFilled.CanTransitionTo(OrderStatusPending))
}

func TestPriceCreation(t *testing.T) {
    pair := NewTradingPair("BTC", "USD")
    price, err := NewPrice(decimal.NewFromInt(50000), pair)
    assert.NoError(t, err)
    assert.Equal(t, decimal.NewFromInt(50000), price.Amount)
}

func TestInvalidPrice(t *testing.T) {
    pair := NewTradingPair("BTC", "USD")
    _, err := NewPrice(decimal.Zero, pair)
    assert.Error(t, err)
    assert.Equal(t, ErrInvalidPrice, err)
}
```

**Verification Command:**
```bash
go test -v ./internal/domain/exchange/valueobject/
```

**PHP Reference:**
- `app/Domain/Exchange/ValueObjects/`
- Order-related constants throughout Exchange domain

---

### Task 5.2: Order Aggregate

**Task ID:** P5-EXCHANGE-002

**Description:** Implement Order aggregate with event sourcing

**Priority:** Critical

**Estimated Complexity:** L (8-16h)

**Dependencies:**
- P5-EXCHANGE-001
- P1-SHARED-010 (AggregateRoot)

**Acceptance Criteria:**
- [ ] Order aggregate struct
- [ ] Business methods: PlaceOrder, MatchOrder, PartialFill, CancelOrder
- [ ] Events: OrderPlaced, OrderMatched, OrderPartiallyFilled, OrderFilled, OrderCancelled
- [ ] Event application methods
- [ ] Business rule validations (quantity > 0, price > 0, etc.)
- [ ] Filled quantity tracking
- [ ] Remaining quantity calculation
- [ ] Unit tests (>90% coverage)

**Files to Create:**
```
internal/domain/exchange/aggregate/order.go
internal/domain/exchange/aggregate/order_test.go
internal/domain/exchange/event/order_placed.go
internal/domain/exchange/event/order_matched.go
internal/domain/exchange/event/order_partially_filled.go
internal/domain/exchange/event/order_filled.go
internal/domain/exchange/event/order_cancelled.go
```

**Implementation Steps:**
1. Define Order aggregate:
   ```go
   type Order struct {
       *aggregate.AggregateRoot

       orderID          string
       accountID        string
       tradingPair      valueobject.TradingPair
       orderType        valueobject.OrderType
       orderSide        valueobject.OrderSide
       price            valueobject.Price  // nil for market orders
       quantity         valueobject.Quantity
       filledQuantity   decimal.Decimal
       remainingQuantity decimal.Decimal
       status           valueobject.OrderStatus
       metadata         map[string]interface{}
   }
   ```

2. Implement PlaceOrder:
   ```go
   func PlaceOrder(
       orderID, accountID string,
       pair valueobject.TradingPair,
       orderType valueobject.OrderType,
       side valueobject.OrderSide,
       price *valueobject.Price,  // nil for market orders
       quantity valueobject.Quantity,
       metadata map[string]interface{},
   ) (*Order, error) {
       // Validation
       if orderType == valueobject.OrderTypeLimit && price == nil {
           return nil, ErrLimitOrderRequiresPrice
       }
       if orderType == valueobject.OrderTypeMarket && price != nil {
           return nil, ErrMarketOrderCannotHavePrice
       }

       o := &Order{
           AggregateRoot: aggregate.NewAggregateRoot(orderID, "Order"),
       }

       o.RecordThat(OrderPlaced{
           OrderID:     orderID,
           AccountID:   accountID,
           TradingPair: pair,
           OrderType:   orderType,
           OrderSide:   side,
           Price:       price,
           Quantity:    quantity,
           Metadata:    metadata,
           Timestamp:   time.Now(),
       })

       return o, nil
   }
   ```

3. Implement PartialFill:
   ```go
   func (o *Order) PartialFill(fillQuantity decimal.Decimal, fillPrice decimal.Decimal, matchID string) error {
       if o.status != valueobject.OrderStatusPending &&
          o.status != valueobject.OrderStatusPartiallyFilled {
           return ErrOrderCannotBeFilled
       }

       if fillQuantity.GreaterThan(o.remainingQuantity) {
           return ErrFillQuantityExceedsRemaining
       }

       newFilledQuantity := o.filledQuantity.Add(fillQuantity)
       newRemainingQuantity := o.quantity.Amount.Sub(newFilledQuantity)

       var event interface{}
       if newRemainingQuantity.IsZero() {
           event = OrderFilled{
               OrderID:       o.orderID,
               FillQuantity:  fillQuantity,
               FillPrice:     fillPrice,
               TotalFilled:   newFilledQuantity,
               MatchID:       matchID,
               Timestamp:     time.Now(),
           }
       } else {
           event = OrderPartiallyFilled{
               OrderID:          o.orderID,
               FillQuantity:     fillQuantity,
               FillPrice:        fillPrice,
               TotalFilled:      newFilledQuantity,
               RemainingQuantity: newRemainingQuantity,
               MatchID:          matchID,
               Timestamp:        time.Now(),
           }
       }

       o.RecordThat(event)
       return nil
   }
   ```

4. Implement CancelOrder:
   ```go
   func (o *Order) Cancel(reason string) error {
       if o.status == valueobject.OrderStatusFilled {
           return ErrCannotCancelFilledOrder
       }
       if o.status == valueobject.OrderStatusCancelled {
           return ErrOrderAlreadyCancelled
       }

       o.RecordThat(OrderCancelled{
           OrderID:   o.orderID,
           Reason:    reason,
           Timestamp: time.Now(),
       })

       return nil
   }
   ```

5. Implement event application methods:
   ```go
   func (o *Order) ApplyOrderPlaced(event OrderPlaced) {
       o.orderID = event.OrderID
       o.accountID = event.AccountID
       o.tradingPair = event.TradingPair
       o.orderType = event.OrderType
       o.orderSide = event.OrderSide
       o.price = event.Price
       o.quantity = event.Quantity
       o.filledQuantity = decimal.Zero
       o.remainingQuantity = event.Quantity.Amount
       o.status = valueobject.OrderStatusPending
       o.metadata = event.Metadata
   }

   func (o *Order) ApplyOrderPartiallyFilled(event OrderPartiallyFilled) {
       o.filledQuantity = event.TotalFilled
       o.remainingQuantity = event.RemainingQuantity
       o.status = valueobject.OrderStatusPartiallyFilled
   }

   func (o *Order) ApplyOrderFilled(event OrderFilled) {
       o.filledQuantity = event.TotalFilled
       o.remainingQuantity = decimal.Zero
       o.status = valueobject.OrderStatusFilled
   }

   func (o *Order) ApplyOrderCancelled(event OrderCancelled) {
       o.status = valueobject.OrderStatusCancelled
   }
   ```

6. Write comprehensive tests

**Testing:**
```go
func TestPlaceMarketOrder(t *testing.T) {
    pair := valueobject.NewTradingPair("BTC", "USD")
    quantity := valueobject.NewQuantity(decimal.NewFromFloat(0.5))

    order, err := PlaceOrder(
        "order-123",
        "acc-456",
        pair,
        valueobject.OrderTypeMarket,
        valueobject.OrderSideBuy,
        nil,  // market order has no price
        quantity,
        nil,
    )

    assert.NoError(t, err)
    assert.Equal(t, valueobject.OrderStatusPending, order.status)
    assert.Equal(t, quantity.Amount, order.remainingQuantity)
}

func TestPlaceLimitOrder(t *testing.T) {
    pair := valueobject.NewTradingPair("BTC", "USD")
    price, _ := valueobject.NewPrice(decimal.NewFromInt(50000), pair)
    quantity := valueobject.NewQuantity(decimal.NewFromFloat(0.5))

    order, err := PlaceOrder(
        "order-123",
        "acc-456",
        pair,
        valueobject.OrderTypeLimit,
        valueobject.OrderSideBuy,
        &price,
        quantity,
        nil,
    )

    assert.NoError(t, err)
    assert.Equal(t, price, *order.price)
}

func TestLimitOrderWithoutPrice(t *testing.T) {
    pair := valueobject.NewTradingPair("BTC", "USD")
    quantity := valueobject.NewQuantity(decimal.NewFromFloat(0.5))

    _, err := PlaceOrder(
        "order-123",
        "acc-456",
        pair,
        valueobject.OrderTypeLimit,
        valueobject.OrderSideBuy,
        nil,  // invalid - limit order needs price
        quantity,
        nil,
    )

    assert.Error(t, err)
    assert.Equal(t, ErrLimitOrderRequiresPrice, err)
}

func TestPartialFill(t *testing.T) {
    order := setupTestOrder(t)

    // Partial fill of 0.2 BTC
    err := order.PartialFill(
        decimal.NewFromFloat(0.2),
        decimal.NewFromInt(50000),
        "match-1",
    )

    assert.NoError(t, err)
    assert.Equal(t, valueobject.OrderStatusPartiallyFilled, order.status)
    assert.Equal(t, decimal.NewFromFloat(0.2), order.filledQuantity)
    assert.Equal(t, decimal.NewFromFloat(0.3), order.remainingQuantity)
}

func TestCompleteFill(t *testing.T) {
    order := setupTestOrder(t)  // 0.5 BTC order

    // Fill entire order
    err := order.PartialFill(
        decimal.NewFromFloat(0.5),
        decimal.NewFromInt(50000),
        "match-1",
    )

    assert.NoError(t, err)
    assert.Equal(t, valueobject.OrderStatusFilled, order.status)
    assert.Equal(t, decimal.NewFromFloat(0.5), order.filledQuantity)
    assert.True(t, order.remainingQuantity.IsZero())
}

func TestCancelOrder(t *testing.T) {
    order := setupTestOrder(t)

    err := order.Cancel("user requested")
    assert.NoError(t, err)
    assert.Equal(t, valueobject.OrderStatusCancelled, order.status)
}

func TestCannotCancelFilledOrder(t *testing.T) {
    order := setupTestOrder(t)
    order.PartialFill(decimal.NewFromFloat(0.5), decimal.NewFromInt(50000), "match-1")

    err := order.Cancel("user requested")
    assert.Error(t, err)
    assert.Equal(t, ErrCannotCancelFilledOrder, err)
}

func TestOrderReconstitution(t *testing.T) {
    store := setupTestEventStore(t)

    // Create and fill order
    order := setupTestOrder(t)
    order.PartialFill(decimal.NewFromFloat(0.2), decimal.NewFromInt(50000), "match-1")
    order.Persist(context.Background(), store)

    // Retrieve and reconstitute
    retrieved := &Order{AggregateRoot: aggregate.NewAggregateRoot("order-123", "Order")}
    err := retrieved.Retrieve(context.Background(), store, "order-123")

    assert.NoError(t, err)
    assert.Equal(t, valueobject.OrderStatusPartiallyFilled, retrieved.status)
    assert.Equal(t, decimal.NewFromFloat(0.2), retrieved.filledQuantity)
}
```

**Verification Command:**
```bash
go test -v ./internal/domain/exchange/aggregate/
```

**PHP Reference:**
- `app/Domain/Exchange/Aggregates/Order.php` (inferred from events)
- `app/Domain/Exchange/Events/OrderPlaced.php`
- `app/Domain/Exchange/Models/Order.php` (projection)

---

### Task 5.3: Liquidity Pool Aggregate

**Task ID:** P5-EXCHANGE-003

**Description:** Implement LiquidityPool aggregate with AMM (Automated Market Maker)

**Priority:** Critical

**Estimated Complexity:** XL (16+ hours)

**Dependencies:**
- P5-EXCHANGE-001
- P1-SHARED-010 (AggregateRoot)
- P2-ACCOUNT-001 (for account references)

**Acceptance Criteria:**
- [ ] LiquidityPool aggregate struct
- [ ] Constant product AMM formula (x * y = k)
- [ ] Business methods: CreatePool, AddLiquidity, RemoveLiquidity, ExecuteSwap
- [ ] Events: PoolCreated, LiquidityAdded, LiquidityRemoved, SwapExecuted, PoolFeeCollected
- [ ] Reserve balances tracking (base and quote)
- [ ] LP token shares calculation
- [ ] Slippage protection
- [ ] Price impact calculation
- [ ] Fee collection (0.3% default)
- [ ] Unit tests (>90% coverage)

**Files to Create:**
```
internal/domain/exchange/aggregate/liquidity_pool.go
internal/domain/exchange/aggregate/liquidity_pool_test.go
internal/domain/exchange/event/pool_created.go
internal/domain/exchange/event/liquidity_added.go
internal/domain/exchange/event/liquidity_removed.go
internal/domain/exchange/event/swap_executed.go
internal/domain/exchange/event/pool_fee_collected.go
internal/domain/exchange/valueobject/pool_fee.go
```

**Implementation Steps:**
1. Define LiquidityPool aggregate:
   ```go
   type LiquidityPool struct {
       *aggregate.AggregateRoot

       poolID           string
       tradingPair      valueobject.TradingPair
       baseReserve      decimal.Decimal
       quoteReserve     decimal.Decimal
       totalShares      decimal.Decimal
       feeRate          decimal.Decimal  // e.g., 0.003 for 0.3%
       providers        map[string]decimal.Decimal  // accountID -> shares
       k                decimal.Decimal  // constant product (x * y)
   }
   ```

2. Implement CreatePool:
   ```go
   func CreatePool(
       poolID string,
       pair valueobject.TradingPair,
       initialBaseAmount, initialQuoteAmount decimal.Decimal,
       feeRate decimal.Decimal,
       creatorAccountID string,
   ) (*LiquidityPool, error) {
       if initialBaseAmount.LessThanOrEqual(decimal.Zero) ||
          initialQuoteAmount.LessThanOrEqual(decimal.Zero) {
           return nil, ErrInvalidInitialLiquidity
       }

       if feeRate.LessThan(decimal.Zero) || feeRate.GreaterThan(decimal.NewFromFloat(0.1)) {
           return nil, ErrInvalidFeeRate
       }

       lp := &LiquidityPool{
           AggregateRoot: aggregate.NewAggregateRoot(poolID, "LiquidityPool"),
       }

       // Initial shares = sqrt(baseAmount * quoteAmount)
       initialShares := initialBaseAmount.Mul(initialQuoteAmount).Sqrt()

       lp.RecordThat(PoolCreated{
           PoolID:            poolID,
           TradingPair:       pair,
           InitialBase:       initialBaseAmount,
           InitialQuote:      initialQuoteAmount,
           InitialShares:     initialShares,
           FeeRate:           feeRate,
           CreatorAccountID:  creatorAccountID,
           Timestamp:         time.Now(),
       })

       return lp, nil
   }
   ```

3. Implement AddLiquidity:
   ```go
   func (lp *LiquidityPool) AddLiquidity(
       accountID string,
       baseAmount, quoteAmount decimal.Decimal,
   ) error {
       if baseAmount.LessThanOrEqual(decimal.Zero) ||
          quoteAmount.LessThanOrEqual(decimal.Zero) {
           return ErrInvalidLiquidityAmount
       }

       // Calculate required ratio
       currentRatio := lp.baseReserve.Div(lp.quoteReserve)
       providedRatio := baseAmount.Div(quoteAmount)

       // Allow 0.5% tolerance
       tolerance := decimal.NewFromFloat(0.005)
       ratioDiff := currentRatio.Sub(providedRatio).Abs()
       maxDiff := currentRatio.Mul(tolerance)

       if ratioDiff.GreaterThan(maxDiff) {
           return ErrImbalancedLiquidity
       }

       // Calculate new shares: shares = (baseAmount / baseReserve) * totalShares
       newShares := baseAmount.Div(lp.baseReserve).Mul(lp.totalShares)

       lp.RecordThat(LiquidityAdded{
           PoolID:       lp.poolID,
           AccountID:    accountID,
           BaseAmount:   baseAmount,
           QuoteAmount:  quoteAmount,
           SharesIssued: newShares,
           Timestamp:    time.Now(),
       })

       return nil
   }
   ```

4. Implement ExecuteSwap (constant product AMM):
   ```go
   func (lp *LiquidityPool) ExecuteSwap(
       accountID string,
       inputCurrency string,  // "base" or "quote"
       inputAmount decimal.Decimal,
       minOutputAmount decimal.Decimal,  // slippage protection
   ) (decimal.Decimal, error) {
       if inputAmount.LessThanOrEqual(decimal.Zero) {
           return decimal.Zero, ErrInvalidSwapAmount
       }

       var outputAmount decimal.Decimal
       var newBaseReserve, newQuoteReserve decimal.Decimal

       // Apply fee (0.3% default)
       fee := inputAmount.Mul(lp.feeRate)
       inputAmountAfterFee := inputAmount.Sub(fee)

       if inputCurrency == "base" {
           // Buying quote with base
           // k = baseReserve * quoteReserve (constant)
           // newBaseReserve = baseReserve + inputAmountAfterFee
           // newQuoteReserve = k / newBaseReserve
           // outputAmount = quoteReserve - newQuoteReserve

           newBaseReserve = lp.baseReserve.Add(inputAmountAfterFee)
           newQuoteReserve = lp.k.Div(newBaseReserve)
           outputAmount = lp.quoteReserve.Sub(newQuoteReserve)
       } else {
           // Buying base with quote
           newQuoteReserve = lp.quoteReserve.Add(inputAmountAfterFee)
           newBaseReserve = lp.k.Div(newQuoteReserve)
           outputAmount = lp.baseReserve.Sub(newBaseReserve)
       }

       // Slippage protection
       if outputAmount.LessThan(minOutputAmount) {
           return decimal.Zero, ErrSlippageExceeded
       }

       // Calculate price impact
       priceImpact := lp.calculatePriceImpact(inputCurrency, inputAmount, outputAmount)

       lp.RecordThat(SwapExecuted{
           PoolID:          lp.poolID,
           AccountID:       accountID,
           InputCurrency:   inputCurrency,
           InputAmount:     inputAmount,
           OutputCurrency:  oppositeOf(inputCurrency),
           OutputAmount:    outputAmount,
           FeeCollected:    fee,
           PriceImpact:     priceImpact,
           NewBaseReserve:  newBaseReserve,
           NewQuoteReserve: newQuoteReserve,
           Timestamp:       time.Now(),
       })

       return outputAmount, nil
   }

   func (lp *LiquidityPool) calculatePriceImpact(
       inputCurrency string,
       inputAmount, outputAmount decimal.Decimal,
   ) decimal.Decimal {
       var currentPrice, executionPrice decimal.Decimal

       if inputCurrency == "base" {
           currentPrice = lp.quoteReserve.Div(lp.baseReserve)
           executionPrice = outputAmount.Div(inputAmount)
       } else {
           currentPrice = lp.baseReserve.Div(lp.quoteReserve)
           executionPrice = outputAmount.Div(inputAmount)
       }

       // Price impact = |currentPrice - executionPrice| / currentPrice * 100
       impact := currentPrice.Sub(executionPrice).Abs()
       return impact.Div(currentPrice).Mul(decimal.NewFromInt(100))
   }
   ```

5. Implement RemoveLiquidity
6. Implement event application methods
7. Write comprehensive tests

**Testing:**
```go
func TestCreatePool(t *testing.T) {
    pair := valueobject.NewTradingPair("BTC", "USD")

    pool, err := CreatePool(
        "pool-123",
        pair,
        decimal.NewFromInt(10),        // 10 BTC
        decimal.NewFromInt(500000),    // 500,000 USD
        decimal.NewFromFloat(0.003),   // 0.3% fee
        "acc-creator",
    )

    assert.NoError(t, err)
    assert.Equal(t, "pool-123", pool.poolID)

    // Initial shares = sqrt(10 * 500000) = sqrt(5000000) ≈ 2236.07
    expectedShares := decimal.NewFromInt(10).Mul(decimal.NewFromInt(500000)).Sqrt()
    assert.True(t, pool.totalShares.Equal(expectedShares))
}

func TestSwapBasicAMM(t *testing.T) {
    pool := setupTestPool(t)  // 10 BTC, 500,000 USD

    // Swap 1 BTC for USD
    // k = 10 * 500000 = 5,000,000
    // newBase = 10 + 1 = 11
    // newQuote = 5,000,000 / 11 ≈ 454,545.45
    // output = 500,000 - 454,545.45 ≈ 45,454.55 USD (before fee)

    outputAmount, err := pool.ExecuteSwap(
        "acc-trader",
        "base",
        decimal.NewFromInt(1),
        decimal.NewFromInt(40000),  // min output for slippage protection
    )

    assert.NoError(t, err)
    assert.True(t, outputAmount.GreaterThan(decimal.NewFromInt(45000)))
    assert.True(t, outputAmount.LessThan(decimal.NewFromInt(46000)))
}

func TestSwapSlippageProtection(t *testing.T) {
    pool := setupTestPool(t)

    // Set unrealistic minimum output
    _, err := pool.ExecuteSwap(
        "acc-trader",
        "base",
        decimal.NewFromInt(1),
        decimal.NewFromInt(60000),  // too high, will trigger slippage error
    )

    assert.Error(t, err)
    assert.Equal(t, ErrSlippageExceeded, err)
}

func TestLargeTradePriceImpact(t *testing.T) {
    pool := setupTestPool(t)

    // Large trade (50% of pool)
    outputAmount, err := pool.ExecuteSwap(
        "acc-trader",
        "base",
        decimal.NewFromInt(5),  // 5 BTC (50% of pool)
        decimal.Zero,
    )

    assert.NoError(t, err)

    // Verify price impact is significant
    events := pool.GetUncommittedEvents()
    swapEvent := events[len(events)-1].(SwapExecuted)

    assert.True(t, swapEvent.PriceImpact.GreaterThan(decimal.NewFromInt(20)))  // >20% impact
}

func TestAddLiquidity(t *testing.T) {
    pool := setupTestPool(t)
    initialShares := pool.totalShares

    // Add liquidity maintaining ratio (10 BTC : 500,000 USD = 1:50,000)
    err := pool.AddLiquidity(
        "acc-provider",
        decimal.NewFromInt(1),      // 1 BTC
        decimal.NewFromInt(50000),  // 50,000 USD
    )

    assert.NoError(t, err)
    assert.True(t, pool.totalShares.GreaterThan(initialShares))
}

func TestAddImbalancedLiquidity(t *testing.T) {
    pool := setupTestPool(t)

    // Try to add liquidity with wrong ratio
    err := pool.AddLiquidity(
        "acc-provider",
        decimal.NewFromInt(1),      // 1 BTC
        decimal.NewFromInt(60000),  // 60,000 USD (wrong ratio)
    )

    assert.Error(t, err)
    assert.Equal(t, ErrImbalancedLiquidity, err)
}

func TestConstantProductInvariant(t *testing.T) {
    pool := setupTestPool(t)
    initialK := pool.k

    // Execute swap
    pool.ExecuteSwap("acc-trader", "base", decimal.NewFromInt(1), decimal.Zero)

    // k should remain approximately constant (minor diff due to fees)
    newK := pool.baseReserve.Mul(pool.quoteReserve)

    // Allow 1% tolerance due to fees
    tolerance := initialK.Mul(decimal.NewFromFloat(0.01))
    diff := newK.Sub(initialK).Abs()

    assert.True(t, diff.LessThan(tolerance))
}
```

**Verification Command:**
```bash
go test -v ./internal/domain/exchange/aggregate/
```

**PHP Reference:**
- `app/Domain/Exchange/Aggregates/LiquidityPool.php`
- `app/Domain/Exchange/Events/LiquidityPool*.php`
- `app/Domain/Exchange/Services/AutomatedMarketMakerService.php`

---

### Task 5.4: Order Matching Service

**Task ID:** P5-EXCHANGE-004

**Description:** Implement FIFO order matching engine

**Priority:** Critical

**Estimated Complexity:** XL (16+ hours)

**Dependencies:**
- P5-EXCHANGE-002 (Order aggregate)

**Acceptance Criteria:**
- [ ] FIFO (First In, First Out) matching algorithm
- [ ] Price-time priority
- [ ] Market order matching (immediate execution)
- [ ] Limit order matching (price condition)
- [ ] Partial fill support
- [ ] Order book management (buy/sell sides)
- [ ] Match creation and validation
- [ ] Thread-safe concurrent matching
- [ ] Unit tests (>90% coverage)
- [ ] Performance tests (>1000 matches/second)

**Files to Create:**
```
internal/domain/exchange/service/order_matching_service.go
internal/domain/exchange/service/order_matching_service_test.go
internal/domain/exchange/valueobject/match.go
internal/domain/exchange/valueobject/order_book.go
```

**Implementation Steps:**
1. Define OrderBook data structure:
   ```go
   type OrderBook struct {
       mu          sync.RWMutex
       tradingPair valueobject.TradingPair
       buyOrders   *PriorityQueue  // Max heap (highest price first)
       sellOrders  *PriorityQueue  // Min heap (lowest price first)
   }

   type PriorityQueue struct {
       orders []*OrderEntry
   }

   type OrderEntry struct {
       OrderID   string
       Price     decimal.Decimal
       Quantity  decimal.Decimal
       Timestamp time.Time
   }
   ```

2. Implement OrderMatchingService:
   ```go
   type OrderMatchingService struct {
       eventStore events.EventStore
       orderBooks map[string]*OrderBook  // tradingPair -> orderBook
       mu         sync.RWMutex
   }

   func NewOrderMatchingService(eventStore events.EventStore) *OrderMatchingService {
       return &OrderMatchingService{
           eventStore: eventStore,
           orderBooks: make(map[string]*OrderBook),
       }
   }
   ```

3. Implement MatchOrder:
   ```go
   func (s *OrderMatchingService) MatchOrder(
       ctx context.Context,
       incomingOrder *aggregate.Order,
   ) ([]*Match, error) {
       s.mu.Lock()
       defer s.mu.Unlock()

       book := s.getOrCreateOrderBook(incomingOrder.TradingPair)

       var matches []*Match

       if incomingOrder.OrderSide == valueobject.OrderSideBuy {
           // Match against sell orders
           matches = s.matchBuyOrder(ctx, incomingOrder, book)
       } else {
           // Match against buy orders
           matches = s.matchSellOrder(ctx, incomingOrder, book)
       }

       // If order not fully filled, add to book
       if incomingOrder.RemainingQuantity.GreaterThan(decimal.Zero) {
           if incomingOrder.OrderType == valueobject.OrderTypeLimit {
               book.AddOrder(incomingOrder)
           }
           // Market orders are filled or cancelled, never added to book
       }

       return matches, nil
   }

   func (s *OrderMatchingService) matchBuyOrder(
       ctx context.Context,
       buyOrder *aggregate.Order,
       book *OrderBook,
   ) []*Match {
       var matches []*Match

       for buyOrder.RemainingQuantity.GreaterThan(decimal.Zero) {
           // Get best sell order (lowest price)
           sellOrder := book.sellOrders.Peek()
           if sellOrder == nil {
               break  // No more sell orders
           }

           // Check price condition
           if buyOrder.OrderType == valueobject.OrderTypeLimit {
               if sellOrder.Price.GreaterThan(buyOrder.Price.Amount) {
                   break  // Sell price too high, no match
               }
           }

           // Determine match quantity
           matchQuantity := decimal.Min(
               buyOrder.RemainingQuantity,
               sellOrder.Quantity,
           )

           // Execution price is the maker's price (sell order price)
           executionPrice := sellOrder.Price

           // Create match
           match := &Match{
               MatchID:        generateMatchID(),
               BuyOrderID:     buyOrder.OrderID,
               SellOrderID:    sellOrder.OrderID,
               TradingPair:    buyOrder.TradingPair,
               Quantity:       matchQuantity,
               Price:          executionPrice,
               Timestamp:      time.Now(),
           }
           matches = append(matches, match)

           // Update orders
           buyOrder.PartialFill(matchQuantity, executionPrice, match.MatchID)

           // Update sell order in book
           sellOrder.Quantity = sellOrder.Quantity.Sub(matchQuantity)
           if sellOrder.Quantity.IsZero() {
               book.sellOrders.Pop()
           }
       }

       return matches
   }

   func (s *OrderMatchingService) matchSellOrder(
       ctx context.Context,
       sellOrder *aggregate.Order,
       book *OrderBook,
   ) []*Match {
       // Similar logic but matching against buy orders (highest price first)
       // ...
   }
   ```

4. Implement price-time priority queue
5. Add thread safety with mutexes
6. Write comprehensive tests

**Testing:**
```go
func TestMatchMarketBuyOrder(t *testing.T) {
    service := setupTestMatchingService(t)

    // Add sell orders to book
    addSellOrder(t, service, "sell-1", decimal.NewFromInt(50000), decimal.NewFromFloat(0.5))
    addSellOrder(t, service, "sell-2", decimal.NewFromInt(50100), decimal.NewFromFloat(0.3))

    // Place market buy order
    buyOrder := createMarketBuyOrder(t, decimal.NewFromFloat(0.7))

    matches, err := service.MatchOrder(context.Background(), buyOrder)

    assert.NoError(t, err)
    assert.Len(t, matches, 2)  // Matched with 2 sell orders

    // First match at 50,000, quantity 0.5
    assert.Equal(t, decimal.NewFromInt(50000), matches[0].Price)
    assert.Equal(t, decimal.NewFromFloat(0.5), matches[0].Quantity)

    // Second match at 50,100, quantity 0.2
    assert.Equal(t, decimal.NewFromInt(50100), matches[1].Price)
    assert.Equal(t, decimal.NewFromFloat(0.2), matches[1].Quantity)

    // Order fully filled
    assert.True(t, buyOrder.Status == valueobject.OrderStatusFilled)
}

func TestMatchLimitBuyOrder(t *testing.T) {
    service := setupTestMatchingService(t)

    // Add sell orders
    addSellOrder(t, service, "sell-1", decimal.NewFromInt(50000), decimal.NewFromFloat(0.5))
    addSellOrder(t, service, "sell-2", decimal.NewFromInt(51000), decimal.NewFromFloat(0.3))

    // Place limit buy order at 50,500
    buyOrder := createLimitBuyOrder(t, decimal.NewFromInt(50500), decimal.NewFromFloat(0.7))

    matches, err := service.MatchOrder(context.Background(), buyOrder)

    assert.NoError(t, err)
    assert.Len(t, matches, 1)  // Only matched with sell-1 (price <= 50,500)

    // Matched at 50,000 (maker price)
    assert.Equal(t, decimal.NewFromInt(50000), matches[0].Price)
    assert.Equal(t, decimal.NewFromFloat(0.5), matches[0].Quantity)

    // Order partially filled, remaining on book
    assert.Equal(t, valueobject.OrderStatusPartiallyFilled, buyOrder.Status)
    assert.Equal(t, decimal.NewFromFloat(0.2), buyOrder.RemainingQuantity)
}

func TestPriceTimePriority(t *testing.T) {
    service := setupTestMatchingService(t)

    // Add sell orders at same price but different times
    time1 := time.Now()
    addSellOrderWithTime(t, service, "sell-1", decimal.NewFromInt(50000), decimal.NewFromFloat(0.3), time1)

    time2 := time1.Add(1 * time.Second)
    addSellOrderWithTime(t, service, "sell-2", decimal.NewFromInt(50000), decimal.NewFromFloat(0.3), time2)

    // Place buy order
    buyOrder := createMarketBuyOrder(t, decimal.NewFromFloat(0.4))

    matches, err := service.MatchOrder(context.Background(), buyOrder)

    assert.NoError(t, err)
    assert.Len(t, matches, 2)

    // First match should be sell-1 (earlier timestamp)
    assert.Equal(t, "sell-1", matches[0].SellOrderID)
    assert.Equal(t, decimal.NewFromFloat(0.3), matches[0].Quantity)

    // Second match with sell-2 for remaining
    assert.Equal(t, "sell-2", matches[1].SellOrderID)
    assert.Equal(t, decimal.NewFromFloat(0.1), matches[1].Quantity)
}

func TestConcurrentMatching(t *testing.T) {
    service := setupTestMatchingService(t)

    // Add sell orders
    for i := 0; i < 10; i++ {
        price := decimal.NewFromInt(50000 + int64(i*100))
        addSellOrder(t, service, fmt.Sprintf("sell-%d", i), price, decimal.NewFromFloat(1.0))
    }

    // Concurrent buy orders
    var wg sync.WaitGroup
    results := make(chan []*Match, 5)

    for i := 0; i < 5; i++ {
        wg.Add(1)
        go func(id int) {
            defer wg.Done()
            order := createMarketBuyOrder(t, decimal.NewFromFloat(2.0))
            matches, _ := service.MatchOrder(context.Background(), order)
            results <- matches
        }(i)
    }

    wg.Wait()
    close(results)

    // Verify all matches are valid and no double-matching
    allMatches := make(map[string]bool)
    for matches := range results {
        for _, match := range matches {
            key := fmt.Sprintf("%s-%s", match.BuyOrderID, match.SellOrderID)
            assert.False(t, allMatches[key], "Duplicate match detected")
            allMatches[key] = true
        }
    }
}

func BenchmarkOrderMatching(b *testing.B) {
    service := setupTestMatchingService(b)

    // Pre-populate order book
    for i := 0; i < 1000; i++ {
        price := decimal.NewFromInt(50000 + int64(i))
        addSellOrder(b, service, fmt.Sprintf("sell-%d", i), price, decimal.NewFromFloat(1.0))
    }

    b.ResetTimer()

    for i := 0; i < b.N; i++ {
        order := createMarketBuyOrder(b, decimal.NewFromFloat(0.1))
        service.MatchOrder(context.Background(), order)
    }
}
```

**Verification Command:**
```bash
go test -v ./internal/domain/exchange/service/
go test -bench=. -benchmem ./internal/domain/exchange/service/
```

**PHP Reference:**
- `app/Domain/Exchange/Services/OrderService.php`
- `app/Domain/Exchange/Workflows/OrderMatchingWorkflow.php`
- `app/Domain/Exchange/Activities/MatchOrderActivity.php`

---

### Task 5.5: Exchange Commands & Handlers

**Task ID:** P5-EXCHANGE-005

**Description:** Implement exchange command DTOs and handlers

**Priority:** Critical

**Estimated Complexity:** L (8-16h)

**Dependencies:**
- P5-EXCHANGE-002 (Order aggregate)
- P5-EXCHANGE-003 (LiquidityPool aggregate)
- P5-EXCHANGE-004 (OrderMatchingService)
- P1-SHARED-006 (CommandBus)

**Acceptance Criteria:**
- [ ] PlaceOrderCommand + Handler
- [ ] CancelOrderCommand + Handler
- [ ] CreateLiquidityPoolCommand + Handler
- [ ] AddLiquidityCommand + Handler
- [ ] RemoveLiquidityCommand + Handler
- [ ] ExecuteSwapCommand + Handler
- [ ] All commands validated
- [ ] Integration with EventStore
- [ ] Integration with OrderMatchingService
- [ ] Unit tests
- [ ] Integration tests

**Files to Create:**
```
internal/application/command/exchange/place_order.go
internal/application/command/exchange/cancel_order.go
internal/application/command/exchange/create_pool.go
internal/application/command/exchange/add_liquidity.go
internal/application/command/exchange/remove_liquidity.go
internal/application/command/exchange/execute_swap.go
internal/application/command/exchange/handler/place_order_handler.go
internal/application/command/exchange/handler/cancel_order_handler.go
internal/application/command/exchange/handler/pool_handler.go
internal/application/command/exchange/handler/swap_handler.go
internal/application/command/exchange/handler/handler_test.go
```

**Implementation Steps:**
1. Define PlaceOrderCommand:
   ```go
   type PlaceOrderCommand struct {
       OrderID     string
       AccountID   string
       TradingPair valueobject.TradingPair
       OrderType   valueobject.OrderType
       OrderSide   valueobject.OrderSide
       Price       *decimal.Decimal  // nil for market orders
       Quantity    decimal.Decimal
       Metadata    map[string]interface{}
   }

   func (c PlaceOrderCommand) CommandName() string {
       return "exchange.place_order"
   }
   ```

2. Implement PlaceOrderHandler:
   ```go
   type PlaceOrderHandler struct {
       eventStore      events.EventStore
       matchingService *service.OrderMatchingService
       accountService  *account.Service  // to verify account has funds
   }

   func (h *PlaceOrderHandler) Handle(ctx context.Context, cmd cqrs.Command) error {
       placeCmd := cmd.(PlaceOrderCommand)

       // Verify account has sufficient balance (for buy orders)
       if placeCmd.OrderSide == valueobject.OrderSideBuy {
           // Calculate required funds
           var requiredAmount decimal.Decimal
           if placeCmd.OrderType == valueobject.OrderTypeMarket {
               // For market orders, estimate based on order book
               requiredAmount = h.estimateRequiredFunds(placeCmd.TradingPair, placeCmd.Quantity)
           } else {
               requiredAmount = placeCmd.Price.Mul(placeCmd.Quantity)
           }

           // Check balance
           balance, err := h.accountService.GetBalance(ctx, placeCmd.AccountID, placeCmd.TradingPair.QuoteCurrency)
           if err != nil {
               return err
           }

           if balance.LessThan(requiredAmount) {
               return ErrInsufficientFunds
           }

           // Lock funds (reserve balance)
           err = h.accountService.LockFunds(ctx, placeCmd.AccountID, placeCmd.TradingPair.QuoteCurrency, requiredAmount)
           if err != nil {
               return err
           }
       } else {
           // For sell orders, verify they have the asset
           balance, err := h.accountService.GetBalance(ctx, placeCmd.AccountID, placeCmd.TradingPair.BaseCurrency)
           if err != nil {
               return err
           }

           if balance.LessThan(placeCmd.Quantity) {
               return ErrInsufficientAssets
           }

           // Lock assets
           err = h.accountService.LockFunds(ctx, placeCmd.AccountID, placeCmd.TradingPair.BaseCurrency, placeCmd.Quantity)
           if err != nil {
               return err
           }
       }

       // Create order aggregate
       var price *valueobject.Price
       if placeCmd.Price != nil {
           p, _ := valueobject.NewPrice(*placeCmd.Price, placeCmd.TradingPair)
           price = &p
       }

       quantity := valueobject.NewQuantity(placeCmd.Quantity)

       order, err := aggregate.PlaceOrder(
           placeCmd.OrderID,
           placeCmd.AccountID,
           placeCmd.TradingPair,
           placeCmd.OrderType,
           placeCmd.OrderSide,
           price,
           quantity,
           placeCmd.Metadata,
       )
       if err != nil {
           return err
       }

       // Persist order
       err = order.Persist(ctx, h.eventStore)
       if err != nil {
           return err
       }

       // Attempt to match order
       matches, err := h.matchingService.MatchOrder(ctx, order)
       if err != nil {
           return err
       }

       // If matches occurred, persist updated order
       if len(matches) > 0 {
           err = order.Persist(ctx, h.eventStore)
           if err != nil {
               return err
           }

           // Execute matched trades (transfer funds/assets between accounts)
           for _, match := range matches {
               err = h.executeMatch(ctx, match)
               if err != nil {
                   return err
               }
           }
       }

       return nil
   }

   func (h *PlaceOrderHandler) executeMatch(ctx context.Context, match *service.Match) error {
       // Transfer quote currency from buyer to seller
       // Transfer base currency from seller to buyer
       // Release locked funds
       // Collect trading fees
       // ... implementation ...
   }
   ```

3. Implement CreateLiquidityPoolHandler
4. Implement ExecuteSwapHandler
5. Write comprehensive tests

**Testing:**
```go
func TestPlaceOrderHandler(t *testing.T) {
    store := setupTestEventStore(t)
    matchingService := setupTestMatchingService(t)
    accountService := setupTestAccountService(t)

    handler := NewPlaceOrderHandler(store, matchingService, accountService)

    // Create account with balance
    setupAccountWithBalance(t, accountService, "acc-123", "USD", decimal.NewFromInt(100000))

    cmd := PlaceOrderCommand{
        OrderID:     "order-123",
        AccountID:   "acc-123",
        TradingPair: valueobject.NewTradingPair("BTC", "USD"),
        OrderType:   valueobject.OrderTypeLimit,
        OrderSide:   valueobject.OrderSideBuy,
        Price:       ptrDecimal(decimal.NewFromInt(50000)),
        Quantity:    decimal.NewFromFloat(0.5),
    }

    err := handler.Handle(context.Background(), cmd)
    assert.NoError(t, err)

    // Verify order was created
    events, err := store.Load(context.Background(), "order-123")
    assert.NoError(t, err)
    assert.Len(t, events, 1)

    // Verify funds were locked
    lockedBalance := accountService.GetLockedBalance(context.Background(), "acc-123", "USD")
    assert.Equal(t, decimal.NewFromInt(25000), lockedBalance)  // 0.5 * 50000
}

func TestPlaceOrderInsufficientFunds(t *testing.T) {
    handler := setupTestPlaceOrderHandler(t)

    // Account with only $1000
    setupAccountWithBalance(t, accountService, "acc-123", "USD", decimal.NewFromInt(1000))

    cmd := PlaceOrderCommand{
        AccountID:   "acc-123",
        OrderSide:   valueobject.OrderSideBuy,
        Price:       ptrDecimal(decimal.NewFromInt(50000)),
        Quantity:    decimal.NewFromFloat(1.0),  // Needs $50,000
    }

    err := handler.Handle(context.Background(), cmd)
    assert.Error(t, err)
    assert.Equal(t, ErrInsufficientFunds, err)
}

func TestExecuteSwapHandler(t *testing.T) {
    handler := setupTestSwapHandler(t)

    // Create pool
    setupTestPool(t, "BTC", "USD", decimal.NewFromInt(10), decimal.NewFromInt(500000))

    // Account with BTC
    setupAccountWithBalance(t, "acc-trader", "BTC", decimal.NewFromInt(1))

    cmd := ExecuteSwapCommand{
        PoolID:          "pool-123",
        AccountID:       "acc-trader",
        InputCurrency:   "BTC",
        InputAmount:     decimal.NewFromFloat(0.5),
        MinOutputAmount: decimal.NewFromInt(20000),  // Slippage protection
    }

    err := handler.Handle(context.Background(), cmd)
    assert.NoError(t, err)

    // Verify account balances updated
    btcBalance := getBalance(t, "acc-trader", "BTC")
    usdBalance := getBalance(t, "acc-trader", "USD")

    assert.Equal(t, decimal.NewFromFloat(0.5), btcBalance)  // 1.0 - 0.5
    assert.True(t, usdBalance.GreaterThan(decimal.NewFromInt(20000)))
}
```

**Verification Command:**
```bash
go test -v ./internal/application/command/exchange/handler/
```

**PHP Reference:**
- `app/Domain/Exchange/Services/ExchangeService.php`
- `app/Domain/Exchange/Services/OrderService.php`
- `app/Domain/Exchange/Services/LiquidityPoolService.php`

---

### Task 5.6: Exchange Projections (Read Models)

**ID:** P5-EXCHANGE-006
**Description:** Create projection models for Exchange read operations
**Priority:** HIGH
**Complexity:** 8 hours

**Dependencies:**
- P5-EXCHANGE-001 (Order Value Objects)
- P5-EXCHANGE-002 (Order Aggregate)
- P5-EXCHANGE-003 (LiquidityPool Aggregate)

**Acceptance Criteria:**
- [ ] All projection models defined with GORM tags
- [ ] Database migrations created
- [ ] Indexes optimized for query patterns
- [ ] Relationship models configured
- [ ] Test coverage >90%

**Files to Create:**
```
internal/domain/exchange/projection/
├── order.go                 # Order projection model
├── trade.go                 # Trade projection model
├── liquidity_pool.go        # LiquidityPool projection model
├── liquidity_provider.go    # LiquidityProvider projection model
├── order_book_entry.go      # OrderBook entry model
└── trading_pair_stats.go    # Trading pair statistics

migrations/
└── 006_create_exchange_projections.up.sql
```

**Implementation Steps:**

1. **Create Order Projection Model:**

```go
// internal/domain/exchange/projection/order.go
package projection

import (
    "time"
    "github.com/shopspring/decimal"
    "gorm.io/gorm"
)

type Order struct {
    ID                string          `gorm:"primaryKey;type:uuid"`
    AccountID         string          `gorm:"type:uuid;not null;index:idx_orders_account"`
    TenantID          string          `gorm:"type:uuid;not null;index:idx_orders_tenant"`
    TradingPairBase   string          `gorm:"type:varchar(10);not null"`
    TradingPairQuote  string          `gorm:"type:varchar(10);not null"`
    TradingPair       string          `gorm:"type:varchar(20);not null;index:idx_orders_pair"`
    OrderType         string          `gorm:"type:varchar(20);not null"`
    OrderSide         string          `gorm:"type:varchar(10);not null"`
    Price             decimal.Decimal `gorm:"type:decimal(36,18)"`
    Quantity          decimal.Decimal `gorm:"type:decimal(36,18);not null"`
    FilledQuantity    decimal.Decimal `gorm:"type:decimal(36,18);default:0"`
    RemainingQuantity decimal.Decimal `gorm:"type:decimal(36,18);not null"`
    Status            string          `gorm:"type:varchar(20);not null;index:idx_orders_status"`
    TimeInForce       string          `gorm:"type:varchar(10)"`
    StopPrice         decimal.Decimal `gorm:"type:decimal(36,18)"`
    AveragePrice      decimal.Decimal `gorm:"type:decimal(36,18)"`
    TotalValue        decimal.Decimal `gorm:"type:decimal(36,18)"`
    FeePaid           decimal.Decimal `gorm:"type:decimal(36,18);default:0"`
    CreatedAt         time.Time       `gorm:"not null;index:idx_orders_created"`
    UpdatedAt         time.Time       `gorm:"not null"`
    CompletedAt       *time.Time      `gorm:"index:idx_orders_completed"`
    CancelledAt       *time.Time

    // Relationships
    Trades []Trade `gorm:"foreignKey:BuyOrderID;references:ID"`
}

func (Order) TableName() string {
    return "exchange_orders"
}

// Scopes for common queries
func (o *Order) ScopeByTenant(tenantID string) func(db *gorm.DB) *gorm.DB {
    return func(db *gorm.DB) *gorm.DB {
        return db.Where("tenant_id = ?", tenantID)
    }
}

func (o *Order) ScopeActive() func(db *gorm.DB) *gorm.DB {
    return func(db *gorm.DB) *gorm.DB {
        return db.Where("status IN ?", []string{"pending", "partially_filled"})
    }
}

func (o *Order) ScopeByTradingPair(pair string) func(db *gorm.DB) *gorm.DB {
    return func(db *gorm.DB) *gorm.DB {
        return db.Where("trading_pair = ?", pair)
    }
}
```

2. **Create Trade Projection Model:**

```go
// internal/domain/exchange/projection/trade.go
package projection

import (
    "time"
    "github.com/shopspring/decimal"
)

type Trade struct {
    ID              string          `gorm:"primaryKey;type:uuid"`
    TenantID        string          `gorm:"type:uuid;not null;index:idx_trades_tenant"`
    MatchID         string          `gorm:"type:uuid;not null;unique"`
    TradingPair     string          `gorm:"type:varchar(20);not null;index:idx_trades_pair"`
    BuyOrderID      string          `gorm:"type:uuid;not null;index:idx_trades_buy_order"`
    SellOrderID     string          `gorm:"type:uuid;not null;index:idx_trades_sell_order"`
    BuyAccountID    string          `gorm:"type:uuid;not null;index:idx_trades_buy_account"`
    SellAccountID   string          `gorm:"type:uuid;not null;index:idx_trades_sell_account"`
    Price           decimal.Decimal `gorm:"type:decimal(36,18);not null"`
    Quantity        decimal.Decimal `gorm:"type:decimal(36,18);not null"`
    TotalValue      decimal.Decimal `gorm:"type:decimal(36,18);not null"`
    BuyerFee        decimal.Decimal `gorm:"type:decimal(36,18);default:0"`
    SellerFee       decimal.Decimal `gorm:"type:decimal(36,18);default:0"`
    TakerSide       string          `gorm:"type:varchar(10);not null"` // buy or sell
    ExecutedAt      time.Time       `gorm:"not null;index:idx_trades_executed"`

    // Relationships
    BuyOrder  *Order `gorm:"foreignKey:BuyOrderID"`
    SellOrder *Order `gorm:"foreignKey:SellOrderID"`
}

func (Trade) TableName() string {
    return "exchange_trades"
}
```

3. **Create LiquidityPool Projection Model:**

```go
// internal/domain/exchange/projection/liquidity_pool.go
package projection

import (
    "time"
    "github.com/shopspring/decimal"
)

type LiquidityPool struct {
    ID               string          `gorm:"primaryKey;type:uuid"`
    TenantID         string          `gorm:"type:uuid;not null;index:idx_pools_tenant"`
    TradingPair      string          `gorm:"type:varchar(20);not null;unique;index:idx_pools_pair"`
    BaseCurrency     string          `gorm:"type:varchar(10);not null"`
    QuoteCurrency    string          `gorm:"type:varchar(10);not null"`
    BaseReserve      decimal.Decimal `gorm:"type:decimal(36,18);not null"`
    QuoteReserve     decimal.Decimal `gorm:"type:decimal(36,18);not null"`
    TotalShares      decimal.Decimal `gorm:"type:decimal(36,18);not null"`
    K                decimal.Decimal `gorm:"type:decimal(72,36);not null"` // x * y constant
    FeeRate          decimal.Decimal `gorm:"type:decimal(10,6);default:0.003"` // 0.3%
    Status           string          `gorm:"type:varchar(20);not null;default:'active'"`
    TotalVolume24h   decimal.Decimal `gorm:"type:decimal(36,18);default:0"`
    TotalFees24h     decimal.Decimal `gorm:"type:decimal(36,18);default:0"`
    PriceImpact      decimal.Decimal `gorm:"type:decimal(10,6)"` // Last swap price impact
    CreatedAt        time.Time       `gorm:"not null"`
    UpdatedAt        time.Time       `gorm:"not null"`

    // Relationships
    Providers []LiquidityProvider `gorm:"foreignKey:PoolID"`
}

func (LiquidityPool) TableName() string {
    return "exchange_liquidity_pools"
}

// Calculate current price (quote per base)
func (lp *LiquidityPool) CurrentPrice() decimal.Decimal {
    if lp.BaseReserve.IsZero() {
        return decimal.Zero
    }
    return lp.QuoteReserve.Div(lp.BaseReserve)
}

// Calculate output amount for swap (with fee)
func (lp *LiquidityPool) CalculateSwapOutput(
    inputCurrency string,
    inputAmount decimal.Decimal,
) decimal.Decimal {
    fee := inputAmount.Mul(lp.FeeRate)
    inputAfterFee := inputAmount.Sub(fee)

    if inputCurrency == lp.BaseCurrency {
        newBaseReserve := lp.BaseReserve.Add(inputAfterFee)
        newQuoteReserve := lp.K.Div(newBaseReserve)
        return lp.QuoteReserve.Sub(newQuoteReserve)
    } else {
        newQuoteReserve := lp.QuoteReserve.Add(inputAfterFee)
        newBaseReserve := lp.K.Div(newQuoteReserve)
        return lp.BaseReserve.Sub(newBaseReserve)
    }
}
```

4. **Create LiquidityProvider Projection Model:**

```go
// internal/domain/exchange/projection/liquidity_provider.go
package projection

import (
    "time"
    "github.com/shopspring/decimal"
)

type LiquidityProvider struct {
    ID                  string          `gorm:"primaryKey;type:uuid"`
    PoolID              string          `gorm:"type:uuid;not null;index:idx_lp_pool"`
    AccountID           string          `gorm:"type:uuid;not null;index:idx_lp_account"`
    TenantID            string          `gorm:"type:uuid;not null;index:idx_lp_tenant"`
    Shares              decimal.Decimal `gorm:"type:decimal(36,18);not null"`
    InitialBaseAmount   decimal.Decimal `gorm:"type:decimal(36,18);not null"`
    InitialQuoteAmount  decimal.Decimal `gorm:"type:decimal(36,18);not null"`
    CurrentBaseValue    decimal.Decimal `gorm:"type:decimal(36,18)"`
    CurrentQuoteValue   decimal.Decimal `gorm:"type:decimal(36,18)"`
    FeesEarnedBase      decimal.Decimal `gorm:"type:decimal(36,18);default:0"`
    FeesEarnedQuote     decimal.Decimal `gorm:"type:decimal(36,18);default:0"`
    ImpermanentLoss     decimal.Decimal `gorm:"type:decimal(36,18);default:0"`
    CreatedAt           time.Time       `gorm:"not null"`
    UpdatedAt           time.Time       `gorm:"not null"`

    // Relationships
    Pool *LiquidityPool `gorm:"foreignKey:PoolID"`
}

func (LiquidityProvider) TableName() string {
    return "exchange_liquidity_providers"
}

// Calculate current value based on pool reserves
func (lp *LiquidityProvider) CalculateCurrentValue(pool *LiquidityPool) {
    if pool.TotalShares.IsZero() {
        return
    }

    sharePercentage := lp.Shares.Div(pool.TotalShares)
    lp.CurrentBaseValue = pool.BaseReserve.Mul(sharePercentage)
    lp.CurrentQuoteValue = pool.QuoteReserve.Mul(sharePercentage)
}
```

5. **Create OrderBook Entry Model:**

```go
// internal/domain/exchange/projection/order_book_entry.go
package projection

import (
    "github.com/shopspring/decimal"
)

type OrderBookEntry struct {
    TradingPair     string          `gorm:"primaryKey;type:varchar(20)"`
    Side            string          `gorm:"primaryKey;type:varchar(10)"` // buy or sell
    Price           decimal.Decimal `gorm:"primaryKey;type:decimal(36,18)"`
    TenantID        string          `gorm:"type:uuid;not null;index:idx_orderbook_tenant"`
    TotalQuantity   decimal.Decimal `gorm:"type:decimal(36,18);not null"`
    OrderCount      int             `gorm:"not null"`
    UpdatedAt       time.Time       `gorm:"not null"`
}

func (OrderBookEntry) TableName() string {
    return "exchange_order_book_entries"
}
```

6. **Create Trading Pair Statistics Model:**

```go
// internal/domain/exchange/projection/trading_pair_stats.go
package projection

import (
    "time"
    "github.com/shopspring/decimal"
)

type TradingPairStats struct {
    TradingPair       string          `gorm:"primaryKey;type:varchar(20)"`
    TenantID          string          `gorm:"type:uuid;not null;index:idx_stats_tenant"`
    LastPrice         decimal.Decimal `gorm:"type:decimal(36,18)"`
    HighPrice24h      decimal.Decimal `gorm:"type:decimal(36,18)"`
    LowPrice24h       decimal.Decimal `gorm:"type:decimal(36,18)"`
    OpenPrice24h      decimal.Decimal `gorm:"type:decimal(36,18)"`
    Volume24hBase     decimal.Decimal `gorm:"type:decimal(36,18)"`
    Volume24hQuote    decimal.Decimal `gorm:"type:decimal(36,18)"`
    TradeCount24h     int64           `gorm:"default:0"`
    PriceChange24h    decimal.Decimal `gorm:"type:decimal(36,18)"`
    PriceChangePercent decimal.Decimal `gorm:"type:decimal(10,6)"`
    BestBidPrice      decimal.Decimal `gorm:"type:decimal(36,18)"`
    BestAskPrice      decimal.Decimal `gorm:"type:decimal(36,18)"`
    Spread            decimal.Decimal `gorm:"type:decimal(36,18)"`
    SpreadPercent     decimal.Decimal `gorm:"type:decimal(10,6)"`
    UpdatedAt         time.Time       `gorm:"not null"`
}

func (TradingPairStats) TableName() string {
    return "exchange_trading_pair_stats"
}
```

7. **Create Database Migration:**

```sql
-- migrations/006_create_exchange_projections.up.sql

-- Orders table
CREATE TABLE exchange_orders (
    id UUID PRIMARY KEY,
    account_id UUID NOT NULL,
    tenant_id UUID NOT NULL,
    trading_pair_base VARCHAR(10) NOT NULL,
    trading_pair_quote VARCHAR(10) NOT NULL,
    trading_pair VARCHAR(20) NOT NULL,
    order_type VARCHAR(20) NOT NULL,
    order_side VARCHAR(10) NOT NULL,
    price DECIMAL(36,18),
    quantity DECIMAL(36,18) NOT NULL,
    filled_quantity DECIMAL(36,18) DEFAULT 0,
    remaining_quantity DECIMAL(36,18) NOT NULL,
    status VARCHAR(20) NOT NULL,
    time_in_force VARCHAR(10),
    stop_price DECIMAL(36,18),
    average_price DECIMAL(36,18),
    total_value DECIMAL(36,18),
    fee_paid DECIMAL(36,18) DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMP,
    cancelled_at TIMESTAMP
);

CREATE INDEX idx_orders_account ON exchange_orders(account_id);
CREATE INDEX idx_orders_tenant ON exchange_orders(tenant_id);
CREATE INDEX idx_orders_pair ON exchange_orders(trading_pair);
CREATE INDEX idx_orders_status ON exchange_orders(status);
CREATE INDEX idx_orders_created ON exchange_orders(created_at DESC);
CREATE INDEX idx_orders_completed ON exchange_orders(completed_at DESC);
CREATE INDEX idx_orders_active ON exchange_orders(trading_pair, status)
    WHERE status IN ('pending', 'partially_filled');

-- Trades table
CREATE TABLE exchange_trades (
    id UUID PRIMARY KEY,
    tenant_id UUID NOT NULL,
    match_id UUID NOT NULL UNIQUE,
    trading_pair VARCHAR(20) NOT NULL,
    buy_order_id UUID NOT NULL,
    sell_order_id UUID NOT NULL,
    buy_account_id UUID NOT NULL,
    sell_account_id UUID NOT NULL,
    price DECIMAL(36,18) NOT NULL,
    quantity DECIMAL(36,18) NOT NULL,
    total_value DECIMAL(36,18) NOT NULL,
    buyer_fee DECIMAL(36,18) DEFAULT 0,
    seller_fee DECIMAL(36,18) DEFAULT 0,
    taker_side VARCHAR(10) NOT NULL,
    executed_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_trades_tenant ON exchange_trades(tenant_id);
CREATE INDEX idx_trades_pair ON exchange_trades(trading_pair);
CREATE INDEX idx_trades_buy_order ON exchange_trades(buy_order_id);
CREATE INDEX idx_trades_sell_order ON exchange_trades(sell_order_id);
CREATE INDEX idx_trades_buy_account ON exchange_trades(buy_account_id);
CREATE INDEX idx_trades_sell_account ON exchange_trades(sell_account_id);
CREATE INDEX idx_trades_executed ON exchange_trades(executed_at DESC);
CREATE INDEX idx_trades_pair_time ON exchange_trades(trading_pair, executed_at DESC);

-- Liquidity pools table
CREATE TABLE exchange_liquidity_pools (
    id UUID PRIMARY KEY,
    tenant_id UUID NOT NULL,
    trading_pair VARCHAR(20) NOT NULL UNIQUE,
    base_currency VARCHAR(10) NOT NULL,
    quote_currency VARCHAR(10) NOT NULL,
    base_reserve DECIMAL(36,18) NOT NULL,
    quote_reserve DECIMAL(36,18) NOT NULL,
    total_shares DECIMAL(36,18) NOT NULL,
    k DECIMAL(72,36) NOT NULL,
    fee_rate DECIMAL(10,6) DEFAULT 0.003,
    status VARCHAR(20) NOT NULL DEFAULT 'active',
    total_volume_24h DECIMAL(36,18) DEFAULT 0,
    total_fees_24h DECIMAL(36,18) DEFAULT 0,
    price_impact DECIMAL(10,6),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_pools_tenant ON exchange_liquidity_pools(tenant_id);
CREATE INDEX idx_pools_pair ON exchange_liquidity_pools(trading_pair);

-- Liquidity providers table
CREATE TABLE exchange_liquidity_providers (
    id UUID PRIMARY KEY,
    pool_id UUID NOT NULL,
    account_id UUID NOT NULL,
    tenant_id UUID NOT NULL,
    shares DECIMAL(36,18) NOT NULL,
    initial_base_amount DECIMAL(36,18) NOT NULL,
    initial_quote_amount DECIMAL(36,18) NOT NULL,
    current_base_value DECIMAL(36,18),
    current_quote_value DECIMAL(36,18),
    fees_earned_base DECIMAL(36,18) DEFAULT 0,
    fees_earned_quote DECIMAL(36,18) DEFAULT 0,
    impermanent_loss DECIMAL(36,18) DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    FOREIGN KEY (pool_id) REFERENCES exchange_liquidity_pools(id) ON DELETE CASCADE
);

CREATE INDEX idx_lp_pool ON exchange_liquidity_providers(pool_id);
CREATE INDEX idx_lp_account ON exchange_liquidity_providers(account_id);
CREATE INDEX idx_lp_tenant ON exchange_liquidity_providers(tenant_id);
CREATE UNIQUE INDEX idx_lp_pool_account ON exchange_liquidity_providers(pool_id, account_id);

-- Order book entries table (materialized view of aggregated orders)
CREATE TABLE exchange_order_book_entries (
    trading_pair VARCHAR(20) NOT NULL,
    side VARCHAR(10) NOT NULL,
    price DECIMAL(36,18) NOT NULL,
    tenant_id UUID NOT NULL,
    total_quantity DECIMAL(36,18) NOT NULL,
    order_count INT NOT NULL,
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    PRIMARY KEY (trading_pair, side, price)
);

CREATE INDEX idx_orderbook_tenant ON exchange_order_book_entries(tenant_id);
CREATE INDEX idx_orderbook_pair_side ON exchange_order_book_entries(trading_pair, side, price);

-- Trading pair statistics table
CREATE TABLE exchange_trading_pair_stats (
    trading_pair VARCHAR(20) PRIMARY KEY,
    tenant_id UUID NOT NULL,
    last_price DECIMAL(36,18),
    high_price_24h DECIMAL(36,18),
    low_price_24h DECIMAL(36,18),
    open_price_24h DECIMAL(36,18),
    volume_24h_base DECIMAL(36,18),
    volume_24h_quote DECIMAL(36,18),
    trade_count_24h BIGINT DEFAULT 0,
    price_change_24h DECIMAL(36,18),
    price_change_percent DECIMAL(10,6),
    best_bid_price DECIMAL(36,18),
    best_ask_price DECIMAL(36,18),
    spread DECIMAL(36,18),
    spread_percent DECIMAL(10,6),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_stats_tenant ON exchange_trading_pair_stats(tenant_id);
```

**Testing:**

```go
// internal/domain/exchange/projection/order_test.go
package projection

import (
    "testing"
    "time"
    "github.com/shopspring/decimal"
    "github.com/stretchr/testify/assert"
    "gorm.io/driver/postgres"
    "gorm.io/gorm"
)

func setupTestDB(t *testing.T) *gorm.DB {
    dsn := "host=localhost user=test password=test dbname=test_exchange port=5432"
    db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{})
    assert.NoError(t, err)

    // Auto migrate all projection models
    err = db.AutoMigrate(
        &Order{},
        &Trade{},
        &LiquidityPool{},
        &LiquidityProvider{},
        &OrderBookEntry{},
        &TradingPairStats{},
    )
    assert.NoError(t, err)

    return db
}

func TestOrderProjection(t *testing.T) {
    db := setupTestDB(t)

    order := &Order{
        ID:                "order-123",
        AccountID:         "acc-123",
        TenantID:          "tenant-123",
        TradingPairBase:   "BTC",
        TradingPairQuote:  "USD",
        TradingPair:       "BTC/USD",
        OrderType:         "limit",
        OrderSide:         "buy",
        Price:             decimal.NewFromInt(50000),
        Quantity:          decimal.NewFromFloat(0.5),
        FilledQuantity:    decimal.Zero,
        RemainingQuantity: decimal.NewFromFloat(0.5),
        Status:            "pending",
        CreatedAt:         time.Now(),
        UpdatedAt:         time.Now(),
    }

    err := db.Create(order).Error
    assert.NoError(t, err)

    // Query by trading pair
    var orders []Order
    err = db.Scopes(order.ScopeByTradingPair("BTC/USD")).
        Scopes(order.ScopeActive()).
        Find(&orders).Error
    assert.NoError(t, err)
    assert.Len(t, orders, 1)
    assert.Equal(t, "order-123", orders[0].ID)
}

func TestLiquidityPoolCalculations(t *testing.T) {
    pool := &LiquidityPool{
        ID:            "pool-123",
        TenantID:      "tenant-123",
        TradingPair:   "BTC/USD",
        BaseCurrency:  "BTC",
        QuoteCurrency: "USD",
        BaseReserve:   decimal.NewFromInt(10),
        QuoteReserve:  decimal.NewFromInt(500000),
        TotalShares:   decimal.NewFromInt(1000),
        K:             decimal.NewFromInt(5000000), // 10 * 500000
        FeeRate:       decimal.NewFromFloat(0.003),
    }

    // Test current price calculation
    price := pool.CurrentPrice()
    assert.Equal(t, decimal.NewFromInt(50000), price) // 500000 / 10

    // Test swap output calculation
    inputAmount := decimal.NewFromInt(1) // 1 BTC
    outputAmount := pool.CalculateSwapOutput("BTC", inputAmount)

    // Expected calculation:
    // Fee: 1 * 0.003 = 0.003 BTC
    // Input after fee: 0.997 BTC
    // New base reserve: 10 + 0.997 = 10.997
    // New quote reserve: 5000000 / 10.997 = 454,673.64
    // Output: 500000 - 454,673.64 = 45,326.36 USD

    assert.True(t, outputAmount.GreaterThan(decimal.NewFromInt(45000)))
    assert.True(t, outputAmount.LessThan(decimal.NewFromInt(46000)))
}

func TestTradingPairStats(t *testing.T) {
    db := setupTestDB(t)

    stats := &TradingPairStats{
        TradingPair:    "BTC/USD",
        TenantID:       "tenant-123",
        LastPrice:      decimal.NewFromInt(50000),
        HighPrice24h:   decimal.NewFromInt(52000),
        LowPrice24h:    decimal.NewFromInt(48000),
        OpenPrice24h:   decimal.NewFromInt(49000),
        Volume24hBase:  decimal.NewFromInt(100),
        Volume24hQuote: decimal.NewFromInt(5000000),
        TradeCount24h:  1250,
        UpdatedAt:      time.Now(),
    }

    // Calculate price change
    priceChange := stats.LastPrice.Sub(stats.OpenPrice24h)
    priceChangePercent := priceChange.Div(stats.OpenPrice24h).Mul(decimal.NewFromInt(100))

    stats.PriceChange24h = priceChange
    stats.PriceChangePercent = priceChangePercent

    err := db.Create(stats).Error
    assert.NoError(t, err)

    // Verify calculations
    assert.Equal(t, decimal.NewFromInt(1000), stats.PriceChange24h) // 50000 - 49000
    assert.True(t, stats.PriceChangePercent.Equal(decimal.NewFromFloat(2.04))) // (1000/49000)*100
}
```

**Verification Command:**
```bash
go test -v ./internal/domain/exchange/projection/
psql -d test_exchange -f migrations/006_create_exchange_projections.up.sql
```

**PHP Reference:**
- `app/Domain/Exchange/Models/Order.php`
- `app/Domain/Exchange/Models/Trade.php`
- `app/Domain/Exchange/Models/LiquidityPool.php`
- `app/Domain/Exchange/Models/LiquidityProvider.php`

---

### Task 5.7: Exchange Projectors (Event Handlers)

**ID:** P5-EXCHANGE-007
**Description:** Implement projectors to update read models from domain events
**Priority:** HIGH
**Complexity:** 12 hours

**Dependencies:**
- P5-EXCHANGE-002 (Order Aggregate)
- P5-EXCHANGE-003 (LiquidityPool Aggregate)
- P5-EXCHANGE-006 (Exchange Projections)
- P0-INFRA-003 (Event Sourcing Setup)

**Acceptance Criteria:**
- [ ] All domain events projected to read models
- [ ] Projectors are idempotent
- [ ] Order book entries updated in real-time
- [ ] Trading pair stats calculated correctly
- [ ] Test coverage >90%

**Files to Create:**
```
internal/domain/exchange/projector/
├── order_projector.go
├── trade_projector.go
├── liquidity_pool_projector.go
└── stats_projector.go
```

**Implementation Steps:**

1. **Create Order Projector:**

```go
// internal/domain/exchange/projector/order_projector.go
package projector

import (
    "context"
    "fmt"
    "time"

    "github.com/shopspring/decimal"
    "go.uber.org/zap"
    "gorm.io/gorm"

    "github.com/finaegis/finaegis-go/internal/domain/exchange/event"
    "github.com/finaegis/finaegis-go/internal/domain/exchange/projection"
    eventhorizon "github.com/looplab/eventhorizon"
)

type OrderProjector struct {
    db     *gorm.DB
    logger *zap.Logger
}

func NewOrderProjector(db *gorm.DB, logger *zap.Logger) *OrderProjector {
    return &OrderProjector{
        db:     db,
        logger: logger,
    }
}

// ProjectorType returns the type of projector
func (p *OrderProjector) ProjectorType() string {
    return "exchange.order_projector"
}

// Project handles domain events and updates read models
func (p *OrderProjector) Project(ctx context.Context, evt eventhorizon.Event) error {
    switch e := evt.Data().(type) {
    case *event.OrderPlaced:
        return p.handleOrderPlaced(ctx, evt.AggregateID(), e)
    case *event.OrderPartiallyFilled:
        return p.handleOrderPartiallyFilled(ctx, evt.AggregateID(), e)
    case *event.OrderFilled:
        return p.handleOrderFilled(ctx, evt.AggregateID(), e)
    case *event.OrderCancelled:
        return p.handleOrderCancelled(ctx, evt.AggregateID(), e)
    default:
        return nil
    }
}

func (p *OrderProjector) handleOrderPlaced(
    ctx context.Context,
    aggregateID string,
    evt *event.OrderPlaced,
) error {
    order := &projection.Order{
        ID:                aggregateID,
        AccountID:         evt.AccountID,
        TenantID:          evt.TenantID,
        TradingPairBase:   evt.TradingPair.Base,
        TradingPairQuote:  evt.TradingPair.Quote,
        TradingPair:       fmt.Sprintf("%s/%s", evt.TradingPair.Base, evt.TradingPair.Quote),
        OrderType:         string(evt.OrderType),
        OrderSide:         string(evt.OrderSide),
        Price:             evt.Price,
        Quantity:          evt.Quantity,
        FilledQuantity:    decimal.Zero,
        RemainingQuantity: evt.Quantity,
        Status:            "pending",
        TimeInForce:       string(evt.TimeInForce),
        StopPrice:         evt.StopPrice,
        CreatedAt:         evt.Timestamp,
        UpdatedAt:         evt.Timestamp,
    }

    if err := p.db.WithContext(ctx).Create(order).Error; err != nil {
        p.logger.Error("Failed to create order projection",
            zap.String("order_id", aggregateID),
            zap.Error(err),
        )
        return err
    }

    // Update order book entries
    if err := p.updateOrderBookEntry(ctx, order); err != nil {
        p.logger.Warn("Failed to update order book entry", zap.Error(err))
    }

    return nil
}

func (p *OrderProjector) handleOrderPartiallyFilled(
    ctx context.Context,
    aggregateID string,
    evt *event.OrderPartiallyFilled,
) error {
    updates := map[string]interface{}{
        "filled_quantity":    evt.NewFilledQuantity,
        "remaining_quantity": evt.NewRemainingQuantity,
        "status":             "partially_filled",
        "updated_at":         evt.Timestamp,
    }

    // Calculate average price
    if !evt.NewFilledQuantity.IsZero() {
        updates["average_price"] = evt.FillPrice
    }

    if err := p.db.WithContext(ctx).
        Model(&projection.Order{}).
        Where("id = ?", aggregateID).
        Updates(updates).Error; err != nil {
        return err
    }

    return p.updateOrderBookEntryForFill(ctx, aggregateID, evt.FillQuantity)
}

func (p *OrderProjector) handleOrderFilled(
    ctx context.Context,
    aggregateID string,
    evt *event.OrderFilled,
) error {
    now := time.Now()
    updates := map[string]interface{}{
        "filled_quantity":    evt.TotalFilledQuantity,
        "remaining_quantity": decimal.Zero,
        "status":             "filled",
        "average_price":      evt.AveragePrice,
        "completed_at":       now,
        "updated_at":         now,
    }

    if err := p.db.WithContext(ctx).
        Model(&projection.Order{}).
        Where("id = ?", aggregateID).
        Updates(updates).Error; err != nil {
        return err
    }

    return p.removeOrderBookEntry(ctx, aggregateID)
}

func (p *OrderProjector) handleOrderCancelled(
    ctx context.Context,
    aggregateID string,
    evt *event.OrderCancelled,
) error {
    now := time.Now()
    updates := map[string]interface{}{
        "status":       "cancelled",
        "cancelled_at": now,
        "updated_at":   now,
    }

    if err := p.db.WithContext(ctx).
        Model(&projection.Order{}).
        Where("id = ?", aggregateID).
        Updates(updates).Error; err != nil {
        return err
    }

    return p.removeOrderBookEntry(ctx, aggregateID)
}

func (p *OrderProjector) updateOrderBookEntry(
    ctx context.Context,
    order *projection.Order,
) error {
    // Check if order is limit order
    if order.OrderType != "limit" {
        return nil
    }

    entry := &projection.OrderBookEntry{
        TradingPair:   order.TradingPair,
        Side:          order.OrderSide,
        Price:         order.Price,
        TenantID:      order.TenantID,
        TotalQuantity: order.RemainingQuantity,
        OrderCount:    1,
        UpdatedAt:     time.Now(),
    }

    // Upsert order book entry
    return p.db.WithContext(ctx).
        Clauses(clause.OnConflict{
            Columns: []clause.Column{
                {Name: "trading_pair"},
                {Name: "side"},
                {Name: "price"},
            },
            DoUpdates: clause.Assignments(map[string]interface{}{
                "total_quantity": gorm.Expr("total_quantity + ?", order.RemainingQuantity),
                "order_count":    gorm.Expr("order_count + 1"),
                "updated_at":     time.Now(),
            }),
        }).
        Create(entry).Error
}

func (p *OrderProjector) updateOrderBookEntryForFill(
    ctx context.Context,
    orderID string,
    fillQuantity decimal.Decimal,
) error {
    var order projection.Order
    if err := p.db.WithContext(ctx).First(&order, "id = ?", orderID).Error; err != nil {
        return err
    }

    return p.db.WithContext(ctx).
        Model(&projection.OrderBookEntry{}).
        Where("trading_pair = ? AND side = ? AND price = ?",
            order.TradingPair, order.OrderSide, order.Price).
        Updates(map[string]interface{}{
            "total_quantity": gorm.Expr("total_quantity - ?", fillQuantity),
            "updated_at":     time.Now(),
        }).Error
}

func (p *OrderProjector) removeOrderBookEntry(
    ctx context.Context,
    orderID string,
) error {
    var order projection.Order
    if err := p.db.WithContext(ctx).First(&order, "id = ?", orderID).Error; err != nil {
        return err
    }

    return p.db.WithContext(ctx).
        Where("trading_pair = ? AND side = ? AND price = ?",
            order.TradingPair, order.OrderSide, order.Price).
        Delete(&projection.OrderBookEntry{}).Error
}
```

2. **Create Trade Projector:**

```go
// internal/domain/exchange/projector/trade_projector.go
package projector

import (
    "context"
    "fmt"

    "github.com/shopspring/decimal"
    "go.uber.org/zap"
    "gorm.io/gorm"

    "github.com/finaegis/finaegis-go/internal/domain/exchange/event"
    "github.com/finaegis/finaegis-go/internal/domain/exchange/projection"
    eventhorizon "github.com/looplab/eventhorizon"
)

type TradeProjector struct {
    db     *gorm.DB
    logger *zap.Logger
}

func NewTradeProjector(db *gorm.DB, logger *zap.Logger) *TradeProjector {
    return &TradeProjector{
        db:     db,
        logger: logger,
    }
}

func (p *TradeProjector) ProjectorType() string {
    return "exchange.trade_projector"
}

func (p *TradeProjector) Project(ctx context.Context, evt eventhorizon.Event) error {
    switch e := evt.Data().(type) {
    case *event.OrderPartiallyFilled:
        return p.handleOrderPartiallyFilled(ctx, e)
    case *event.OrderFilled:
        return p.handleOrderFilled(ctx, e)
    default:
        return nil
    }
}

func (p *TradeProjector) handleOrderPartiallyFilled(
    ctx context.Context,
    evt *event.OrderPartiallyFilled,
) error {
    // Create trade record
    trade := &projection.Trade{
        ID:            generateTradeID(),
        TenantID:      evt.TenantID,
        MatchID:       evt.MatchID,
        TradingPair:   fmt.Sprintf("%s/%s", evt.TradingPair.Base, evt.TradingPair.Quote),
        BuyOrderID:    evt.BuyOrderID,
        SellOrderID:   evt.SellOrderID,
        BuyAccountID:  evt.BuyAccountID,
        SellAccountID: evt.SellAccountID,
        Price:         evt.FillPrice,
        Quantity:      evt.FillQuantity,
        TotalValue:    evt.FillPrice.Mul(evt.FillQuantity),
        BuyerFee:      evt.BuyerFee,
        SellerFee:     evt.SellerFee,
        TakerSide:     string(evt.TakerSide),
        ExecutedAt:    evt.Timestamp,
    }

    if err := p.db.WithContext(ctx).Create(trade).Error; err != nil {
        p.logger.Error("Failed to create trade projection",
            zap.String("match_id", evt.MatchID),
            zap.Error(err),
        )
        return err
    }

    return nil
}

func (p *TradeProjector) handleOrderFilled(
    ctx context.Context,
    evt *event.OrderFilled,
) error {
    // The final fill should already be recorded via OrderPartiallyFilled
    // This is just for additional processing if needed
    return nil
}

func generateTradeID() string {
    return uuid.New().String()
}
```

3. **Create Liquidity Pool Projector:**

```go
// internal/domain/exchange/projector/liquidity_pool_projector.go
package projector

import (
    "context"
    "fmt"

    "github.com/shopspring/decimal"
    "go.uber.org/zap"
    "gorm.io/gorm"
    "gorm.io/gorm/clause"

    "github.com/finaegis/finaegis-go/internal/domain/exchange/event"
    "github.com/finaegis/finaegis-go/internal/domain/exchange/projection"
    eventhorizon "github.com/looplab/eventhorizon"
)

type LiquidityPoolProjector struct {
    db     *gorm.DB
    logger *zap.Logger
}

func NewLiquidityPoolProjector(db *gorm.DB, logger *zap.Logger) *LiquidityPoolProjector {
    return &LiquidityPoolProjector{
        db:     db,
        logger: logger,
    }
}

func (p *LiquidityPoolProjector) ProjectorType() string {
    return "exchange.liquidity_pool_projector"
}

func (p *LiquidityPoolProjector) Project(ctx context.Context, evt eventhorizon.Event) error {
    switch e := evt.Data().(type) {
    case *event.LiquidityPoolCreated:
        return p.handlePoolCreated(ctx, evt.AggregateID(), e)
    case *event.LiquidityAdded:
        return p.handleLiquidityAdded(ctx, evt.AggregateID(), e)
    case *event.LiquidityRemoved:
        return p.handleLiquidityRemoved(ctx, evt.AggregateID(), e)
    case *event.SwapExecuted:
        return p.handleSwapExecuted(ctx, evt.AggregateID(), e)
    default:
        return nil
    }
}

func (p *LiquidityPoolProjector) handlePoolCreated(
    ctx context.Context,
    aggregateID string,
    evt *event.LiquidityPoolCreated,
) error {
    pool := &projection.LiquidityPool{
        ID:            aggregateID,
        TenantID:      evt.TenantID,
        TradingPair:   fmt.Sprintf("%s/%s", evt.TradingPair.Base, evt.TradingPair.Quote),
        BaseCurrency:  evt.TradingPair.Base,
        QuoteCurrency: evt.TradingPair.Quote,
        BaseReserve:   evt.InitialBaseAmount,
        QuoteReserve:  evt.InitialQuoteAmount,
        TotalShares:   evt.InitialShares,
        K:             evt.InitialBaseAmount.Mul(evt.InitialQuoteAmount),
        FeeRate:       evt.FeeRate,
        Status:        "active",
        CreatedAt:     evt.Timestamp,
        UpdatedAt:     evt.Timestamp,
    }

    if err := p.db.WithContext(ctx).Create(pool).Error; err != nil {
        return err
    }

    // Create initial liquidity provider
    provider := &projection.LiquidityProvider{
        ID:                 uuid.New().String(),
        PoolID:             aggregateID,
        AccountID:          evt.ProviderAccountID,
        TenantID:           evt.TenantID,
        Shares:             evt.InitialShares,
        InitialBaseAmount:  evt.InitialBaseAmount,
        InitialQuoteAmount: evt.InitialQuoteAmount,
        CurrentBaseValue:   evt.InitialBaseAmount,
        CurrentQuoteValue:  evt.InitialQuoteAmount,
        CreatedAt:          evt.Timestamp,
        UpdatedAt:          evt.Timestamp,
    }

    return p.db.WithContext(ctx).Create(provider).Error
}

func (p *LiquidityPoolProjector) handleLiquidityAdded(
    ctx context.Context,
    aggregateID string,
    evt *event.LiquidityAdded,
) error {
    // Update pool reserves
    if err := p.db.WithContext(ctx).
        Model(&projection.LiquidityPool{}).
        Where("id = ?", aggregateID).
        Updates(map[string]interface{}{
            "base_reserve":  gorm.Expr("base_reserve + ?", evt.BaseAmount),
            "quote_reserve": gorm.Expr("quote_reserve + ?", evt.QuoteAmount),
            "total_shares":  gorm.Expr("total_shares + ?", evt.SharesMinted),
            "k":             gorm.Expr("base_reserve * quote_reserve"),
            "updated_at":    evt.Timestamp,
        }).Error; err != nil {
        return err
    }

    // Upsert liquidity provider
    provider := &projection.LiquidityProvider{
        ID:                 uuid.New().String(),
        PoolID:             aggregateID,
        AccountID:          evt.ProviderAccountID,
        TenantID:           evt.TenantID,
        Shares:             evt.SharesMinted,
        InitialBaseAmount:  evt.BaseAmount,
        InitialQuoteAmount: evt.QuoteAmount,
        CreatedAt:          evt.Timestamp,
        UpdatedAt:          evt.Timestamp,
    }

    return p.db.WithContext(ctx).
        Clauses(clause.OnConflict{
            Columns: []clause.Column{{Name: "pool_id"}, {Name: "account_id"}},
            DoUpdates: clause.Assignments(map[string]interface{}{
                "shares":     gorm.Expr("shares + ?", evt.SharesMinted),
                "updated_at": evt.Timestamp,
            }),
        }).
        Create(provider).Error
}

func (p *LiquidityPoolProjector) handleSwapExecuted(
    ctx context.Context,
    aggregateID string,
    evt *event.SwapExecuted,
) error {
    updates := map[string]interface{}{
        "base_reserve":      evt.NewBaseReserve,
        "quote_reserve":     evt.NewQuoteReserve,
        "k":                 evt.NewBaseReserve.Mul(evt.NewQuoteReserve),
        "total_volume_24h":  gorm.Expr("total_volume_24h + ?", evt.OutputAmount),
        "total_fees_24h":    gorm.Expr("total_fees_24h + ?", evt.FeeAmount),
        "price_impact":      evt.PriceImpact,
        "updated_at":        evt.Timestamp,
    }

    return p.db.WithContext(ctx).
        Model(&projection.LiquidityPool{}).
        Where("id = ?", aggregateID).
        Updates(updates).Error
}
```

**Testing:**

```go
// internal/domain/exchange/projector/order_projector_test.go
package projector

import (
    "context"
    "testing"
    "time"

    "github.com/shopspring/decimal"
    "github.com/stretchr/testify/assert"
    eventhorizon "github.com/looplab/eventhorizon"

    "github.com/finaegis/finaegis-go/internal/domain/exchange/event"
    "github.com/finaegis/finaegis-go/internal/domain/exchange/projection"
)

func TestOrderProjector_OrderPlaced(t *testing.T) {
    db := setupTestDB(t)
    logger := setupTestLogger(t)
    projector := NewOrderProjector(db, logger)

    evt := eventhorizon.NewEvent(
        "OrderPlaced",
        &event.OrderPlaced{
            OrderID:     "order-123",
            AccountID:   "acc-123",
            TenantID:    "tenant-123",
            TradingPair: valueobject.TradingPair{Base: "BTC", Quote: "USD"},
            OrderType:   "limit",
            OrderSide:   "buy",
            Price:       decimal.NewFromInt(50000),
            Quantity:    decimal.NewFromFloat(0.5),
            Timestamp:   time.Now(),
        },
        time.Now(),
        eventhorizon.ForAggregate("Order", "order-123", 1),
    )

    err := projector.Project(context.Background(), evt)
    assert.NoError(t, err)

    // Verify order projection created
    var order projection.Order
    err = db.First(&order, "id = ?", "order-123").Error
    assert.NoError(t, err)
    assert.Equal(t, "BTC/USD", order.TradingPair)
    assert.Equal(t, "pending", order.Status)
    assert.Equal(t, decimal.NewFromFloat(0.5), order.Quantity)

    // Verify order book entry created
    var entry projection.OrderBookEntry
    err = db.First(&entry, "trading_pair = ? AND side = ? AND price = ?",
        "BTC/USD", "buy", decimal.NewFromInt(50000)).Error
    assert.NoError(t, err)
    assert.Equal(t, decimal.NewFromFloat(0.5), entry.TotalQuantity)
}

func TestOrderProjector_OrderFilled(t *testing.T) {
    db := setupTestDB(t)
    logger := setupTestLogger(t)
    projector := NewOrderProjector(db, logger)

    // Create initial order
    order := &projection.Order{
        ID:                "order-123",
        AccountID:         "acc-123",
        TenantID:          "tenant-123",
        TradingPair:       "BTC/USD",
        OrderType:         "limit",
        OrderSide:         "buy",
        Price:             decimal.NewFromInt(50000),
        Quantity:          decimal.NewFromFloat(0.5),
        FilledQuantity:    decimal.Zero,
        RemainingQuantity: decimal.NewFromFloat(0.5),
        Status:            "pending",
        CreatedAt:         time.Now(),
        UpdatedAt:         time.Now(),
    }
    db.Create(order)

    // Fire OrderFilled event
    evt := eventhorizon.NewEvent(
        "OrderFilled",
        &event.OrderFilled{
            OrderID:             "order-123",
            TotalFilledQuantity: decimal.NewFromFloat(0.5),
            AveragePrice:        decimal.NewFromInt(50000),
            Timestamp:           time.Now(),
        },
        time.Now(),
        eventhorizon.ForAggregate("Order", "order-123", 2),
    )

    err := projector.Project(context.Background(), evt)
    assert.NoError(t, err)

    // Verify order status updated
    err = db.First(&order, "id = ?", "order-123").Error
    assert.NoError(t, err)
    assert.Equal(t, "filled", order.Status)
    assert.NotNil(t, order.CompletedAt)
    assert.Equal(t, decimal.NewFromFloat(0.5), order.FilledQuantity)
    assert.Equal(t, decimal.Zero, order.RemainingQuantity)
}
```

**Verification Command:**
```bash
go test -v ./internal/domain/exchange/projector/
```

**PHP Reference:**
- `app/Domain/Exchange/Projectors/OrderProjector.php`
- `app/Domain/Exchange/Projectors/TradeProjector.php`
- `app/Domain/Exchange/Projectors/LiquidityPoolProjector.php`

---

### Task 5.8: Exchange Queries (CQRS Read Side)

**ID:** P5-EXCHANGE-008
**Description:** Define query objects for Exchange read operations
**Priority:** HIGH
**Complexity:** 6 hours

**Dependencies:**
- P5-EXCHANGE-006 (Exchange Projections)
- P1-FOUNDATION-008 (Query Bus)

**Acceptance Criteria:**
- [ ] All query objects defined
- [ ] Validation logic implemented
- [ ] Pagination support added
- [ ] Filter options configured
- [ ] Test coverage >90%

**Files to Create:**
```
internal/application/query/exchange/
├── get_order_book.go
├── get_order.go
├── get_orders.go
├── get_trade.go
├── get_trades.go
├── get_liquidity_pool.go
├── get_trading_pair_stats.go
└── get_account_orders.go
```

**Implementation Steps:**

```go
// internal/application/query/exchange/get_order_book.go
package query

import (
    "github.com/shopspring/decimal"
)

type GetOrderBookQuery struct {
    TradingPair string
    TenantID    string
    Depth       int  // Number of price levels (default: 20)
}

func (q GetOrderBookQuery) Validate() error {
    if q.TradingPair == "" {
        return ErrTradingPairRequired
    }
    if q.Depth <= 0 || q.Depth > 100 {
        q.Depth = 20
    }
    return nil
}

type OrderBookResult struct {
    TradingPair string               `json:"trading_pair"`
    Bids        []OrderBookLevel     `json:"bids"`
    Asks        []OrderBookLevel     `json:"asks"`
    UpdatedAt   time.Time            `json:"updated_at"`
}

type OrderBookLevel struct {
    Price      decimal.Decimal `json:"price"`
    Quantity   decimal.Decimal `json:"quantity"`
    OrderCount int             `json:"order_count"`
}

// internal/application/query/exchange/get_orders.go
package query

type GetOrdersQuery struct {
    TenantID      string
    AccountID     string
    TradingPair   string
    Status        string  // pending, filled, cancelled
    Side          string  // buy, sell
    StartDate     *time.Time
    EndDate       *time.Time
    Page          int
    PageSize      int
}

func (q *GetOrdersQuery) Validate() error {
    if q.TenantID == "" {
        return ErrTenantIDRequired
    }
    if q.Page <= 0 {
        q.Page = 1
    }
    if q.PageSize <= 0 || q.PageSize > 100 {
        q.PageSize = 50
    }
    return nil
}

type OrdersResult struct {
    Orders     []OrderSummary `json:"orders"`
    Total      int64          `json:"total"`
    Page       int            `json:"page"`
    PageSize   int            `json:"page_size"`
    TotalPages int            `json:"total_pages"`
}

type OrderSummary struct {
    ID                string          `json:"id"`
    TradingPair       string          `json:"trading_pair"`
    OrderType         string          `json:"order_type"`
    OrderSide         string          `json:"order_side"`
    Price             decimal.Decimal `json:"price"`
    Quantity          decimal.Decimal `json:"quantity"`
    FilledQuantity    decimal.Decimal `json:"filled_quantity"`
    RemainingQuantity decimal.Decimal `json:"remaining_quantity"`
    Status            string          `json:"status"`
    CreatedAt         time.Time       `json:"created_at"`
    UpdatedAt         time.Time       `json:"updated_at"`
}

// internal/application/query/exchange/get_trading_pair_stats.go
package query

type GetTradingPairStatsQuery struct {
    TradingPair string
    TenantID    string
}

type TradingPairStatsResult struct {
    TradingPair        string          `json:"trading_pair"`
    LastPrice          decimal.Decimal `json:"last_price"`
    HighPrice24h       decimal.Decimal `json:"high_24h"`
    LowPrice24h        decimal.Decimal `json:"low_24h"`
    OpenPrice24h       decimal.Decimal `json:"open_24h"`
    Volume24hBase      decimal.Decimal `json:"volume_24h_base"`
    Volume24hQuote     decimal.Decimal `json:"volume_24h_quote"`
    TradeCount24h      int64           `json:"trade_count_24h"`
    PriceChange24h     decimal.Decimal `json:"price_change_24h"`
    PriceChangePercent decimal.Decimal `json:"price_change_percent"`
    BestBid            decimal.Decimal `json:"best_bid"`
    BestAsk            decimal.Decimal `json:"best_ask"`
    Spread             decimal.Decimal `json:"spread"`
    SpreadPercent      decimal.Decimal `json:"spread_percent"`
    UpdatedAt          time.Time       `json:"updated_at"`
}
```

**PHP Reference:**
- `app/Domain/Exchange/Queries/GetOrderBookQuery.php`
- `app/Domain/Exchange/Queries/GetOrdersQuery.php`

---


### Task 5.9: Exchange Query Handlers

**ID:** P5-EXCHANGE-009
**Description:** Implement query handlers for Exchange read operations
**Priority:** HIGH
**Complexity:** 10 hours

**Dependencies:**
- P5-EXCHANGE-006 (Exchange Projections)
- P5-EXCHANGE-008 (Exchange Queries)
- P1-FOUNDATION-008 (Query Bus)

**Acceptance Criteria:**
- [ ] All query handlers implemented
- [ ] Efficient database queries with proper indexing
- [ ] Caching strategy implemented
- [ ] Pagination working correctly
- [ ] Test coverage >90%

**Files to Create:**
```
internal/application/query/exchange/handler/
├── get_order_book_handler.go
├── get_orders_handler.go
├── get_liquidity_pool_handler.go
└── get_trading_pair_stats_handler.go
```

**Implementation Steps:**

```go
// internal/application/query/exchange/handler/get_order_book_handler.go
package handler

import (
    "context"
    "fmt"
    "time"

    "go.uber.org/zap"
    "gorm.io/gorm"

    "github.com/finaegis/finaegis-go/internal/application/query/exchange"
    "github.com/finaegis/finaegis-go/internal/domain/exchange/projection"
)

type GetOrderBookHandler struct {
    db     *gorm.DB
    cache  cache.Cache
    logger *zap.Logger
}

func NewGetOrderBookHandler(
    db *gorm.DB,
    cache cache.Cache,
    logger *zap.Logger,
) *GetOrderBookHandler {
    return &GetOrderBookHandler{
        db:     db,
        cache:  cache,
        logger: logger,
    }
}

func (h *GetOrderBookHandler) Handle(
    ctx context.Context,
    q query.GetOrderBookQuery,
) (*query.OrderBookResult, error) {
    if err := q.Validate(); err != nil {
        return nil, err
    }

    // Check cache first
    cacheKey := fmt.Sprintf("orderbook:%s:%s", q.TenantID, q.TradingPair)
    var result query.OrderBookResult
    if err := h.cache.Get(ctx, cacheKey, &result); err == nil {
        return &result, nil
    }

    // Get bids (buy orders) - highest price first
    var bids []projection.OrderBookEntry
    if err := h.db.WithContext(ctx).
        Where("trading_pair = ? AND side = ? AND tenant_id = ?",
            q.TradingPair, "buy", q.TenantID).
        Order("price DESC").
        Limit(q.Depth).
        Find(&bids).Error; err != nil {
        return nil, err
    }

    // Get asks (sell orders) - lowest price first
    var asks []projection.OrderBookEntry
    if err := h.db.WithContext(ctx).
        Where("trading_pair = ? AND side = ? AND tenant_id = ?",
            q.TradingPair, "sell", q.TenantID).
        Order("price ASC").
        Limit(q.Depth).
        Find(&asks).Error; err != nil {
        return nil, err
    }

    // Build result
    result = query.OrderBookResult{
        TradingPair: q.TradingPair,
        Bids:        make([]query.OrderBookLevel, len(bids)),
        Asks:        make([]query.OrderBookLevel, len(asks)),
        UpdatedAt:   time.Now(),
    }

    for i, bid := range bids {
        result.Bids[i] = query.OrderBookLevel{
            Price:      bid.Price,
            Quantity:   bid.TotalQuantity,
            OrderCount: bid.OrderCount,
        }
    }

    for i, ask := range asks {
        result.Asks[i] = query.OrderBookLevel{
            Price:      ask.Price,
            Quantity:   ask.TotalQuantity,
            OrderCount: ask.OrderCount,
        }
    }

    // Cache for 1 second (order book changes frequently)
    h.cache.Set(ctx, cacheKey, result, time.Second)

    return &result, nil
}

// internal/application/query/exchange/handler/get_orders_handler.go
package handler

import (
    "context"

    "go.uber.org/zap"
    "gorm.io/gorm"

    "github.com/finaegis/finaegis-go/internal/application/query/exchange"
    "github.com/finaegis/finaegis-go/internal/domain/exchange/projection"
)

type GetOrdersHandler struct {
    db     *gorm.DB
    logger *zap.Logger
}

func NewGetOrdersHandler(db *gorm.DB, logger *zap.Logger) *GetOrdersHandler {
    return &GetOrdersHandler{
        db:     db,
        logger: logger,
    }
}

func (h *GetOrdersHandler) Handle(
    ctx context.Context,
    q query.GetOrdersQuery,
) (*query.OrdersResult, error) {
    if err := q.Validate(); err != nil {
        return nil, err
    }

    // Build query
    db := h.db.WithContext(ctx).
        Model(&projection.Order{}).
        Where("tenant_id = ?", q.TenantID)

    if q.AccountID != "" {
        db = db.Where("account_id = ?", q.AccountID)
    }
    if q.TradingPair != "" {
        db = db.Where("trading_pair = ?", q.TradingPair)
    }
    if q.Status != "" {
        db = db.Where("status = ?", q.Status)
    }
    if q.Side != "" {
        db = db.Where("order_side = ?", q.Side)
    }
    if q.StartDate != nil {
        db = db.Where("created_at >= ?", q.StartDate)
    }
    if q.EndDate != nil {
        db = db.Where("created_at <= ?", q.EndDate)
    }

    // Count total
    var total int64
    if err := db.Count(&total).Error; err != nil {
        return nil, err
    }

    // Get paginated orders
    var orders []projection.Order
    offset := (q.Page - 1) * q.PageSize
    if err := db.
        Order("created_at DESC").
        Offset(offset).
        Limit(q.PageSize).
        Find(&orders).Error; err != nil {
        return nil, err
    }

    // Convert to summary
    summaries := make([]query.OrderSummary, len(orders))
    for i, order := range orders {
        summaries[i] = query.OrderSummary{
            ID:                order.ID,
            TradingPair:       order.TradingPair,
            OrderType:         order.OrderType,
            OrderSide:         order.OrderSide,
            Price:             order.Price,
            Quantity:          order.Quantity,
            FilledQuantity:    order.FilledQuantity,
            RemainingQuantity: order.RemainingQuantity,
            Status:            order.Status,
            CreatedAt:         order.CreatedAt,
            UpdatedAt:         order.UpdatedAt,
        }
    }

    totalPages := int(total) / q.PageSize
    if int(total)%q.PageSize > 0 {
        totalPages++
    }

    return &query.OrdersResult{
        Orders:     summaries,
        Total:      total,
        Page:       q.Page,
        PageSize:   q.PageSize,
        TotalPages: totalPages,
    }, nil
}

// internal/application/query/exchange/handler/get_trading_pair_stats_handler.go
package handler

import (
    "context"
    "fmt"
    "time"

    "go.uber.org/zap"
    "gorm.io/gorm"

    "github.com/finaegis/finaegis-go/internal/application/query/exchange"
    "github.com/finaegis/finaegis-go/internal/domain/exchange/projection"
)

type GetTradingPairStatsHandler struct {
    db     *gorm.DB
    cache  cache.Cache
    logger *zap.Logger
}

func NewGetTradingPairStatsHandler(
    db *gorm.DB,
    cache cache.Cache,
    logger *zap.Logger,
) *GetTradingPairStatsHandler {
    return &GetTradingPairStatsHandler{
        db:     db,
        cache:  cache,
        logger: logger,
    }
}

func (h *GetTradingPairStatsHandler) Handle(
    ctx context.Context,
    q query.GetTradingPairStatsQuery,
) (*query.TradingPairStatsResult, error) {
    // Check cache
    cacheKey := fmt.Sprintf("stats:%s:%s", q.TenantID, q.TradingPair)
    var result query.TradingPairStatsResult
    if err := h.cache.Get(ctx, cacheKey, &result); err == nil {
        return &result, nil
    }

    // Get from database
    var stats projection.TradingPairStats
    if err := h.db.WithContext(ctx).
        Where("trading_pair = ? AND tenant_id = ?", q.TradingPair, q.TenantID).
        First(&stats).Error; err != nil {
        if err == gorm.ErrRecordNotFound {
            return nil, ErrTradingPairNotFound
        }
        return nil, err
    }

    result = query.TradingPairStatsResult{
        TradingPair:        stats.TradingPair,
        LastPrice:          stats.LastPrice,
        HighPrice24h:       stats.HighPrice24h,
        LowPrice24h:        stats.LowPrice24h,
        OpenPrice24h:       stats.OpenPrice24h,
        Volume24hBase:      stats.Volume24hBase,
        Volume24hQuote:     stats.Volume24hQuote,
        TradeCount24h:      stats.TradeCount24h,
        PriceChange24h:     stats.PriceChange24h,
        PriceChangePercent: stats.PriceChangePercent,
        BestBid:            stats.BestBidPrice,
        BestAsk:            stats.BestAskPrice,
        Spread:             stats.Spread,
        SpreadPercent:      stats.SpreadPercent,
        UpdatedAt:          stats.UpdatedAt,
    }

    // Cache for 5 seconds
    h.cache.Set(ctx, cacheKey, result, 5*time.Second)

    return &result, nil
}
```

**Testing:**

```go
// internal/application/query/exchange/handler/get_order_book_handler_test.go
package handler

import (
    "context"
    "testing"

    "github.com/shopspring/decimal"
    "github.com/stretchr/testify/assert"

    "github.com/finaegis/finaegis-go/internal/application/query/exchange"
    "github.com/finaegis/finaegis-go/internal/domain/exchange/projection"
)

func TestGetOrderBookHandler(t *testing.T) {
    db := setupTestDB(t)
    cache := setupTestCache(t)
    logger := setupTestLogger(t)

    handler := NewGetOrderBookHandler(db, cache, logger)

    // Create test order book entries
    entries := []projection.OrderBookEntry{
        // Bids (buy orders)
        {
            TradingPair:   "BTC/USD",
            Side:          "buy",
            Price:         decimal.NewFromInt(50000),
            TenantID:      "tenant-123",
            TotalQuantity: decimal.NewFromFloat(1.5),
            OrderCount:    3,
        },
        {
            TradingPair:   "BTC/USD",
            Side:          "buy",
            Price:         decimal.NewFromInt(49900),
            TenantID:      "tenant-123",
            TotalQuantity: decimal.NewFromFloat(2.0),
            OrderCount:    4,
        },
        // Asks (sell orders)
        {
            TradingPair:   "BTC/USD",
            Side:          "sell",
            Price:         decimal.NewFromInt(50100),
            TenantID:      "tenant-123",
            TotalQuantity: decimal.NewFromFloat(1.2),
            OrderCount:    2,
        },
        {
            TradingPair:   "BTC/USD",
            Side:          "sell",
            Price:         decimal.NewFromInt(50200),
            TenantID:      "tenant-123",
            TotalQuantity: decimal.NewFromFloat(0.8),
            OrderCount:    1,
        },
    }

    for _, entry := range entries {
        db.Create(&entry)
    }

    // Execute query
    result, err := handler.Handle(context.Background(), query.GetOrderBookQuery{
        TradingPair: "BTC/USD",
        TenantID:    "tenant-123",
        Depth:       20,
    })

    assert.NoError(t, err)
    assert.NotNil(t, result)
    assert.Equal(t, "BTC/USD", result.TradingPair)
    assert.Len(t, result.Bids, 2)
    assert.Len(t, result.Asks, 2)

    // Verify bids are sorted by price DESC
    assert.True(t, result.Bids[0].Price.GreaterThan(result.Bids[1].Price))

    // Verify asks are sorted by price ASC
    assert.True(t, result.Asks[0].Price.LessThan(result.Asks[1].Price))
}

func TestGetOrdersHandler_Pagination(t *testing.T) {
    db := setupTestDB(t)
    logger := setupTestLogger(t)
    handler := NewGetOrdersHandler(db, logger)

    // Create 25 test orders
    for i := 0; i < 25; i++ {
        order := &projection.Order{
            ID:                fmt.Sprintf("order-%d", i),
            AccountID:         "acc-123",
            TenantID:          "tenant-123",
            TradingPair:       "BTC/USD",
            OrderType:         "limit",
            OrderSide:         "buy",
            Price:             decimal.NewFromInt(50000 + int64(i)),
            Quantity:          decimal.NewFromFloat(0.1),
            FilledQuantity:    decimal.Zero,
            RemainingQuantity: decimal.NewFromFloat(0.1),
            Status:            "pending",
            CreatedAt:         time.Now().Add(-time.Duration(i) * time.Hour),
            UpdatedAt:         time.Now(),
        }
        db.Create(order)
    }

    // Query first page
    result, err := handler.Handle(context.Background(), query.GetOrdersQuery{
        TenantID:    "tenant-123",
        AccountID:   "acc-123",
        TradingPair: "BTC/USD",
        Page:        1,
        PageSize:    10,
    })

    assert.NoError(t, err)
    assert.NotNil(t, result)
    assert.Len(t, result.Orders, 10)
    assert.Equal(t, int64(25), result.Total)
    assert.Equal(t, 3, result.TotalPages)

    // Query second page
    result2, err := handler.Handle(context.Background(), query.GetOrdersQuery{
        TenantID:    "tenant-123",
        AccountID:   "acc-123",
        TradingPair: "BTC/USD",
        Page:        2,
        PageSize:    10,
    })

    assert.NoError(t, err)
    assert.Len(t, result2.Orders, 10)
}
```

**Verification Command:**
```bash
go test -v ./internal/application/query/exchange/handler/
```

**PHP Reference:**
- `app/Domain/Exchange/Queries/Handlers/GetOrderBookHandler.php`
- `app/Domain/Exchange/Queries/Handlers/GetOrdersHandler.php`

---

### Task 5.10: Exchange REST API

**ID:** P5-EXCHANGE-010
**Description:** Implement REST API endpoints for Exchange domain
**Priority:** HIGH
**Complexity:** 12 hours

**Dependencies:**
- P5-EXCHANGE-005 (Exchange Commands & Handlers)
- P5-EXCHANGE-009 (Exchange Query Handlers)
- P1-FOUNDATION-009 (HTTP Server Setup)

**Acceptance Criteria:**
- [ ] All endpoints implemented with proper routing
- [ ] Request validation working
- [ ] Response serialization correct
- [ ] Error handling comprehensive
- [ ] OpenAPI documentation generated
- [ ] Rate limiting configured
- [ ] Test coverage >90%

**Files to Create:**
```
internal/interfaces/rest/handler/exchange/
├── order_handler.go
├── liquidity_pool_handler.go
├── trading_pair_handler.go
└── orderbook_handler.go

api/openapi/exchange.yaml
```

**Implementation Steps:**

```go
// internal/interfaces/rest/handler/exchange/order_handler.go
package exchange

import (
    "net/http"

    "github.com/gin-gonic/gin"
    "github.com/shopspring/decimal"
    "go.uber.org/zap"

    "github.com/finaegis/finaegis-go/internal/application/command/exchange"
    "github.com/finaegis/finaegis-go/internal/application/query/exchange"
    "github.com/finaegis/finaegis-go/internal/shared/cqrs/bus"
)

type OrderHandler struct {
    commandBus *bus.CommandBus
    queryBus   *bus.QueryBus
    logger     *zap.Logger
}

func NewOrderHandler(
    commandBus *bus.CommandBus,
    queryBus *bus.QueryBus,
    logger *zap.Logger,
) *OrderHandler {
    return &OrderHandler{
        commandBus: commandBus,
        queryBus:   queryBus,
        logger:     logger,
    }
}

// PlaceOrder godoc
// @Summary Place a new order
// @Description Place a limit, market, stop, or stop-limit order
// @Tags Exchange
// @Accept json
// @Produce json
// @Param order body PlaceOrderRequest true "Order details"
// @Success 201 {object} OrderResponse
// @Failure 400 {object} ErrorResponse
// @Failure 401 {object} ErrorResponse
// @Failure 422 {object} ErrorResponse
// @Router /api/v1/exchange/orders [post]
func (h *OrderHandler) PlaceOrder(c *gin.Context) {
    var req PlaceOrderRequest
    if err := c.ShouldBindJSON(&req); err != nil {
        c.JSON(http.StatusBadRequest, ErrorResponse{
            Error:   "invalid_request",
            Message: err.Error(),
        })
        return
    }

    // Get account ID from context (set by auth middleware)
    accountID := c.GetString("account_id")
    tenantID := c.GetString("tenant_id")

    // Parse price
    var price *decimal.Decimal
    if req.Price != "" {
        p, err := decimal.NewFromString(req.Price)
        if err != nil {
            c.JSON(http.StatusBadRequest, ErrorResponse{
                Error:   "invalid_price",
                Message: "Price must be a valid decimal number",
            })
            return
        }
        price = &p
    }

    // Parse quantity
    quantity, err := decimal.NewFromString(req.Quantity)
    if err != nil {
        c.JSON(http.StatusBadRequest, ErrorResponse{
            Error:   "invalid_quantity",
            Message: "Quantity must be a valid decimal number",
        })
        return
    }

    // Create command
    cmd := command.PlaceOrderCommand{
        OrderID:     uuid.New().String(),
        AccountID:   accountID,
        TenantID:    tenantID,
        TradingPair: parseTradingPair(req.TradingPair),
        OrderType:   valueobject.OrderType(req.OrderType),
        OrderSide:   valueobject.OrderSide(req.OrderSide),
        Price:       price,
        Quantity:    quantity,
        TimeInForce: valueobject.TimeInForce(req.TimeInForce),
    }

    // Execute command
    if err := h.commandBus.Dispatch(c.Request.Context(), cmd); err != nil {
        h.logger.Error("Failed to place order",
            zap.Error(err),
            zap.String("account_id", accountID),
        )

        switch err {
        case command.ErrInsufficientFunds:
            c.JSON(http.StatusUnprocessableEntity, ErrorResponse{
                Error:   "insufficient_funds",
                Message: "Insufficient funds to place order",
            })
        default:
            c.JSON(http.StatusInternalServerError, ErrorResponse{
                Error:   "internal_error",
                Message: "Failed to place order",
            })
        }
        return
    }

    c.JSON(http.StatusCreated, OrderResponse{
        OrderID: cmd.OrderID,
        Status:  "pending",
    })
}

// GetOrders godoc
// @Summary Get account orders
// @Description Get list of orders for the authenticated account
// @Tags Exchange
// @Produce json
// @Param trading_pair query string false "Trading pair filter"
// @Param status query string false "Order status filter"
// @Param side query string false "Order side filter"
// @Param page query int false "Page number" default(1)
// @Param page_size query int false "Page size" default(50)
// @Success 200 {object} OrdersListResponse
// @Failure 401 {object} ErrorResponse
// @Router /api/v1/exchange/orders [get]
func (h *OrderHandler) GetOrders(c *gin.Context) {
    accountID := c.GetString("account_id")
    tenantID := c.GetString("tenant_id")

    page := c.GetInt("page")
    if page == 0 {
        page = 1
    }

    pageSize := c.GetInt("page_size")
    if pageSize == 0 {
        pageSize = 50
    }

    q := query.GetOrdersQuery{
        TenantID:    tenantID,
        AccountID:   accountID,
        TradingPair: c.Query("trading_pair"),
        Status:      c.Query("status"),
        Side:        c.Query("side"),
        Page:        page,
        PageSize:    pageSize,
    }

    result, err := h.queryBus.Execute(c.Request.Context(), q)
    if err != nil {
        c.JSON(http.StatusInternalServerError, ErrorResponse{
            Error:   "internal_error",
            Message: "Failed to retrieve orders",
        })
        return
    }

    c.JSON(http.StatusOK, result)
}

// CancelOrder godoc
// @Summary Cancel an order
// @Description Cancel a pending or partially filled order
// @Tags Exchange
// @Produce json
// @Param id path string true "Order ID"
// @Success 200 {object} OrderResponse
// @Failure 400 {object} ErrorResponse
// @Failure 404 {object} ErrorResponse
// @Router /api/v1/exchange/orders/{id}/cancel [post]
func (h *OrderHandler) CancelOrder(c *gin.Context) {
    orderID := c.Param("id")
    accountID := c.GetString("account_id")

    cmd := command.CancelOrderCommand{
        OrderID:   orderID,
        AccountID: accountID,
    }

    if err := h.commandBus.Dispatch(c.Request.Context(), cmd); err != nil {
        switch err {
        case command.ErrOrderNotFound:
            c.JSON(http.StatusNotFound, ErrorResponse{
                Error:   "order_not_found",
                Message: "Order not found",
            })
        case command.ErrOrderNotCancellable:
            c.JSON(http.StatusBadRequest, ErrorResponse{
                Error:   "order_not_cancellable",
                Message: "Order cannot be cancelled",
            })
        default:
            c.JSON(http.StatusInternalServerError, ErrorResponse{
                Error:   "internal_error",
                Message: "Failed to cancel order",
            })
        }
        return
    }

    c.JSON(http.StatusOK, OrderResponse{
        OrderID: orderID,
        Status:  "cancelled",
    })
}

// Request/Response DTOs
type PlaceOrderRequest struct {
    TradingPair string `json:"trading_pair" binding:"required" example:"BTC/USD"`
    OrderType   string `json:"order_type" binding:"required,oneof=market limit stop stop_limit"`
    OrderSide   string `json:"order_side" binding:"required,oneof=buy sell"`
    Price       string `json:"price" example:"50000.00"`
    Quantity    string `json:"quantity" binding:"required" example:"0.5"`
    TimeInForce string `json:"time_in_force" default:"gtc" example:"gtc"`
}

type OrderResponse struct {
    OrderID string `json:"order_id"`
    Status  string `json:"status"`
}

type ErrorResponse struct {
    Error   string `json:"error"`
    Message string `json:"message"`
}

// internal/interfaces/rest/handler/exchange/orderbook_handler.go
package exchange

import (
    "net/http"

    "github.com/gin-gonic/gin"
    "go.uber.org/zap"

    "github.com/finaegis/finaegis-go/internal/application/query/exchange"
    "github.com/finaegis/finaegis-go/internal/shared/cqrs/bus"
)

type OrderBookHandler struct {
    queryBus *bus.QueryBus
    logger   *zap.Logger
}

func NewOrderBookHandler(queryBus *bus.QueryBus, logger *zap.Logger) *OrderBookHandler {
    return &OrderBookHandler{
        queryBus: queryBus,
        logger:   logger,
    }
}

// GetOrderBook godoc
// @Summary Get order book
// @Description Get current order book for a trading pair
// @Tags Exchange
// @Produce json
// @Param trading_pair path string true "Trading pair" example:"BTC/USD"
// @Param depth query int false "Depth (max 100)" default(20)
// @Success 200 {object} query.OrderBookResult
// @Failure 400 {object} ErrorResponse
// @Router /api/v1/exchange/orderbook/{trading_pair} [get]
func (h *OrderBookHandler) GetOrderBook(c *gin.Context) {
    tradingPair := c.Param("trading_pair")
    tenantID := c.GetString("tenant_id")

    depth := c.GetInt("depth")
    if depth == 0 {
        depth = 20
    }

    q := query.GetOrderBookQuery{
        TradingPair: tradingPair,
        TenantID:    tenantID,
        Depth:       depth,
    }

    result, err := h.queryBus.Execute(c.Request.Context(), q)
    if err != nil {
        c.JSON(http.StatusInternalServerError, ErrorResponse{
            Error:   "internal_error",
            Message: "Failed to retrieve order book",
        })
        return
    }

    c.JSON(http.StatusOK, result)
}

// GetTradingPairStats godoc
// @Summary Get trading pair statistics
// @Description Get 24h statistics for a trading pair
// @Tags Exchange
// @Produce json
// @Param trading_pair path string true "Trading pair" example:"BTC/USD"
// @Success 200 {object} query.TradingPairStatsResult
// @Failure 404 {object} ErrorResponse
// @Router /api/v1/exchange/stats/{trading_pair} [get]
func (h *OrderBookHandler) GetTradingPairStats(c *gin.Context) {
    tradingPair := c.Param("trading_pair")
    tenantID := c.GetString("tenant_id")

    q := query.GetTradingPairStatsQuery{
        TradingPair: tradingPair,
        TenantID:    tenantID,
    }

    result, err := h.queryBus.Execute(c.Request.Context(), q)
    if err != nil {
        if err == query.ErrTradingPairNotFound {
            c.JSON(http.StatusNotFound, ErrorResponse{
                Error:   "trading_pair_not_found",
                Message: "Trading pair not found",
            })
            return
        }
        c.JSON(http.StatusInternalServerError, ErrorResponse{
            Error:   "internal_error",
            Message: "Failed to retrieve statistics",
        })
        return
    }

    c.JSON(http.StatusOK, result)
}

// Register routes
func RegisterExchangeRoutes(router *gin.RouterGroup, handlers *ExchangeHandlers) {
    exchange := router.Group("/exchange")
    {
        // Order endpoints
        exchange.POST("/orders", handlers.Order.PlaceOrder)
        exchange.GET("/orders", handlers.Order.GetOrders)
        exchange.GET("/orders/:id", handlers.Order.GetOrder)
        exchange.POST("/orders/:id/cancel", handlers.Order.CancelOrder)

        // Order book endpoints
        exchange.GET("/orderbook/:trading_pair", handlers.OrderBook.GetOrderBook)
        exchange.GET("/stats/:trading_pair", handlers.OrderBook.GetTradingPairStats)

        // Liquidity pool endpoints
        exchange.POST("/pools", handlers.LiquidityPool.CreatePool)
        exchange.POST("/pools/:id/liquidity", handlers.LiquidityPool.AddLiquidity)
        exchange.DELETE("/pools/:id/liquidity", handlers.LiquidityPool.RemoveLiquidity)
        exchange.POST("/pools/:id/swap", handlers.LiquidityPool.ExecuteSwap)
        exchange.GET("/pools/:id", handlers.LiquidityPool.GetPool)
    }
}
```

**Testing:**

```go
// internal/interfaces/rest/handler/exchange/order_handler_test.go
package exchange

import (
    "bytes"
    "encoding/json"
    "net/http"
    "net/http/httptest"
    "testing"

    "github.com/gin-gonic/gin"
    "github.com/stretchr/testify/assert"
)

func TestOrderHandler_PlaceOrder(t *testing.T) {
    // Setup
    gin.SetMode(gin.TestMode)
    router := gin.New()

    commandBus := setupTestCommandBus(t)
    queryBus := setupTestQueryBus(t)
    logger := setupTestLogger(t)

    handler := NewOrderHandler(commandBus, queryBus, logger)
    router.POST("/orders", func(c *gin.Context) {
        c.Set("account_id", "acc-123")
        c.Set("tenant_id", "tenant-123")
        handler.PlaceOrder(c)
    })

    // Test valid order
    req := PlaceOrderRequest{
        TradingPair: "BTC/USD",
        OrderType:   "limit",
        OrderSide:   "buy",
        Price:       "50000.00",
        Quantity:    "0.5",
        TimeInForce: "gtc",
    }

    body, _ := json.Marshal(req)
    w := httptest.NewRecorder()
    r, _ := http.NewRequest("POST", "/orders", bytes.NewBuffer(body))
    r.Header.Set("Content-Type", "application/json")

    router.ServeHTTP(w, r)

    assert.Equal(t, http.StatusCreated, w.Code)

    var resp OrderResponse
    json.Unmarshal(w.Body.Bytes(), &resp)
    assert.NotEmpty(t, resp.OrderID)
    assert.Equal(t, "pending", resp.Status)
}

func TestOrderHandler_InvalidPrice(t *testing.T) {
    // Setup
    router, handler := setupTestRouter(t)
    router.POST("/orders", handler.PlaceOrder)

    req := PlaceOrderRequest{
        TradingPair: "BTC/USD",
        OrderType:   "limit",
        OrderSide:   "buy",
        Price:       "invalid",  // Invalid price
        Quantity:    "0.5",
    }

    body, _ := json.Marshal(req)
    w := httptest.NewRecorder()
    r, _ := http.NewRequest("POST", "/orders", bytes.NewBuffer(body))
    r.Header.Set("Content-Type", "application/json")

    router.ServeHTTP(w, r)

    assert.Equal(t, http.StatusBadRequest, w.Code)

    var resp ErrorResponse
    json.Unmarshal(w.Body.Bytes(), &resp)
    assert.Equal(t, "invalid_price", resp.Error)
}
```

**Verification Command:**
```bash
go test -v ./internal/interfaces/rest/handler/exchange/
curl -X POST http://localhost:8080/api/v1/exchange/orders \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{"trading_pair":"BTC/USD","order_type":"limit","order_side":"buy","price":"50000","quantity":"0.5"}'
```

**PHP Reference:**
- `app/Http/Controllers/Api/Exchange/OrderController.php`
- `app/Http/Controllers/Api/Exchange/LiquidityPoolController.php`

---


### Task 5.11: External Exchange Integration (Binance)

**ID:** P5-EXCHANGE-011
**Description:** Integrate with Binance API for external liquidity and price feeds
**Priority:** MEDIUM
**Complexity:** 16 hours

**Dependencies:**
- P5-EXCHANGE-001 (Order Value Objects)
- P1-FOUNDATION-005 (HTTP Client Setup)

**Acceptance Criteria:**
- [ ] Binance REST API client implemented
- [ ] WebSocket price feed integrated
- [ ] Order placement to Binance working
- [ ] Balance synchronization implemented
- [ ] Circuit breaker pattern implemented
- [ ] Rate limiting compliant with Binance limits
- [ ] Test coverage >85%

**Files to Create:**
```
internal/infrastructure/exchange/binance/
├── client.go
├── websocket.go
├── mapper.go
├── types.go
└── rate_limiter.go
```

**Implementation Steps:**

```go
// internal/infrastructure/exchange/binance/client.go
package binance

import (
    "context"
    "crypto/hmac"
    "crypto/sha256"
    "encoding/hex"
    "encoding/json"
    "fmt"
    "net/http"
    "net/url"
    "strconv"
    "time"

    "github.com/shopspring/decimal"
    "go.uber.org/zap"

    "github.com/finaegis/finaegis-go/internal/shared/http/client"
)

const (
    BinanceBaseURL = "https://api.binance.com"
    BinanceWSURL   = "wss://stream.binance.com:9443/ws"
)

type Client struct {
    apiKey      string
    secretKey   string
    httpClient  *client.HTTPClient
    rateLimiter *RateLimiter
    logger      *zap.Logger
}

func NewClient(apiKey, secretKey string, logger *zap.Logger) *Client {
    return &Client{
        apiKey:      apiKey,
        secretKey:   secretKey,
        httpClient:  client.NewHTTPClient(BinanceBaseURL, 10*time.Second),
        rateLimiter: NewRateLimiter(),
        logger:      logger,
    }
}

// GetTicker gets 24hr ticker price change statistics
func (c *Client) GetTicker(ctx context.Context, symbol string) (*Ticker, error) {
    if err := c.rateLimiter.Wait(ctx); err != nil {
        return nil, err
    }

    var ticker Ticker
    err := c.httpClient.Get(ctx, "/api/v3/ticker/24hr", map[string]string{
        "symbol": symbol,
    }, &ticker)

    if err != nil {
        c.logger.Error("Failed to get ticker",
            zap.String("symbol", symbol),
            zap.Error(err),
        )
        return nil, err
    }

    return &ticker, nil
}

// GetOrderBook gets order book depth
func (c *Client) GetOrderBook(ctx context.Context, symbol string, limit int) (*OrderBook, error) {
    if err := c.rateLimiter.Wait(ctx); err != nil {
        return nil, err
    }

    params := map[string]string{
        "symbol": symbol,
        "limit":  strconv.Itoa(limit),
    }

    var orderBook OrderBook
    err := c.httpClient.Get(ctx, "/api/v3/depth", params, &orderBook)
    if err != nil {
        return nil, err
    }

    return &orderBook, nil
}

// PlaceOrder places a new order
func (c *Client) PlaceOrder(ctx context.Context, req PlaceOrderRequest) (*OrderResponse, error) {
    if err := c.rateLimiter.Wait(ctx); err != nil {
        return nil, err
    }

    params := map[string]string{
        "symbol":    req.Symbol,
        "side":      req.Side,
        "type":      req.Type,
        "quantity":  req.Quantity.String(),
        "timestamp": strconv.FormatInt(time.Now().UnixMilli(), 10),
    }

    if req.Price != nil {
        params["price"] = req.Price.String()
    }
    if req.TimeInForce != "" {
        params["timeInForce"] = req.TimeInForce
    }

    // Sign request
    signature := c.sign(params)
    params["signature"] = signature

    var response OrderResponse
    headers := map[string]string{
        "X-MBX-APIKEY": c.apiKey,
    }

    err := c.httpClient.PostForm(ctx, "/api/v3/order", params, headers, &response)
    if err != nil {
        c.logger.Error("Failed to place order",
            zap.String("symbol", req.Symbol),
            zap.Error(err),
        )
        return nil, err
    }

    return &response, nil
}

// CancelOrder cancels an active order
func (c *Client) CancelOrder(ctx context.Context, symbol, orderID string) error {
    if err := c.rateLimiter.Wait(ctx); err != nil {
        return err
    }

    params := map[string]string{
        "symbol":    symbol,
        "orderId":   orderID,
        "timestamp": strconv.FormatInt(time.Now().UnixMilli(), 10),
    }

    signature := c.sign(params)
    params["signature"] = signature

    headers := map[string]string{
        "X-MBX-APIKEY": c.apiKey,
    }

    return c.httpClient.Delete(ctx, "/api/v3/order", params, headers)
}

// GetAccountInfo gets account information
func (c *Client) GetAccountInfo(ctx context.Context) (*AccountInfo, error) {
    if err := c.rateLimiter.Wait(ctx); err != nil {
        return nil, err
    }

    params := map[string]string{
        "timestamp": strconv.FormatInt(time.Now().UnixMilli(), 10),
    }

    signature := c.sign(params)
    params["signature"] = signature

    headers := map[string]string{
        "X-MBX-APIKEY": c.apiKey,
    }

    var info AccountInfo
    err := c.httpClient.Get(ctx, "/api/v3/account", params, headers, &info)
    if err != nil {
        return nil, err
    }

    return &info, nil
}

// sign creates HMAC SHA256 signature
func (c *Client) sign(params map[string]string) string {
    // Build query string
    query := url.Values{}
    for k, v := range params {
        query.Add(k, v)
    }
    queryString := query.Encode()

    // Create signature
    mac := hmac.New(sha256.New, []byte(c.secretKey))
    mac.Write([]byte(queryString))
    signature := hex.EncodeToString(mac.Sum(nil))

    return signature
}

// Types
type Ticker struct {
    Symbol             string          `json:"symbol"`
    PriceChange        string          `json:"priceChange"`
    PriceChangePercent string          `json:"priceChangePercent"`
    LastPrice          string          `json:"lastPrice"`
    HighPrice          string          `json:"highPrice"`
    LowPrice           string          `json:"lowPrice"`
    Volume             string          `json:"volume"`
    QuoteVolume        string          `json:"quoteVolume"`
}

type OrderBook struct {
    LastUpdateID int64               `json:"lastUpdateId"`
    Bids         [][]string          `json:"bids"`
    Asks         [][]string          `json:"asks"`
}

type PlaceOrderRequest struct {
    Symbol      string
    Side        string  // BUY, SELL
    Type        string  // LIMIT, MARKET
    TimeInForce string  // GTC, IOC, FOK
    Quantity    decimal.Decimal
    Price       *decimal.Decimal
}

type OrderResponse struct {
    Symbol              string `json:"symbol"`
    OrderID             int64  `json:"orderId"`
    ClientOrderID       string `json:"clientOrderId"`
    TransactTime        int64  `json:"transactTime"`
    Price               string `json:"price"`
    OrigQty             string `json:"origQty"`
    ExecutedQty         string `json:"executedQty"`
    Status              string `json:"status"`
    TimeInForce         string `json:"timeInForce"`
    Type                string `json:"type"`
    Side                string `json:"side"`
}

type AccountInfo struct {
    MakerCommission  int              `json:"makerCommission"`
    TakerCommission  int              `json:"takerCommission"`
    BuyerCommission  int              `json:"buyerCommission"`
    SellerCommission int              `json:"sellerCommission"`
    CanTrade         bool             `json:"canTrade"`
    CanWithdraw      bool             `json:"canWithdraw"`
    CanDeposit       bool             `json:"canDeposit"`
    UpdateTime       int64            `json:"updateTime"`
    Balances         []Balance        `json:"balances"`
}

type Balance struct {
    Asset  string `json:"asset"`
    Free   string `json:"free"`
    Locked string `json:"locked"`
}

// internal/infrastructure/exchange/binance/websocket.go
package binance

import (
    "context"
    "encoding/json"
    "fmt"

    "github.com/gorilla/websocket"
    "go.uber.org/zap"
)

type PriceUpdateHandler func(symbol string, price decimal.Decimal, timestamp time.Time)

type WebSocketClient struct {
    conn    *websocket.Conn
    logger  *zap.Logger
    handler PriceUpdateHandler
}

func NewWebSocketClient(logger *zap.Logger, handler PriceUpdateHandler) *WebSocketClient {
    return &WebSocketClient{
        logger:  logger,
        handler: handler,
    }
}

func (ws *WebSocketClient) Connect(ctx context.Context, symbols []string) error {
    // Build stream names
    streams := make([]string, len(symbols))
    for i, symbol := range symbols {
        streams[i] = fmt.Sprintf("%s@ticker", strings.ToLower(symbol))
    }
    streamStr := strings.Join(streams, "/")

    url := fmt.Sprintf("%s/stream?streams=%s", BinanceWSURL, streamStr)

    conn, _, err := websocket.DefaultDialer.Dial(url, nil)
    if err != nil {
        return err
    }

    ws.conn = conn

    // Start reading messages
    go ws.readMessages(ctx)

    return nil
}

func (ws *WebSocketClient) readMessages(ctx context.Context) {
    defer ws.conn.Close()

    for {
        select {
        case <-ctx.Done():
            return
        default:
            _, message, err := ws.conn.ReadMessage()
            if err != nil {
                ws.logger.Error("WebSocket read error", zap.Error(err))
                return
            }

            var msg TickerMessage
            if err := json.Unmarshal(message, &msg); err != nil {
                ws.logger.Warn("Failed to unmarshal message", zap.Error(err))
                continue
            }

            // Parse price
            price, err := decimal.NewFromString(msg.Data.LastPrice)
            if err != nil {
                ws.logger.Warn("Failed to parse price", zap.Error(err))
                continue
            }

            // Call handler
            if ws.handler != nil {
                timestamp := time.UnixMilli(msg.Data.EventTime)
                ws.handler(msg.Data.Symbol, price, timestamp)
            }
        }
    }
}

func (ws *WebSocketClient) Close() error {
    if ws.conn != nil {
        return ws.conn.Close()
    }
    return nil
}

type TickerMessage struct {
    Stream string      `json:"stream"`
    Data   TickerData  `json:"data"`
}

type TickerData struct {
    EventType          string `json:"e"`
    EventTime          int64  `json:"E"`
    Symbol             string `json:"s"`
    LastPrice          string `json:"c"`
    PriceChange        string `json:"p"`
    PriceChangePercent string `json:"P"`
    Volume             string `json:"v"`
    QuoteVolume        string `json:"q"`
}

// internal/infrastructure/exchange/binance/rate_limiter.go
package binance

import (
    "context"
    "time"

    "golang.org/x/time/rate"
)

// RateLimiter implements Binance rate limiting
// Binance limits: 1200 requests per minute, 10 orders per second
type RateLimiter struct {
    requestLimiter *rate.Limiter
    orderLimiter   *rate.Limiter
}

func NewRateLimiter() *RateLimiter {
    return &RateLimiter{
        // 1200 requests per minute = 20 requests per second
        requestLimiter: rate.NewLimiter(rate.Every(50*time.Millisecond), 20),
        // 10 orders per second
        orderLimiter:   rate.NewLimiter(rate.Every(100*time.Millisecond), 10),
    }
}

func (rl *RateLimiter) Wait(ctx context.Context) error {
    return rl.requestLimiter.Wait(ctx)
}

func (rl *RateLimiter) WaitForOrder(ctx context.Context) error {
    if err := rl.orderLimiter.Wait(ctx); err != nil {
        return err
    }
    return rl.requestLimiter.Wait(ctx)
}
```

**Testing:**

```go
// internal/infrastructure/exchange/binance/client_test.go
package binance

import (
    "context"
    "testing"

    "github.com/shopspring/decimal"
    "github.com/stretchr/testify/assert"
)

func TestBinanceClient_GetTicker(t *testing.T) {
    client := NewClient("test_api_key", "test_secret", setupTestLogger(t))

    ticker, err := client.GetTicker(context.Background(), "BTCUSDT")
    assert.NoError(t, err)
    assert.NotNil(t, ticker)
    assert.Equal(t, "BTCUSDT", ticker.Symbol)
    assert.NotEmpty(t, ticker.LastPrice)
}

func TestBinanceClient_PlaceOrder(t *testing.T) {
    client := NewClient("test_api_key", "test_secret", setupTestLogger(t))

    price := decimal.NewFromInt(50000)
    req := PlaceOrderRequest{
        Symbol:      "BTCUSDT",
        Side:        "BUY",
        Type:        "LIMIT",
        TimeInForce: "GTC",
        Quantity:    decimal.NewFromFloat(0.001),
        Price:       &price,
    }

    response, err := client.PlaceOrder(context.Background(), req)
    assert.NoError(t, err)
    assert.NotNil(t, response)
    assert.NotZero(t, response.OrderID)
}

func TestBinanceClient_Signature(t *testing.T) {
    client := NewClient("test_api_key", "test_secret", setupTestLogger(t))

    params := map[string]string{
        "symbol":    "BTCUSDT",
        "side":      "BUY",
        "type":      "LIMIT",
        "timestamp": "1234567890",
    }

    signature := client.sign(params)
    assert.NotEmpty(t, signature)
    assert.Len(t, signature, 64) // SHA256 hex = 64 chars
}
```

**Verification Command:**
```bash
go test -v ./internal/infrastructure/exchange/binance/
```

**PHP Reference:**
- `app/Services/Exchange/Connectors/BinanceConnector.php`
- `app/Services/Exchange/ExchangeAggregator.php`

---

### Task 5.12: Fee Tier Management

**ID:** P5-EXCHANGE-012
**Description:** Implement dynamic fee tier system based on trading volume
**Priority:** MEDIUM
**Complexity:** 8 hours

**Dependencies:**
- P5-EXCHANGE-007 (Exchange Projectors)
- P2-ACCOUNT-010 (Account Domain Complete)

**Acceptance Criteria:**
- [ ] Fee tier calculation logic implemented
- [ ] Volume-based tier assignment working
- [ ] Fee discounts applied correctly
- [ ] Monthly volume tracking accurate
- [ ] Test coverage >90%

**Files to Create:**
```
internal/domain/exchange/service/
├── fee_calculator.go
└── fee_tier_manager.go

internal/domain/exchange/valueobject/
└── fee_tier.go
```

**Implementation Steps:**

```go
// internal/domain/exchange/valueobject/fee_tier.go
package valueobject

import (
    "github.com/shopspring/decimal"
)

type FeeTier string

const (
    FeeTierRetail      FeeTier = "retail"
    FeeTierBronze      FeeTier = "bronze"
    FeeTierSilver      FeeTier = "silver"
    FeeTierGold        FeeTier = "gold"
    FeeTierPlatinum    FeeTier = "platinum"
    FeeTierVIP         FeeTier = "vip"
)

type FeeTierConfig struct {
    Tier                FeeTier
    MinimumVolume30d    decimal.Decimal  // Minimum 30-day volume in USD
    MakerFeeRate        decimal.Decimal  // Maker fee rate (e.g., 0.001 = 0.1%)
    TakerFeeRate        decimal.Decimal  // Taker fee rate (e.g., 0.002 = 0.2%)
}

var DefaultFeeTiers = []FeeTierConfig{
    {
        Tier:             FeeTierRetail,
        MinimumVolume30d: decimal.Zero,
        MakerFeeRate:     decimal.NewFromFloat(0.002),  // 0.2%
        TakerFeeRate:     decimal.NewFromFloat(0.003),  // 0.3%
    },
    {
        Tier:             FeeTierBronze,
        MinimumVolume30d: decimal.NewFromInt(100000),    // $100k
        MakerFeeRate:     decimal.NewFromFloat(0.0015),  // 0.15%
        TakerFeeRate:     decimal.NewFromFloat(0.0025),  // 0.25%
    },
    {
        Tier:             FeeTierSilver,
        MinimumVolume30d: decimal.NewFromInt(500000),    // $500k
        MakerFeeRate:     decimal.NewFromFloat(0.001),   // 0.1%
        TakerFeeRate:     decimal.NewFromFloat(0.002),   // 0.2%
    },
    {
        Tier:             FeeTierGold,
        MinimumVolume30d: decimal.NewFromInt(2000000),   // $2M
        MakerFeeRate:     decimal.NewFromFloat(0.0008),  // 0.08%
        TakerFeeRate:     decimal.NewFromFloat(0.0015),  // 0.15%
    },
    {
        Tier:             FeeTierPlatinum,
        MinimumVolume30d: decimal.NewFromInt(10000000),  // $10M
        MakerFeeRate:     decimal.NewFromFloat(0.0005),  // 0.05%
        TakerFeeRate:     decimal.NewFromFloat(0.001),   // 0.1%
    },
    {
        Tier:             FeeTierVIP,
        MinimumVolume30d: decimal.NewFromInt(50000000),  // $50M
        MakerFeeRate:     decimal.NewFromFloat(0.0002),  // 0.02%
        TakerFeeRate:     decimal.NewFromFloat(0.0005),  // 0.05%
    },
}

func GetFeeTierConfig(tier FeeTier) FeeTierConfig {
    for _, config := range DefaultFeeTiers {
        if config.Tier == tier {
            return config
        }
    }
    return DefaultFeeTiers[0] // Default to retail
}

// internal/domain/exchange/service/fee_calculator.go
package service

import (
    "context"

    "github.com/shopspring/decimal"
    "gorm.io/gorm"

    "github.com/finaegis/finaegis-go/internal/domain/exchange/projection"
    "github.com/finaegis/finaegis-go/internal/domain/exchange/valueobject"
)

type FeeCalculator struct {
    db *gorm.DB
}

func NewFeeCalculator(db *gorm.DB) *FeeCalculator {
    return &FeeCalculator{db: db}
}

func (fc *FeeCalculator) CalculateFee(
    ctx context.Context,
    accountID string,
    tradingValue decimal.Decimal,
    isMaker bool,
) (decimal.Decimal, error) {
    // Get account's fee tier
    tier, err := fc.GetAccountFeeTier(ctx, accountID)
    if err != nil {
        return decimal.Zero, err
    }

    config := valueobject.GetFeeTierConfig(tier)

    var feeRate decimal.Decimal
    if isMaker {
        feeRate = config.MakerFeeRate
    } else {
        feeRate = config.TakerFeeRate
    }

    fee := tradingValue.Mul(feeRate)
    return fee, nil
}

func (fc *FeeCalculator) GetAccountFeeTier(
    ctx context.Context,
    accountID string,
) (valueobject.FeeTier, error) {
    // Calculate 30-day trading volume
    volume30d, err := fc.Calculate30DayVolume(ctx, accountID)
    if err != nil {
        return valueobject.FeeTierRetail, err
    }

    // Determine tier based on volume
    var selectedTier valueobject.FeeTier = valueobject.FeeTierRetail

    for i := len(valueobject.DefaultFeeTiers) - 1; i >= 0; i-- {
        tierConfig := valueobject.DefaultFeeTiers[i]
        if volume30d.GreaterThanOrEqual(tierConfig.MinimumVolume30d) {
            selectedTier = tierConfig.Tier
            break
        }
    }

    return selectedTier, nil
}

func (fc *FeeCalculator) Calculate30DayVolume(
    ctx context.Context,
    accountID string,
) (decimal.Decimal, error) {
    cutoffDate := time.Now().AddDate(0, 0, -30)

    // Calculate buy volume
    var buyVolume decimal.Decimal
    err := fc.db.WithContext(ctx).
        Model(&projection.Trade{}).
        Where("buy_account_id = ? AND executed_at >= ?", accountID, cutoffDate).
        Select("COALESCE(SUM(total_value), 0)").
        Scan(&buyVolume).Error
    if err != nil {
        return decimal.Zero, err
    }

    // Calculate sell volume
    var sellVolume decimal.Decimal
    err = fc.db.WithContext(ctx).
        Model(&projection.Trade{}).
        Where("sell_account_id = ? AND executed_at >= ?", accountID, cutoffDate).
        Select("COALESCE(SUM(total_value), 0)").
        Scan(&sellVolume).Error
    if err != nil {
        return decimal.Zero, err
    }

    totalVolume := buyVolume.Add(sellVolume)
    return totalVolume, nil
}

// CalculateFeesForMatch calculates fees for both buyer and seller
func (fc *FeeCalculator) CalculateFeesForMatch(
    ctx context.Context,
    buyAccountID string,
    sellAccountID string,
    matchValue decimal.Decimal,
    buyerIsMaker bool,
) (buyerFee, sellerFee decimal.Decimal, err error) {
    // Calculate buyer fee
    buyerFee, err = fc.CalculateFee(ctx, buyAccountID, matchValue, buyerIsMaker)
    if err != nil {
        return decimal.Zero, decimal.Zero, err
    }

    // Calculate seller fee
    sellerIsMaker := !buyerIsMaker
    sellerFee, err = fc.CalculateFee(ctx, sellAccountID, matchValue, sellerIsMaker)
    if err != nil {
        return decimal.Zero, decimal.Zero, err
    }

    return buyerFee, sellerFee, nil
}
```

**Testing:**

```go
// internal/domain/exchange/service/fee_calculator_test.go
package service

import (
    "context"
    "testing"
    "time"

    "github.com/shopspring/decimal"
    "github.com/stretchr/testify/assert"

    "github.com/finaegis/finaegis-go/internal/domain/exchange/projection"
    "github.com/finaegis/finaegis-go/internal/domain/exchange/valueobject"
)

func TestFeeCalculator_GetAccountFeeTier(t *testing.T) {
    db := setupTestDB(t)
    calculator := NewFeeCalculator(db)

    accountID := "acc-trader-123"

    // Create trades totaling $600,000 in last 30 days
    createTestTrades(t, db, accountID, decimal.NewFromInt(600000))

    tier, err := calculator.GetAccountFeeTier(context.Background(), accountID)
    assert.NoError(t, err)
    assert.Equal(t, valueobject.FeeTierSilver, tier) // $500k threshold
}

func TestFeeCalculator_CalculateFee(t *testing.T) {
    db := setupTestDB(t)
    calculator := NewFeeCalculator(db)

    tests := []struct {
        name          string
        volume30d     decimal.Decimal
        tradingValue  decimal.Decimal
        isMaker       bool
        expectedTier  valueobject.FeeTier
        expectedFee   decimal.Decimal
    }{
        {
            name:          "Retail tier maker",
            volume30d:     decimal.NewFromInt(50000),
            tradingValue:  decimal.NewFromInt(10000),
            isMaker:       true,
            expectedTier:  valueobject.FeeTierRetail,
            expectedFee:   decimal.NewFromInt(20), // 10000 * 0.002
        },
        {
            name:          "Bronze tier taker",
            volume30d:     decimal.NewFromInt(150000),
            tradingValue:  decimal.NewFromInt(10000),
            isMaker:       false,
            expectedTier:  valueobject.FeeTierBronze,
            expectedFee:   decimal.NewFromInt(25), // 10000 * 0.0025
        },
        {
            name:          "Gold tier maker",
            volume30d:     decimal.NewFromInt(3000000),
            tradingValue:  decimal.NewFromInt(100000),
            isMaker:       true,
            expectedTier:  valueobject.FeeTierGold,
            expectedFee:   decimal.NewFromInt(80), // 100000 * 0.0008
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            accountID := "acc-test-" + tt.name

            // Create trades for volume
            createTestTrades(t, db, accountID, tt.volume30d)

            // Calculate fee
            fee, err := calculator.CalculateFee(
                context.Background(),
                accountID,
                tt.tradingValue,
                tt.isMaker,
            )

            assert.NoError(t, err)
            assert.True(t, fee.Equal(tt.expectedFee),
                "Expected %s but got %s", tt.expectedFee, fee)
        })
    }
}

func createTestTrades(t *testing.T, db *gorm.DB, accountID string, totalVolume decimal.Decimal) {
    // Split volume across 10 trades in last 30 days
    volumePerTrade := totalVolume.Div(decimal.NewFromInt(10))

    for i := 0; i < 10; i++ {
        trade := &projection.Trade{
            ID:            fmt.Sprintf("trade-%s-%d", accountID, i),
            TenantID:      "tenant-123",
            MatchID:       uuid.New().String(),
            TradingPair:   "BTC/USD",
            BuyAccountID:  accountID,
            SellAccountID: "acc-seller",
            Price:         decimal.NewFromInt(50000),
            Quantity:      decimal.NewFromFloat(0.1),
            TotalValue:    volumePerTrade,
            ExecutedAt:    time.Now().AddDate(0, 0, -i-1),
        }
        db.Create(trade)
    }
}
```

**Verification Command:**
```bash
go test -v ./internal/domain/exchange/service/
```

**PHP Reference:**
- `app/Domain/Exchange/Services/FeeCalculator.php`
- `app/Domain/Exchange/ValueObjects/FeeTier.php`

---


### Task 5.13: Exchange Performance Testing & Benchmarks

**ID:** P5-EXCHANGE-013
**Description:** Implement comprehensive performance tests and benchmarks
**Priority:** HIGH
**Complexity:** 10 hours

**Dependencies:**
- P5-EXCHANGE-004 (Order Matching Service)
- P5-EXCHANGE-010 (Exchange REST API)

**Acceptance Criteria:**
- [ ] Order matching benchmark >10,000 matches/second
- [ ] API endpoint latency <50ms p99
- [ ] Load test handles 1,000 concurrent users
- [ ] Memory usage optimized
- [ ] Database query performance profiled

**Files to Create:**
```
test/performance/exchange/
├── order_matching_benchmark_test.go
├── api_load_test.go
└── database_benchmark_test.go
```

**Implementation Steps:**

```go
// test/performance/exchange/order_matching_benchmark_test.go
package exchange_test

import (
    "context"
    "fmt"
    "testing"

    "github.com/shopspring/decimal"

    "github.com/finaegis/finaegis-go/internal/domain/exchange/aggregate"
    "github.com/finaegis/finaegis-go/internal/domain/exchange/service"
    "github.com/finaegis/finaegis-go/internal/domain/exchange/valueobject"
)

func BenchmarkOrderMatching_Sequential(b *testing.B) {
    matchingService := setupMatchingService(b)
    tradingPair := valueobject.NewTradingPair("BTC", "USD")

    // Pre-populate order book with 1000 sell orders
    for i := 0; i < 1000; i++ {
        price := decimal.NewFromInt(50000 + int64(i))
        order := createTestOrder(
            fmt.Sprintf("sell-order-%d", i),
            tradingPair,
            valueobject.OrderSideSell,
            price,
            decimal.NewFromFloat(0.1),
        )
        matchingService.AddOrder(context.Background(), order)
    }

    b.ResetTimer()

    // Benchmark buy order matching
    for i := 0; i < b.N; i++ {
        buyOrder := createTestOrder(
            fmt.Sprintf("buy-order-%d", i),
            tradingPair,
            valueobject.OrderSideBuy,
            decimal.NewFromInt(51000),
            decimal.NewFromFloat(0.1),
        )

        matches := matchingService.MatchOrder(context.Background(), buyOrder)
        _ = matches
    }
}

func BenchmarkOrderMatching_Concurrent(b *testing.B) {
    matchingService := setupMatchingService(b)
    tradingPair := valueobject.NewTradingPair("BTC", "USD")

    // Pre-populate order book
    for i := 0; i < 1000; i++ {
        price := decimal.NewFromInt(50000 + int64(i))
        order := createTestOrder(
            fmt.Sprintf("sell-order-%d", i),
            tradingPair,
            valueobject.OrderSideSell,
            price,
            decimal.NewFromFloat(0.1),
        )
        matchingService.AddOrder(context.Background(), order)
    }

    b.ResetTimer()
    b.RunParallel(func(pb *testing.PB) {
        i := 0
        for pb.Next() {
            buyOrder := createTestOrder(
                fmt.Sprintf("buy-order-concurrent-%d", i),
                tradingPair,
                valueobject.OrderSideBuy,
                decimal.NewFromInt(51000),
                decimal.NewFromFloat(0.05),
            )

            matches := matchingService.MatchOrder(context.Background(), buyOrder)
            _ = matches
            i++
        }
    })
}

func BenchmarkAMMSwap(b *testing.B) {
    pool := &aggregate.LiquidityPool{}
    pool.Initialize(
        "pool-123",
        valueobject.NewTradingPair("BTC", "USD"),
        decimal.NewFromInt(100),    // 100 BTC
        decimal.NewFromInt(5000000), // $5M
        decimal.NewFromFloat(0.003), // 0.3% fee
    )

    b.ResetTimer()

    for i := 0; i < b.N; i++ {
        // Swap 1 BTC for USD
        _, err := pool.ExecuteSwap(
            context.Background(),
            "acc-trader",
            "BTC",
            decimal.NewFromInt(1),
            decimal.NewFromInt(45000), // Min output with slippage
        )
        if err != nil {
            b.Fatal(err)
        }
    }
}

// test/performance/exchange/api_load_test.go
package exchange_test

import (
    "bytes"
    "encoding/json"
    "fmt"
    "net/http"
    "net/http/httptest"
    "sync"
    "testing"
    "time"

    "github.com/gin-gonic/gin"
    "github.com/stretchr/testify/assert"
)

func TestAPILoad_PlaceOrder(t *testing.T) {
    router := setupTestRouter(t)
    server := httptest.NewServer(router)
    defer server.Close()

    concurrentUsers := 100
    ordersPerUser := 100
    totalOrders := concurrentUsers * ordersPerUser

    var wg sync.WaitGroup
    results := make(chan time.Duration, totalOrders)
    errors := make(chan error, totalOrders)

    startTime := time.Now()

    for u := 0; u < concurrentUsers; u++ {
        wg.Add(1)
        go func(userID int) {
            defer wg.Done()

            client := &http.Client{Timeout: 5 * time.Second}

            for i := 0; i < ordersPerUser; i++ {
                reqStart := time.Now()

                req := map[string]interface{}{
                    "trading_pair": "BTC/USD",
                    "order_type":   "limit",
                    "order_side":   "buy",
                    "price":        "50000",
                    "quantity":     "0.001",
                }

                body, _ := json.Marshal(req)
                resp, err := client.Post(
                    server.URL+"/api/v1/exchange/orders",
                    "application/json",
                    bytes.NewBuffer(body),
                )

                reqDuration := time.Since(reqStart)
                results <- reqDuration

                if err != nil {
                    errors <- err
                    continue
                }

                resp.Body.Close()

                if resp.StatusCode != http.StatusCreated {
                    errors <- fmt.Errorf("unexpected status: %d", resp.StatusCode)
                }
            }
        }(u)
    }

    wg.Wait()
    close(results)
    close(errors)

    totalDuration := time.Since(startTime)

    // Calculate statistics
    var durations []time.Duration
    for d := range results {
        durations = append(durations, d)
    }

    errorCount := len(errors)

    // Calculate percentiles
    p50 := calculatePercentile(durations, 50)
    p95 := calculatePercentile(durations, 95)
    p99 := calculatePercentile(durations, 99)

    throughput := float64(totalOrders) / totalDuration.Seconds()

    t.Logf("Load Test Results:")
    t.Logf("  Total Orders: %d", totalOrders)
    t.Logf("  Concurrent Users: %d", concurrentUsers)
    t.Logf("  Duration: %v", totalDuration)
    t.Logf("  Throughput: %.2f orders/sec", throughput)
    t.Logf("  Latency p50: %v", p50)
    t.Logf("  Latency p95: %v", p95)
    t.Logf("  Latency p99: %v", p99)
    t.Logf("  Errors: %d", errorCount)

    // Assertions
    assert.Less(t, p99, 100*time.Millisecond, "p99 latency should be <100ms")
    assert.Greater(t, throughput, 1000.0, "Throughput should be >1000 orders/sec")
    assert.Less(t, errorCount, totalOrders/100, "Error rate should be <1%")
}

func calculatePercentile(durations []time.Duration, percentile int) time.Duration {
    if len(durations) == 0 {
        return 0
    }

    sort.Slice(durations, func(i, j int) bool {
        return durations[i] < durations[j]
    })

    index := (len(durations) * percentile) / 100
    if index >= len(durations) {
        index = len(durations) - 1
    }

    return durations[index]
}
```

**Verification Command:**
```bash
# Run benchmarks
go test -bench=. -benchmem -benchtime=10s ./test/performance/exchange/

# Run load test
go test -v -run TestAPILoad ./test/performance/exchange/

# Profile CPU usage
go test -bench=BenchmarkOrderMatching -cpuprofile=cpu.prof ./test/performance/exchange/
go tool pprof cpu.prof
```

**Performance Targets:**
- Order matching: >10,000 matches/second
- API latency p99: <50ms
- Database query: <10ms for order book
- Memory: <500MB for 100k active orders

---

### Task 5.14: Exchange CLI Testing Tool

**ID:** P5-EXCHANGE-014
**Description:** Build CLI tool for manual testing and simulation
**Priority:** MEDIUM
**Complexity:** 8 hours

**Dependencies:**
- P5-EXCHANGE-005 (Exchange Commands & Handlers)
- P5-EXCHANGE-009 (Exchange Query Handlers)

**Acceptance Criteria:**
- [ ] Interactive CLI with commands
- [ ] Order placement simulation working
- [ ] Market making bot included
- [ ] Order book visualization implemented
- [ ] Test scenarios documented

**Files to Create:**
```
cmd/exchange-cli/
├── main.go
└── commands/
    ├── place_order.go
    ├── view_orderbook.go
    ├── market_maker.go
    └── simulate_trading.go
```

**Implementation Steps:**

```go
// cmd/exchange-cli/main.go
package main

import (
    "fmt"
    "os"

    "github.com/spf13/cobra"
    "go.uber.org/zap"

    "github.com/finaegis/finaegis-go/cmd/exchange-cli/commands"
)

var rootCmd = &cobra.Command{
    Use:   "exchange-cli",
    Short: "Exchange CLI testing tool",
    Long:  `Interactive CLI tool for testing and simulating exchange operations`,
}

func main() {
    // Initialize logger
    logger, _ := zap.NewDevelopment()
    defer logger.Sync()

    // Add commands
    rootCmd.AddCommand(commands.NewPlaceOrderCmd(logger))
    rootCmd.AddCommand(commands.NewViewOrderBookCmd(logger))
    rootCmd.AddCommand(commands.NewMarketMakerCmd(logger))
    rootCmd.AddCommand(commands.NewSimulateCmd(logger))

    if err := rootCmd.Execute(); err != nil {
        fmt.Fprintf(os.Stderr, "Error: %v\n", err)
        os.Exit(1)
    }
}

// cmd/exchange-cli/commands/place_order.go
package commands

import (
    "context"
    "fmt"

    "github.com/shopspring/decimal"
    "github.com/spf13/cobra"
    "go.uber.org/zap"

    "github.com/finaegis/finaegis-go/internal/application/command/exchange"
    "github.com/finaegis/finaegis-go/internal/domain/exchange/valueobject"
)

func NewPlaceOrderCmd(logger *zap.Logger) *cobra.Command {
    var (
        accountID   string
        tradingPair string
        orderType   string
        orderSide   string
        price       string
        quantity    string
    )

    cmd := &cobra.Command{
        Use:   "place-order",
        Short: "Place a test order",
        RunE: func(cmd *cobra.Command, args []string) error {
            commandBus := setupCommandBus(logger)

            priceDecimal, err := decimal.NewFromString(price)
            if err != nil {
                return fmt.Errorf("invalid price: %w", err)
            }

            quantityDecimal, err := decimal.NewFromString(quantity)
            if err != nil {
                return fmt.Errorf("invalid quantity: %w", err)
            }

            orderCmd := command.PlaceOrderCommand{
                OrderID:     uuid.New().String(),
                AccountID:   accountID,
                TenantID:    "tenant-test",
                TradingPair: parseTradingPair(tradingPair),
                OrderType:   valueobject.OrderType(orderType),
                OrderSide:   valueobject.OrderSide(orderSide),
                Price:       &priceDecimal,
                Quantity:    quantityDecimal,
            }

            if err := commandBus.Dispatch(context.Background(), orderCmd); err != nil {
                return fmt.Errorf("failed to place order: %w", err)
            }

            fmt.Printf("✅ Order placed successfully: %s\n", orderCmd.OrderID)
            return nil
        },
    }

    cmd.Flags().StringVar(&accountID, "account", "acc-test-1", "Account ID")
    cmd.Flags().StringVar(&tradingPair, "pair", "BTC/USD", "Trading pair")
    cmd.Flags().StringVar(&orderType, "type", "limit", "Order type (limit, market)")
    cmd.Flags().StringVar(&orderSide, "side", "buy", "Order side (buy, sell)")
    cmd.Flags().StringVar(&price, "price", "", "Price (required for limit orders)")
    cmd.Flags().StringVar(&quantity, "quantity", "", "Quantity")
    cmd.MarkFlagRequired("quantity")

    return cmd
}

// cmd/exchange-cli/commands/view_orderbook.go
package commands

import (
    "context"
    "fmt"
    "os"
    "text/tabwriter"

    "github.com/spf13/cobra"
    "go.uber.org/zap"

    "github.com/finaegis/finaegis-go/internal/application/query/exchange"
)

func NewViewOrderBookCmd(logger *zap.Logger) *cobra.Command {
    var (
        tradingPair string
        depth       int
    )

    cmd := &cobra.Command{
        Use:   "orderbook",
        Short: "View order book",
        RunE: func(cmd *cobra.Command, args []string) error {
            queryBus := setupQueryBus(logger)

            q := query.GetOrderBookQuery{
                TradingPair: tradingPair,
                TenantID:    "tenant-test",
                Depth:       depth,
            }

            result, err := queryBus.Execute(context.Background(), q)
            if err != nil {
                return fmt.Errorf("failed to get order book: %w", err)
            }

            orderBook := result.(*query.OrderBookResult)

            // Display order book
            fmt.Printf("\n📊 Order Book: %s\n\n", orderBook.TradingPair)

            w := tabwriter.NewWriter(os.Stdout, 0, 0, 2, ' ', 0)

            // Asks (sell orders) - reverse order to show lowest ask first
            fmt.Fprintln(w, "ASKS (Sell Orders)")
            fmt.Fprintln(w, "Price\tQuantity\tOrders")
            fmt.Fprintln(w, "-----\t--------\t------")

            for i := len(orderBook.Asks) - 1; i >= 0; i-- {
                ask := orderBook.Asks[i]
                fmt.Fprintf(w, "$%s\t%s\t%d\n",
                    ask.Price.StringFixed(2),
                    ask.Quantity.StringFixed(8),
                    ask.OrderCount,
                )
            }

            fmt.Fprintln(w, "")
            fmt.Fprintln(w, "═════════════════════")
            fmt.Fprintln(w, "")

            // Bids (buy orders)
            fmt.Fprintln(w, "BIDS (Buy Orders)")
            fmt.Fprintln(w, "Price\tQuantity\tOrders")
            fmt.Fprintln(w, "-----\t--------\t------")

            for _, bid := range orderBook.Bids {
                fmt.Fprintf(w, "$%s\t%s\t%d\n",
                    bid.Price.StringFixed(2),
                    bid.Quantity.StringFixed(8),
                    bid.OrderCount,
                )
            }

            w.Flush()

            // Calculate spread
            if len(orderBook.Bids) > 0 && len(orderBook.Asks) > 0 {
                spread := orderBook.Asks[0].Price.Sub(orderBook.Bids[0].Price)
                spreadPercent := spread.Div(orderBook.Bids[0].Price).Mul(decimal.NewFromInt(100))

                fmt.Printf("\n📈 Spread: $%s (%.3f%%)\n",
                    spread.StringFixed(2),
                    spreadPercent.InexactFloat64(),
                )
            }

            return nil
        },
    }

    cmd.Flags().StringVar(&tradingPair, "pair", "BTC/USD", "Trading pair")
    cmd.Flags().IntVar(&depth, "depth", 10, "Order book depth")

    return cmd
}

// cmd/exchange-cli/commands/market_maker.go
package commands

import (
    "context"
    "fmt"
    "time"

    "github.com/shopspring/decimal"
    "github.com/spf13/cobra"
    "go.uber.org/zap"

    "github.com/finaegis/finaegis-go/internal/application/command/exchange"
    "github.com/finaegis/finaegis-go/internal/domain/exchange/valueobject"
)

func NewMarketMakerCmd(logger *zap.Logger) *cobra.Command {
    var (
        tradingPair  string
        centerPrice  string
        spreadPercent float64
        orderCount   int
        orderSize    string
    )

    cmd := &cobra.Command{
        Use:   "market-maker",
        Short: "Run market making bot",
        Long:  "Continuously places buy and sell orders around a center price",
        RunE: func(cmd *cobra.Command, args []string) error {
            commandBus := setupCommandBus(logger)

            center, err := decimal.NewFromString(centerPrice)
            if err != nil {
                return fmt.Errorf("invalid center price: %w", err)
            }

            size, err := decimal.NewFromString(orderSize)
            if err != nil {
                return fmt.Errorf("invalid order size: %w", err)
            }

            spread := decimal.NewFromFloat(spreadPercent / 100)

            fmt.Printf("🤖 Starting market maker...\n")
            fmt.Printf("   Trading Pair: %s\n", tradingPair)
            fmt.Printf("   Center Price: $%s\n", center.String())
            fmt.Printf("   Spread: %.2f%%\n", spreadPercent)
            fmt.Printf("   Order Count: %d per side\n", orderCount)
            fmt.Printf("   Order Size: %s\n\n", size.String())

            ticker := time.NewTicker(5 * time.Second)
            defer ticker.Stop()

            for {
                select {
                case <-ticker.C:
                    // Place buy orders
                    for i := 1; i <= orderCount; i++ {
                        priceOffset := spread.Mul(decimal.NewFromInt(int64(i)))
                        buyPrice := center.Mul(decimal.NewFromInt(1).Sub(priceOffset))

                        buyCmd := command.PlaceOrderCommand{
                            OrderID:     uuid.New().String(),
                            AccountID:   "acc-market-maker",
                            TenantID:    "tenant-test",
                            TradingPair: parseTradingPair(tradingPair),
                            OrderType:   valueobject.OrderTypeLimit,
                            OrderSide:   valueobject.OrderSideBuy,
                            Price:       &buyPrice,
                            Quantity:    size,
                        }

                        if err := commandBus.Dispatch(context.Background(), buyCmd); err != nil {
                            logger.Error("Failed to place buy order", zap.Error(err))
                        } else {
                            fmt.Printf("📈 BUY  $%s x %s\n",
                                buyPrice.StringFixed(2), size.String())
                        }
                    }

                    // Place sell orders
                    for i := 1; i <= orderCount; i++ {
                        priceOffset := spread.Mul(decimal.NewFromInt(int64(i)))
                        sellPrice := center.Mul(decimal.NewFromInt(1).Add(priceOffset))

                        sellCmd := command.PlaceOrderCommand{
                            OrderID:     uuid.New().String(),
                            AccountID:   "acc-market-maker",
                            TenantID:    "tenant-test",
                            TradingPair: parseTradingPair(tradingPair),
                            OrderType:   valueobject.OrderTypeLimit,
                            OrderSide:   valueobject.OrderSideSell,
                            Price:       &sellPrice,
                            Quantity:    size,
                        }

                        if err := commandBus.Dispatch(context.Background(), sellCmd); err != nil {
                            logger.Error("Failed to place sell order", zap.Error(err))
                        } else {
                            fmt.Printf("📉 SELL $%s x %s\n",
                                sellPrice.StringFixed(2), size.String())
                        }
                    }

                    fmt.Println()
                }
            }
        },
    }

    cmd.Flags().StringVar(&tradingPair, "pair", "BTC/USD", "Trading pair")
    cmd.Flags().StringVar(&centerPrice, "center", "50000", "Center price")
    cmd.Flags().Float64Var(&spreadPercent, "spread", 0.1, "Spread percentage")
    cmd.Flags().IntVar(&orderCount, "count", 5, "Number of orders per side")
    cmd.Flags().StringVar(&orderSize, "size", "0.1", "Order size")

    return cmd
}
```

**Usage Examples:**
```bash
# Place a buy order
./exchange-cli place-order --pair BTC/USD --side buy --type limit --price 50000 --quantity 0.5

# View order book
./exchange-cli orderbook --pair BTC/USD --depth 20

# Run market maker
./exchange-cli market-maker --pair BTC/USD --center 50000 --spread 0.2 --count 10

# Simulate trading activity
./exchange-cli simulate --pair BTC/USD --traders 50 --duration 5m
```

**Verification Command:**
```bash
go build -o exchange-cli ./cmd/exchange-cli/
./exchange-cli --help
```

---

## Exchange Domain Summary

**Total Tasks Completed:** 14
**Estimated Total Hours:** 146 hours
**Recommended Timeline:** 3-4 weeks with 2-3 developers

### Task Breakdown by Category:

**Core Domain (Tasks 5.1-5.5):** 46 hours
- Value Objects & Aggregates
- Order matching engine
- AMM liquidity pools
- Commands & Handlers

**Read Models (Tasks 5.6-5.9):** 36 hours
- Projections & Database schema
- Projectors (event handlers)
- Queries & Query handlers

**API & Integration (Tasks 5.10-5.12):** 36 hours
- REST API endpoints
- External exchange integration (Binance)
- Fee tier management

**Testing & Tools (Tasks 5.13-5.14):** 28 hours
- Performance benchmarks
- Load testing
- CLI testing tool

### Key Accomplishments:

✅ **High-Performance Order Matching**
- FIFO algorithm with price-time priority
- Concurrent matching support
- Target: >10,000 matches/second

✅ **AMM Liquidity Pools**
- Constant product formula (x * y = k)
- Slippage protection
- Impermanent loss tracking
- LP token share calculations

✅ **Complete CQRS Implementation**
- Event-sourced aggregates
- Projections for read models
- Separate command and query paths
- Real-time order book updates

✅ **External Integration**
- Binance API client
- WebSocket price feeds
- Rate limiting compliance
- Circuit breaker pattern

✅ **Production-Ready Features**
- Volume-based fee tiers
- Multi-tenancy support
- Comprehensive error handling
- Performance benchmarks

### PHP Coverage:

All major PHP Exchange components migrated:
- ✅ `app/Domain/Exchange/Aggregates/`
- ✅ `app/Domain/Exchange/Services/`
- ✅ `app/Domain/Exchange/Models/`
- ✅ `app/Domain/Exchange/Projectors/`
- ✅ `app/Http/Controllers/Api/Exchange/`

---

**Next Phase:** Continue with remaining domains (Stablecoin, Treasury, Lending, Wallet, etc.)

