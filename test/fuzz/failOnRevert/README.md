# FailOnRevert (StopOnRevert) 模式详解

## 概述

本目录使用 **FailOnRevert** 模式进行 Invariant 测试。与 `continueOnRevert` 目录的区别：

| 模式 | 遇到 revert 时 | 适用场景 |
|------|---------------|---------|
| **FailOnRevert** (默认) | 立即停止测试，报告失败 | 测试 Handler 逻辑是否正确 |
| **ContinueOnRevert** | 跳过继续，继续执行后续调用 | 测试全局不变量是否成立 |

---

## 为什么需要两种模式？

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         两种模式的根本区别                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ContinueOnRevert 模式的问题：                                                │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │  调用: handler.mintDsc(超大金额)                                     │    │
│  │        → DSCEngine 内部 revert（健康因子不足）                        │    │
│  │        → ContinueOnRevert: 跳过，继续测试                             │    │
│  │        → 你不知道这个 revert 是否是预期的                             │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                             │
│  FailOnRevert 模式的价值：                                                   │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │  目标: Handler 必须"预测"哪些操作会 revert，提前避免                   │    │
│  │                                                                     │    │
│  │  如果 Handler 编写正确 → 永远不会 revert                             │    │
│  │  如果 Handler 编写错误 → 立即发现 bug                                │    │
│  │                                                                     │    │
│  │  这是在测试 Handler 的正确性，而不是测试 DSCEngine                    │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## StopOnRevertHandler 关键设计

### 1. 防止 revert 的策略

```solidity
// ❌ 错误写法：可能 revert
function redeemCollateral(uint256 amount) public {
    dscEngine.redeemCollateral(weth, amount);  // 如果 amount > 余额，会 revert
}

// ✅ 正确写法：先检查，避免 revert
function redeemCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
    ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
    
    // 1. 获取用户实际拥有的抵押品数量
    uint256 maxCollateral = dscEngine.getCollateralBalanceOfUser(msg.sender, address(collateral));
    
    // 2. 限制 amount 不超过最大值
    amountCollateral = bound(amountCollateral, 0, maxCollateral);
    
    // 3. 如果是 0，直接返回（因为 redeemCollateral 要求 amount > 0）
    if (amountCollateral == 0) {
        return;  // 安全退出，不会 revert
    }
    
    // 4. 现在可以安全调用
    vm.prank(msg.sender);
    dscEngine.redeemCollateral(address(collateral), amountCollateral);
}
```

### 2. 各函数的防 revert 设计

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    StopOnRevertHandler 防护策略                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  mintAndDepositCollateral()                                                 │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │  bound(amount, 1, MAX)        // 金额必须 >= 1                       │    │
│  │  先 mint 代币给用户             // 确保有足够余额                      │    │
│  │  先 approve                    // 确保有授权                          │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                             │
│  redeemCollateral()                                                         │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │  查询用户余额                   // 知道最多能取多少                    │    │
│  │  bound(amount, 0, max)         // 限制在余额范围内                    │    │
│  │  if (amount == 0) return       // 跳过无效操作                        │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                             │
│  burnDsc()                                                                  │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │  bound(amount, 0, balance)     // 不能 burn 超过持有量                │    │
│  │  if (amount == 0) return       // 跳过无效操作                        │    │
│  │  先 approve                    // 确保有授权                          │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                             │
│  liquidate()                                                                │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │  检查健康因子                   // 只有不健康才能清算                  │    │
│  │  if (健康) return              // 跳过无效清算                        │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                             │
│  transferDsc()                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │  if (to == address(0)) to = address(1)  // 防止零地址转账             │    │
│  │  bound(amount, 0, balance)    // 不能转超过持有量                     │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 3. 为什么注释掉 mintDsc？

```solidity
// Only the DSCEngine can mint DSC!
// function mintDsc(uint256 amountDsc) public {
//     amountDsc = bound(amountDsc, 0, MAX_DEPOSIT_SIZE);
//     vm.prank(dsc.owner());
//     dsc.mint(msg.sender, amountDsc);
// }

/*
   为什么注释掉？

   DSC 的 mint 函数只能被 DSCEngine 调用（DSC 合约的 owner 是 DSCEngine）
   
   在 DSCEngine.mintDsc() 中：
   1. 先增加 s_DSCMinted[msg.sender]
   2. 检查健康因子
   3. 如果健康因子不足，整个交易 revert

   如果 Handler 直接调用 dsc.mint()：
   - 绕过了健康因子检查
   - 会破坏不变量！
   
   所以正确的做法是通过 DSCEngine.mintDsc() 来铸造 DSC，
   而 DSCEngine 会自动验证健康因子。
   
   但这会导致 Handler 可能因为健康因子不足而 revert，
   所以需要更复杂的逻辑来处理。
   
   这里选择注释掉，让测试集中在其他操作上。
*/
```

---

## Invariant 函数详解

### invariant_protocolMustHaveMoreValueThatTotalSupplyDollars

