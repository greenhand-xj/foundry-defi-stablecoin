# AGENTS.md - Foundry DeFi Stablecoin Project

## Overview

This is a Foundry-based Solidity project implementing a Decentralized Stable Coin (DSC) system. The system maintains a 1 token = $1 peg using overcollateralization with WETH and WBTC as collateral. The codebase follows specific layout and naming conventions documented within each contract.

## Build, Lint, and Test Commands

### Core Commands

```bash
# Build the project
forge build

# Build with contract size information
forge build --sizes

# Run all tests with verbose output
forge test -vvv

# Run a single test function
forge test --match-test testFunctionName -vvv

# Run tests matching a contract name
forge test --match-contract DSCEngineTest -vvv

# Run tests in a specific file
forge test --match-path test/DSCEngine.t.sol -vvv

# Format all Solidity files
forge fmt

# Check formatting without applying changes
forge fmt --check

# Generate gas snapshots
forge snapshot

# Show help for forge commands
forge --help
```

### CI/CD Commands (from .github/workflows/test.yml)

```bash
# Format check (used in CI)
forge fmt --check

# Build with sizes (used in CI)
forge build --sizes

# Tests with verbose output (used in CI)
forge test -vvv
```

### Additional Utilities

```bash
# Start local Ethereum node
anvil

# Cast commands for interacting with contracts
cast <subcommand>

# Solidity REPL
chisel

# Deploy a contract
forge script script/Deploy.s.sol:DeployScript --rpc-url <RPC_URL> --private-key <PRIVATE_KEY>
```

## Code Style Guidelines

### Contract Layout (in this exact order)

1. Version pragma
2. Imports
3. Custom errors
4. Interfaces, libraries, contracts
5. Type declarations
6. State variables
7. Events
8. Modifiers
9. Functions

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

error CustomError__Reason();

contract Example {
    // Types
    struct Position { }

    // State variables
    uint256 private constant CONSTANT = 1e18;

    // Events
    event EventName(address indexed user);

    // Modifiers
    modifier onlyOwner() { }

    // Functions
    constructor() { }
    function externalFunction() external { }
    function internalFunction() internal { }
}
```

### Function Layout (in this exact order)

1. Constructor
2. Receive function (if exists)
3. Fallback function (if exists)
4. External functions
5. Public functions
6. Internal functions
7. Private functions
8. Internal & private view/pure functions
9. External & public view/pure functions

### Import Conventions

- Use OpenZeppelin imports via remapping: `@openzeppelin/contracts/...`
- Remapping is configured in foundry.toml: `@openzeppelin/contracts/=lib/openzeppelin-contracts/contracts/`
- Import with specific symbols when possible to reduce bytecode

```solidity
import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
```

### Naming Conventions

- **Contracts**: PascalCase (e.g., `DSCEngine`, `DecentralizedStableCoin`)
- **Interfaces**: Prefixed with `I` (e.g., `IERC20`)
- **Libraries**: PascalCase (e.g., `Math`)
- **Structs**: PascalCase (e.g., `UserPosition`)
- **Events**: PascalCase with noun-verb structure (e.g., `CollateralDeposited`)
- **Custom Errors**: `ContractName__ErrorReason` format
- **State Variables**: 
  - Private/immutable: `s_` or `i_` prefix (e.g., `s_collateralDeposited`, `i_dsc`)
  - Constants: `UPPER_CASE_WITH_UNDERSCORES`
  - Public: No prefix
- **Functions**: camelCase (e.g., `depositCollateral`, `getHealthFactor`)
- **Parameters**: camelCase (e.g., `tokenCollateralAddress`, `amountCollateral`)
- **Local Variables**: camelCase

### Custom Errors

Use custom errors instead of require statements for better gas efficiency and readability.

```solidity
error DSCEngine__NeedsMoreThanZero();
error DSCEngine__TransferFailed();
error DSCEngine__BreaksHealthFactor(uint256 healthFactorValue);
```

### Type Conventions

- Use `uint256` explicitly instead of `uint`
- Use `address` for addresses, `address payable` for addresses that need to receive ETH
- Use `int256` for signed integers
- Use `bytes32` for fixed-size bytes
- Constants should be `uint256 private constant`
- Precision constants typically use `1e18` base

### Visibility Order

Declare visibility in this order: `public` → `external` → `internal` → `private`

### State Variable Visibility

Order state variables by type and visibility:
1. Immutables (`i_` prefix)
2. Constants (`UPPER_CASE`)
3. Private (`s_` prefix)
4. Public
5. Internal

### Health Factor Validation

When modifying user positions, always validate health factor:

```solidity
if (_healthFactor < MIN_HEALTH_FACTOR) {
    revert DSCEngine__BreaksHealthFactor(_healthFactor);
}
```

### Reentrancy Protection

Use CEI pattern (Checks, Effects, Interactions) for all external calls:

```solidity
function withdrawCollateral(address token, uint256 amount) external moreThanZero(amount) {
    // Checks
    if (s_collateralDeposited[msg.sender][token] < amount) {
        revert NotEnoughCollateral();
    }

    // Effects
    s_collateralDeposited[msg.sender][token] -= amount;

    // Interactions
    bool success = IERC20(token).transfer(msg.sender, amount);
    if (!success) revert TransferFailed();
}
```

### Precision Handling

When working with prices or ratios:
- Use `uint256` with appropriate precision (typically `1e18` or `1e8`)
- Define precision constants at top of contract
- Be careful with multiplication/division order to avoid precision loss

```solidity
uint256 private constant PRECISION = 1e18;
uint256 private constant FEED_PRECISION = 1e8;
uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
```

### Liquidation Logic

- Liquidation threshold: typically 50 (200% overcollateralized)
- Liquidation bonus: typically 10 (10% discount for liquidators)
- Always validate health factor after position changes

### Testing Guidelines

- Use `vm.startPrank(address)` and `vm.stopPrank()` for testing different actors
- Use `deal(address, uint256)` to give test tokens
- Use `deployCode(string memory, bytes memory)` or script deployments
- Test both success and failure cases
- Use `vm.expectRevert()` for testing reverts

### Solidity Version

- Current pragma: `^0.8.19`
- Do not use versions below 0.8.19 (safety and convenience features)
