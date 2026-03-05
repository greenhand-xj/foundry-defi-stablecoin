# Decentralized Stable Coin (DSC)

基于 Foundry 的去中心化稳定币系统，实现 1 DSC = $1 的锚定，通过超额抵押（WETH/WBTC）进行支撑。

## 什么是去中心化稳定币？

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         稳定币的核心问题                                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  目标：创造一种价值稳定在 $1 的加密货币                                        │
│                                                                             │
│  挑战：加密货币价格波动巨大，如何保持稳定？                                     │
│                                                                             │
│  解决方案：超额抵押 (Overcollateralization)                                  │
│                                                                             │
│  示例：                                                                     │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │  存入 $2000 的 ETH                                                   │    │
│  │  最多只能铸造 $1000 的 DSC                                           │    │
│  │                                                                     │    │
│  │  抵押率 = $2000 / $1000 = 200%                                      │    │
│  │                                                                     │    │
│  │  即使 ETH 下跌 50%，仍然有足够抵押品覆盖 DSC                           │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## 系统架构

### 核心合约

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              系统架构图                                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│                              ┌──────────────┐                               │
│                              │    用户       │                               │
│                              └──────┬───────┘                               │
│                                     │                                       │
│          ┌──────────────────────────┼──────────────────────────┐            │
│          │                          │                          │            │
│          ▼                          ▼                          ▼            │
│  ┌───────────────┐         ┌───────────────┐         ┌───────────────┐     │
│  │  存入抵押品    │         │   铸造 DSC    │         │   清算用户    │     │
│  │ depositColla- │         │   mintDsc     │         │  liquidate    │     │
│  │ teral        │         │               │         │               │     │
│  └───────┬───────┘         └───────┬───────┘         └───────┬───────┘     │
│          │                          │                          │            │
│          └──────────────────────────┼──────────────────────────┘            │
│                                     │                                       │
│                                     ▼                                       │
│                        ┌────────────────────────┐                          │
│                        │     DSCEngine          │                          │
│                        │  ┌──────────────────┐  │                          │
│                        │  │ 抵押品管理        │  │                          │
│                        │  │ 铸造/销毁逻辑      │  │                          │
│                        │  │ 健康因子检查       │  │                          │
│                        │  │ 清算逻辑          │  │                          │
│                        │  └──────────────────┘  │                          │
│                        └───────────┬────────────┘                          │
│                                    │                                       │
│                                    │ 拥有                                   │
│                                    ▼                                       │
│                        ┌────────────────────────┐                          │
│                        │ DecentralizedStableCoin│                          │
│                        │  (ERC20 代币)         │                          │
│                        └───────────┬────────────┘                          │
│                                    │                                       │
│          ┌─────────────────────────┼─────────────────────────┐             │
│          │                         │                         │             │
│          ▼                         ▼                         ▼             │
│  ┌───────────────┐         ┌───────────────┐         ┌───────────────┐   │
│  │ WETH/USD      │         │ WBTC/USD      │         │   用户钱包     │   │
│  │ 价格预言机     │         │ 价格预言机     │         │               │   │
│  │ (Chainlink)  │         │ (Chainlink)  │         │               │   │
│  └───────────────┘         └───────────────┘         └───────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 核心概念

| 概念 | 说明 |
|------|------|
| **抵押品 (Collateral)** | 用户存入的 ETH/WBTC，作为 DSC 的支撑资产 |
| **铸造 (Mint)** | 抵押 ETH 后，铸造对应价值的 DSC |
| **健康因子 (Health Factor)** | 抵押品价值 / DSC 债务，低于 1 时可被清算 |
| **清算 (Liquidation)** | 当健康因子 < 1 时，清算人可偿还债务并获得抵押品 |
| **预言机 (Oracle)** | Chainlink 提供 ETH/USD、WBTC/USD 价格 |

## 项目结构

