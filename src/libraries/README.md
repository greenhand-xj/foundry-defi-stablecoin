# Solidity Libraries 详解

## 什么是 Library（库）？

Library 是 Solidity 中一种特殊的合约类型，**它的代码会被嵌入到调用合约中**（类似于其他语言的"库"概念）。

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         Library vs Contract                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Contract (普通合约)              │  Library (库)                           │
│  ─────────────────────            │  ─────────────                          │
│  - 可以部署到区块链                │  - 不能独立部署                         │
│  - 可以有状态变量                  │  - 通常只有 pure/view 函数             │
│  - 可以继承                        │  - 不能被继承                           │
│  - 可以拥有 ETH                    │  - 不能拥有 ETH                        │
│  - 可以调用其他合约                │  - 通过 delegatecall 嵌入到合约中       │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 为什么使用 Library？

### 1. 代码复用（最重要的原因）

```solidity
// ❌ 没有 Library：重复代码
contract A {
    function calculate(uint256 a, uint256 b) public pure returns (uint256) {
        return a * b / 10;  // 同样的逻辑
    }
}

contract B {
    function calculate(uint256 a, uint256 b) public pure returns (uint256) {
        return a * b / 10;  // 同样的逻辑重复了！
    }
}

// ✅ 使用 Library：复用代码
library MathUtils {
    function calculate(uint256 a, uint256 b) public pure returns (uint256) {
        return a * b / 10;
    }
}

contract A {
    function test() public pure returns (uint256) {
        return MathUtils.calculate(10, 100);
    }
}

contract B {
    function test() public pure returns (uint256) {
        return MathUtils.calculate(20, 50);  // 复用同一份代码
    }
}
```

### 2. 减少部署成本

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         Gas 优化效果                                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  如果 10 个合约都使用了相同的 100 行逻辑：                                     │
│                                                                             │
│  ❌ 没有 Library：                                                          │
│     合约 A: 部署 100 行代码 × 10 = 1000 行部署                              │
│     合约 B:                                                                  │
│     合约 C:                                                                  │
│     ...                                                                     │
│                                                                             │
│  ✅ 使用 Library：                                                          │
│     Library: 部署 100 行代码 (1 次)                                         │
│     合约 A: 嵌入调用 (几乎 0 额外部署成本)                                    │
│     合约 B: 嵌入调用                                                         │
│     合约 C: 嵌入调用                                                         │
│     ...                                                                     │
│                                                                             │
│  节省约 90% 的部署 gas！                                                    │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 3. 代码组织与可维护性

```solidity
// 库将相关功能组织在一起
library AddressUtils {
    function isContract(address) internal pure returns (bool) { }
    function sendValue(address, uint256) internal pure { }
}

library StringUtils {
    function equals(string memory, string memory) internal pure returns (bool) { }
    function toString(uint256) internal pure returns (string memory) { }
}
```

---

## 本项目的 OracleLib 详解

### 作用：检查 Chainlink 价格数据是否过期

```solidity
library OracleLib {
    uint256 private constant TIMEOUT = 3 hours;  // 价格超过 3 小时算过期

    function staleCheckLatestRoundData(AggregatorV3Interface chainlinkFeed)
        public
        view
        returns (...)
    {
        // 1. 获取最新的价格数据
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            chainlinkFeed.latestRoundData();

        // 2. 检查数据是否存在
        if (updatedAt == 0 || answeredInRound < roundId) {
            revert OracleLib__StalePrice();  // 数据不存在
        }

        // 3. 检查是否过期
        uint256 secondsSince = block.timestamp - updatedAt;
        if (secondsSince > TIMEOUT) revert OracleLib__StalePrice();  // 价格太旧

        return (...);
    }
}
```