```solidity
function invariant_protocolMustHaveMoreValueThatTotalSupplyDollars() public view {
    uint256 totalSupply = dsc.totalSupply();
    uint256 wethDeposited = ERC20Mock(weth).balanceOf(address(dsce));
    uint256 wbtcDeposited = ERC20Mock(wbtc).balanceOf(address(dsce));

    uint256 wethValue = dsce.getUsdValue(weth, wethDeposited);
    uint256 wbtcValue = dsce.getUsdValue(wbtc, wbtcDeposited);

    assert(wethValue + wbtcValue >= totalSupply);
}
```

这是稳定币系统的核心安全保证：

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         核心不变量：超额抵押                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  抵押品价值 (WETH + WBTC)  >=  DSC 总供应量                                   │
│                                                                             │
│  示例：                                                                      │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │  WETH 存入: 100 ETH × $2000 = $200,000                               │    │
│  │  WBTC 存入: 10 BTC × $30000 = $300,000                               │    │
│  │  抵押品总价值: $500,000                                              │    │
│  │                                                                     │    │
│  │  DSC 总供应量: $250,000                                              │    │
│  │                                                                     │    │
│  │  $500,000 >= $250,000 ✓                                             │    │
│  │  系统安全！每个 DSC 都有 $2 的抵押品支撑                               │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                             │
│  如果这个不变量被破坏：                                                       │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │  抵押品价值: $100,000                                                │    │
│  │  DSC 总供应量: $150,000                                              │    │
│  │                                                                     │    │
│  │  资不抵债！用户想兑换 DSC 时，没有足够的抵押品                         │    │
│  │  稳定币脱锚，系统崩溃                                                 │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### invariant_gettersCantRevert

```solidity
function invariant_gettersCantRevert() public view {
    dsce.getAdditionalFeedPrecision();
    dsce.getCollateralTokens();
    dsce.getLiquidationBonus();
    dsce.getLiquidationThreshold();
    dsce.getMinHealthFactor();
    dsce.getPrecision();
    dsce.getDsc();
}
```

这个测试确保所有 view/pure getter 函数正常工作：

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      Getter 函数应该永不 revert                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  getter 函数特点：                                                           │
│  - 不修改状态                                                                │
│  - 不需要前置条件                                                            │
│  - 应该总是能返回值                                                          │
│                                                                             │
│  如果 getter revert 了，说明：                                               │
│  - 可能有数组越界                                                            │
│  - 可能有未初始化的变量                                                       │
│  - 可能有逻辑错误                                                            │
│                                                                             │
│  这些都是严重的 bug！                                                        │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## ContinueOnRevert vs FailOnRevert 对比

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    ContinueOnRevert                                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Handler 设计：简单，允许某些操作失败                                         │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │  function mintDsc(uint256 amount) {                                  │    │
│  │      // 不检查健康因子，让 DSCEngine 自己 revert                      │    │
│  │      dscEngine.mintDsc(amount);  // 可能失败，但没关系               │    │
│  │  }                                                                   │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                             │
│  测试重点：全局不变量是否在任何情况下都成立                                    │
│  - 即使某些操作失败了，系统整体是否仍然安全                                    │
│  - 适合测试"系统崩溃场景"                                                    │
│                                                                             │
│  配置：/// forge-config: default.invariant.fail-on-revert = false           │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                    FailOnRevert (本目录)                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Handler 设计：复杂，必须预测并避免所有 revert                                 │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │  function mintDsc(uint256 amount) {                                  │    │
│  │      // 先检查健康因子，确保不会 revert                                │    │
│  │      // 如果会 revert，就不调用                                       │    │
│  │      if (!canMintSafely(amount)) return;                             │    │
│  │      dscEngine.mintDsc(amount);  // 确保成功                         │    │
│  │  }                                                                   │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                             │
│  测试重点：Handler 是否能生成有效的调用序列                                    │
│  - 验证所有操作都能成功执行                                                   │
│  - 不变量检查更严格                                                          │
│                                                                             │
│  配置：默认 fail-on-revert = true（无需配置）                                 │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 运行测试

```bash
# 运行 FailOnRevert 测试
forge test --match-contract StopOnRevertInvariants -vvv

# 增加测试轮数（更彻底的测试）
forge test --match-contract StopOnRevertInvariants --fuzz-runs 1000 -vvv

# 如果测试失败，查看完整调用序列
forge test --match-contract StopOnRevertInvariants -vvvvv
```

---

## 总结

| 特点 | FailOnRevert | ContinueOnRevert |
|------|--------------|------------------|
| Handler 复杂度 | 高（需避免所有 revert） | 低（允许失败） |
| 测试严格程度 | 高（所有操作必须成功） | 中（关注不变量） |
| 适用场景 | 验证 Handler 正确性 | 验证系统健壮性 |
| 发现 bug 类型 | 逻辑错误、边界条件 | 系统性安全漏洞 |
| revert 处理 | 立即失败 | 跳过继续 |

**最佳实践：两种模式都应该使用**

- FailOnRevert：确保 Handler 逻辑正确
- ContinueOnRevert：测试极端情况下的系统安全性