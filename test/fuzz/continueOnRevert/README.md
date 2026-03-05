# Fuzz 与 Invariant 测试指南

## 什么是 Fuzz Testing（模糊测试）？

**Fuzz Testing** 是一种自动化测试方法，测试框架会自动生成大量随机输入来测试你的合约，试图找到你意想不到的边界情况。

### 普通单元测试 vs Fuzz 测试

```solidity
// ❌ 普通单元测试：只测试你想到的情况
function testDepositCollateral() public {
    vm.prank(user);
    dsce.depositCollateral(weth, 10 ether);  // 只测试 10 ether
    assertEq(dsce.getCollateralBalanceOfUser(user, weth), 10 ether);
}

// ✅ Fuzz 测试：测试所有可能的情况
function testDepositCollateral(uint256 amount) public {
    // amount 会自动被赋予各种随机值
    amount = bound(amount, 1, MAX_DEPOSIT_SIZE);  // 限制范围
    vm.prank(user);
    dsce.depositCollateral(weth, amount);
    assertEq(dsce.getCollateralBalanceOfUser(user, weth), amount);
}
// Foundry 会运行这个测试几百次，每次用不同的随机 amount
```

### Fuzz 测试的威力

```
┌─────────────────────────────────────────────────────────────────┐
│                    普通 Unit Test                                │
├─────────────────────────────────────────────────────────────────┤
│  输入: 10 ether                                                  │
│  输入: 100 ether                                                 │
│  输入: 0.1 ether                                                 │
│  你只测试了 3 种情况，可能漏掉很多 bug                              │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                    Fuzz Test                                     │
├─────────────────────────────────────────────────────────────────┤
│  输入: 0x0000...0001                                             │
│  输入: 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF │
│  输入: 0x80000000000000000000000000000000...                     │
│  输入: 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF│
│  ... 运行 256 次或更多 ...                                        │
│  自动发现溢出、边界条件等隐藏 bug                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 什么是 Invariant Testing（不变量测试）？

**Invariant Testing** 是更高级的测试方法。它的核心思想是：

> **无论系统经历什么操作，某些"不变量"（Invariants）必须永远成立。**

### 本项目的不变量

根据代码注释：

```solidity
// Invariants:
// 1. protocol must never be insolvent / undercollateralized
//    协议永远不能资不抵债（抵押品价值 >= DSC 总供应量）

// 2. users cant create stablecoins with a bad health factor
//    用户不能创建健康因子不良的稳定币

// 3. a user should only be able to be liquidated if they have a bad health factor
//    只有健康因子不良的用户才能被清算
```

### 不变量测试的工作原理

```
┌──────────────────────────────────────────────────────────────────────────┐
│                          Invariant Test 流程                              │
├──────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  1. 部署合约                                                              │
│     ↓                                                                    │
│  2. 创建 Handler（定义可以调用的函数）                                      │
│     ↓                                                                    │
│  3. Fuzz 测试开始：                                                       │
│     ┌──────────────────────────────────────────────┐                     │
│     │  随机调用 Handler 中的任意函数                  │                     │
│     │  depositCollateral() → mintDsc() → ...        │                     │
│     │  执行 N 次（如 256 次）随机操作                 │                     │
│     └──────────────────────────────────────────────┘                     │
│     ↓                                                                    │
│  4. 每次操作后，检查 Invariant 是否成立                                     │
│     ↓                                                                    │
│  5. 如果 Invariant 被破坏 → 测试失败，报告调用序列                          │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
```

---

## Handler 合约是什么？

Handler 是一个"代理人"合约，定义了 Fuzz 测试可以调用的所有函数。

```
┌─────────────────────────────────────────────────────────────────┐
│                    ContinueOnRevertHandler                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  为什么需要 Handler？                                              │
│                                                                  │
│  1. 限制随机调用的范围（不测试无关函数）                             │
│  2. 处理参数绑定（bound 函数限制输入范围）                          │
│  3. 跟踪状态（Ghost Variables）                                   │
│  4. 统计调用次数                                                  │
│                                                                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  函数列表：                                                       │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │ mintAndDepositCollateral()                                  │ │
│  │ redeemCollateral()                                          │ │
│  │ burnDsc()                                                   │ │
│  │ mintDsc()                                                   │ │
│  │ liquidate()                                                 │ │
│  │ transferDsc()                                               │ │
│  │ updateCollateralPrice()                                     │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Handler 函数详解

```solidity
// 示例 1：存款和铸造抵押品
function mintAndDepositCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
    // bound: 限制随机数范围，防止溢出等问题
    amountCollateral = bound(amountCollateral, 0, MAX_DEPOSIT_SIZE);
    
    // 用 seed 决定用哪个代币（WETH 或 WBTC）
    ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
    
    // 先给调用者铸造代币
    collateral.mint(msg.sender, amountCollateral);
    
    // 然后存入 DSCEngine
    dscEngine.depositCollateral(address(collateral), amountCollateral);
}

// 示例 2：选择抵押品
function _getCollateralFromSeed(uint256 collateralSeed) private view returns (ERC20Mock) {
    if (collateralSeed % 2 == 0) {
        return weth;  // 偶数 seed → WETH
    } else {
        return wbtc;  // 奇数 seed → WBTC
    }
}
```