### 为什么需要这个库？

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         价格预言机的重要性                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  DSCEngine 依赖 Chainlink 价格来计算抵押品价值：                               │
│                                                                             │
│  用户存入 1 ETH → 抵押品价值 = ETH 价格 × 1                                  │
│                                                                             │
│  问题：如果 Chainlink 价格停止更新怎么办？                                     │
│                                                                             │
│  场景：                                                                     │
│  1. ETH 实际价格: $2000                                                     │
│  2. Chainlink 价格: $2000 (5 小时前更新的) ← 过期！                          │
│  3. 如果用过期价格计算，用户可能超额借款                                       │
│  4. 系统出现坏账！                                                          │
│                                                                             │
│  OracleLib 的作用：                                                          │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  在使用价格前，先检查价格是否过期                                       │   │
│  │  如果过期 → revert 整个交易                                            │   │
│  │  这样可以"冻结"系统，防止使用错误价格                                    │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  这是安全优先的设计：宁可暂停合约，也不让用户用错误价格借款                      │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### staleCheckLatestRoundData 检查逻辑

```solidity
(uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
    chainlinkFeed.latestRoundData();

if (updatedAt == 0 || answeredInRound < roundId) {
    revert OracleLib__StalePrice();  // 检查 1: round 数据不存在
}

uint256 secondsSince = block.timestamp - updatedAt;
if (secondsSince > TIMEOUT) revert OracleLib__StalePrice();  // 检查 2: 价格太旧
```

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Chainlink latestRoundData 返回值                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  roundId:        当前轮次 ID                                                 │
│  answer:         当前价格（如 2000_00000000 = $2000）                       │
│  startedAt:      这轮开始的时间戳                                             │
│  updatedAt:     价格最后更新的时间戳 ← 用来判断是否过期                       │
│  answeredInRound: 回答此轮的轮次 ID                                          │
│                                                                             │
│  过期判断：                                                                  │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │  updatedAt == 0                                                     │    │
│  │  → 还没有任何价格数据                                               │    │
│  │                                                                     │    │
│  │  answeredInRound < roundId                                          │    │
│  │  → 出现了新 round，旧数据被覆盖                                     │    │
│  │                                                                     │    │
│  │  block.timestamp - updatedAt > TIMEOUT (3 hours)                   │    │
│  │  → 价格超过 3 小时没更新                                            │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Library 的使用方式

### 方式 1：using for（推荐）

```solidity
library Math {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }
}

contract Example {
    using Math for uint256;  // 为 uint256 添加 Math 方法

    function test() public pure returns (uint256) {
        uint256 result = 5.add(10);  // 像调用方法一样
        return result;  // 15
    }
}
```

### 方式 2：直接调用

```solidity
library Math {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }
}

contract Example {
    function test() public pure returns (uint256) {
        return Math.add(5, 10);  // 直接调用
    }
}
```

---

## 本项目中 Library 的使用示例

```solidity
// DSCEngine.sol 中使用 OracleLib

import {OracleLib} from "./libraries/OracleLib.sol";

contract DSCEngine {
    // 使用 OracleLib 检查价格
    function _getUsdValue(address token, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        
        // 使用 library 的函数
        (, int256 answer,,,) = priceFeed.latestRoundData();
        // ↑ 也可以用 OracleLib.staleCheckLatestRoundData(priceFeed) 来检查
        
        return ((uint256(answer) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION;
    }
}
```

---

## 常见 Library 示例

### OpenZeppelin 提供的常用库

| 库 | 作用 |
|-----|------|
| `Address` | 地址操作（判断是否为合约、safe transfer） |
| `Strings` | 字符串操作 |
| `Math` | 数学运算（max、min） |
| `Counters` | 计数器（自动递增 ID） |
| `ECDSA` | 签名验证 |
| `EnumerableSet` | 可枚举集合 |
| `EnumerableMap` | 可枚举映射 |

---

## 总结

| 问题 | 答案 |
|------|------|
| 什么是 Library？ | 可复用的代码库，嵌入到调用合约中 |
| 为什么使用？ | 1. 代码复用 2. 节省 gas 3. 代码组织 |
| 本项目用在哪？ | OracleLib：检查 Chainlink 价格是否过期 |
| 过期了怎么办？ | revert 整个交易，冻结系统，防止使用错误价格 |
| 有哪些常用库？ | OpenZeppelin 的 Address、Strings、Math 等 |