```
foundry-defi-stablecoin/
├── src/
│   ├── DSCEngine.sol              # 核心逻辑合约
│   ├── DecentralizedStableCoin.sol # DSC 代币合约
│   └── libraries/
│       └── OracleLib.sol          # 预言机价格检查库
├── script/
│   ├── DeployDSC.s.sol            # 部署脚本
│   └── HelperConfig.s.sol         # 网络配置
├── test/
│   ├── unit/
│   │   └── DSCEngineTest.t.sol   # 单元测试
│   ├── mocks/
│   │   ├── ERC20Mock.sol         # 测试用 ERC20
│   │   └── MockV3Aggregator.sol  # 测试用价格预言机
│   └── fuzz/
│       ├── continueOnRevert/      # 模糊测试 (继续模式)
│       └── failOnRevert/          # 模糊测试 (停止模式)
├── foundry.toml                   # Foundry 配置
└── README.md                      # 项目文档
```

## 快速开始

### 安装依赖

```bash
forge install
```

### 构建

```bash
forge build
```

### 测试

```bash
# 运行所有测试
forge test -vvv

# 运行单个测试
forge test --match-test testFunctionName -vvv

# 运行单元测试
forge test --match-contract DSCEngineTest -vvv
```

### 格式化

```bash
forge fmt
```

### 启动本地节点

```bash
anvil
```

### 部署

```bash
forge script script/DeployDSC.s.sol:DeployDSC --rpc-url <RPC_URL> --private-key <PRIVATE_KEY>
```

## 核心功能详解

### 1. 存入抵押品

```solidity
function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral) external;
```

- 用户批准 ERC20 代币给 DSCEngine
- 调用 `depositCollateral` 存入抵押品
- 抵押品记录在 `s_collateralDeposited[user][token]`

### 2. 铸造 DSC

```solidity
function mintDsc(uint256 amountDscToMint) external;
```

- 基于存入的抵押品价值铸造 DSC
- **必须先存入抵押品才能铸造**
- 铸造后立即检查健康因子

### 3. 一键存款+铸造

```solidity
function depositCollateralAndMintDsc(
    address tokenCollateralAddress,
    uint256 amountCollateral,
    uint256 amountDscToMint
) external;
```

### 4. 赎回抵押品

```solidity
function redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral) external;
```

- 赎回前需确保健康因子仍 > 1

### 5. 清算

```solidity
function liquidate(
    address collateral,
    address user,
    uint256 debtToCover
) external;
```

- 清算条件：`用户健康因子 < 1`
- 清算人获得 10% 清算奖金
- 偿还部分/全部债务，获得对应抵押品

## 关键参数

| 参数 | 值 | 说明 |
|------|-----|------|
| 清算阈值 | 50 | 200% 超额抵押 |
| 清算奖金 | 10% | 清算人获得 10% 折扣 |
| 最小健康因子 | 1e18 | 即 1.0 |
| 价格超时 | 3 小时 | Chainlink 价格过期时间 |

## 安全机制

### 1. 超额抵押

```
抵押品价值 >= DSC 总供应量
```

### 2. 健康因子检查

```solidity
if (userHealthFactor < MIN_HEALTH_FACTOR) {
    revert DSCEngine__BreaksHealthFactor(userHealthFactor);
}
```

### 3. CEI 模式

Checks-Effects-Interactions 模式防止重入攻击

### 4. 预言机价格验证

OracleLib 检查 Chainlink 价格是否过期，过期则冻结系统

## 测试覆盖

- ✅ 单元测试：核心函数功能测试
- ✅ 模糊测试 (FailOnRevert)：Handler 逻辑正确性
- ✅ 模糊测试 (ContinueOnRevert)：极端情况下系统安全性
- ✅ 不变量测试：抵押品价值 >= DSC 供应量

## 技术栈

- **Solidity** ^0.8.19
- **Foundry** - 智能合约开发框架
- **OpenZeppelin** - 合约库
- **Chainlink** - 价格预言机

## 参考

本项目基于 [Cyfrin Foundry Solidty Course](https://github.com/Cyfrin/foundry-smart-contract-lottery) 实现。