---

## ContinueOnRevert vs FailOnRevert

这是 Foundry 提供的两种 Invariant 测试模式：

### FailOnRevert（默认模式）

```
┌─────────────────────────────────────────────────────────────────┐
│                         FailOnRevert                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  当任何调用 revert 时，整个测试立即失败                             │
│                                                                  │
│  调用序列：                                                       │
│  1. depositCollateral(100) ✓                                     │
│  2. mintDsc(1000) ✓                                              │
│  3. redeemCollateral(50) → REVERT! ❌                            │
│     ↓                                                            │
│  测试失败 ❌                                                      │
│                                                                  │
│  优点：更容易发现问题，调用序列简单                                  │
│  缺点：无法测试某些"预期中的 revert"                                │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### ContinueOnRevert（继续模式）

```
┌─────────────────────────────────────────────────────────────────┐
│                       ContinueOnRevert                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  当调用 revert 时，跳过这个调用，继续执行下一个                      │
│                                                                  │
│  调用序列：                                                       │
│  1. depositCollateral(100) ✓                                     │
│  2. mintDsc(1000) ✓                                              │
│  3. redeemCollateral(50) → REVERT ⚠️ 跳过，继续                   │
│  4. depositCollateral(200) ✓                                     │
│  5. mintDsc(500) ✓                                               │
│     ↓                                                            │
│  检查 Invariant ✓                                                │
│                                                                  │
│  优点：可以测试更多场景，更贴近真实世界                              │
│  缺点：可能掩盖某些 bug                                           │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 如何配置

```solidity
// 在测试函数上方添加注释：
/// forge-config: default.invariant.fail-on-revert = false
function invariant_protocolMustHaveMoreValueThanTotalSupplyDollars() public view {
    // 这个 invariant 测试会在 continue-on-revert 模式下运行
    assert(wethValue + wbtcValue >= totalSupply);
}
```

或在 `foundry.toml` 中配置：

```toml
[invariant]
fail-on-revert = false
runs = 256          # 每次测试运行多少个随机调用序列
depth = 15          # 每个序列有多少次调用
```

---

## 本测试的核心不变量

```solidity
/// forge-config: default.invariant.fail-on-revert = false
function invariant_protocolMustHaveMoreValueThanTotalSupplyDollars() public view {
    // 获取 DSC 总供应量
    uint256 totalSupply = dsc.totalSupply();
    
    // 获取 WETH 和 WBTC 存入数量
    uint256 wethDeposited = ERC20Mock(weth).balanceOf(address(dsce));
    uint256 wbtcDeposited = ERC20Mock(wbtc).balanceOf(address(dsce));
    
    // 计算美元价值
    uint256 wethValue = dsce.getUsdValue(weth, wethDeposited);
    uint256 wbtcValue = dsce.getUsdValue(wbtc, wbtcDeposited);
    
    // 不变量：抵押品总价值必须 >= DSC 总供应量
    // 这是一个稳定币系统的核心安全保证！
    assert(wethValue + wbtcValue >= totalSupply);
}
```

### 为什么这个不变量至关重要？

```
┌─────────────────────────────────────────────────────────────────┐
│                    稳定币系统的核心保证                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  如果 totalSupply > 抵押品价值：                                  │
│                                                                  │
│  用户持有: 1000 DSC  (声称值 $1000)                               │
│  抵押品:   $500 价值的 ETH                                        │
│                                                                  │
│  结果：                                                          │
│  - 用户无法用 $1000 兑换到 $1000 的 ETH                           │
│  - 系统资不抵债                                                   │
│  - 稳定币脱锚（DSC 不再值 $1）                                     │
│  - 挤兑风险                                                       │
│  - 系统崩溃！ 💥                                                  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 运行 Fuzz/Invariant 测试

```bash
# 运行所有 invariant 测试
forge test --match-contract ContinueOnRevertInvariants -vvvvv

# 增加 fuzz 次数（在 foundry.toml 或命令行）
forge test --fuzz-runs 1000

# 只运行特定的 invariant
forge test --match-test invariant_protocolMustHaveMoreValueThanTotalSupplyDollars -vvv
```

---

## 总结

| 概念 | 说明 |
|------|------|
| **Fuzz Testing** | 自动生成随机输入测试合约 |
| **Invariant Testing** | 随机调用后检查系统不变量是否成立 |
| **Handler** | 定义可被随机调用的函数 |
| **FailOnRevert** | 遇到 revert 就失败 |
| **ContinueOnRevert** | 遇到 revert 继续，适合测试不变量 |
| **Ghost Variables** | 测试中跟踪的额外状态变量 |
| **bound()** | 限制随机数范围，防止无意义的溢出测试 |