# AGENTS.md - Foundry DeFi Stablecoin Project

## Overview

Foundry-based Solidity project implementing a Decentralized Stable Coin (DSC) system with 1 token = $1 peg using overcollateralization (WETH/WBTC).

## Build, Lint, and Test Commands

```bash
forge build                    # Build the project
forge build --sizes            # Build with contract sizes
forge test -vvv                # Run all tests with verbose output
forge test --match-test testFunctionName -vvv    # Run single test function
forge test --match-contract DSCEngineTest -vvv   # Run tests by contract name
forge test --match-path test/unit/DSCEngineTest.t.sol -vvv  # Run tests in file
forge fmt                      # Format all Solidity files
forge fmt --check              # Check formatting without applying
forge snapshot                 # Generate gas snapshots
anvil                          # Start local Ethereum node
forge script script/DeployDSC.s.sol:DeployDSC --rpc-url <RPC_URL> --private-key <KEY>  # Deploy
```

## Code Style Guidelines

### Contract Layout (exact order)

1. Version pragma  2. Imports  3. Custom errors  4. Interfaces/libraries/contracts
5. Type declarations  6. State variables  7. Events  8. Modifiers  9. Functions

### Function Layout (exact order)

1. Constructor  2. Receive  3. Fallback  4. External  5. Public
6. Internal  7. Private  8. Internal/private view/pure  9. External/public view/pure

### Imports

```solidity
import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
```

Remappings configured in `foundry.toml`:
- `@openzeppelin/contracts/=lib/openzeppelin-contracts/contracts/`
- `@chainlink/contracts=lib/chainlink-brownie-contracts/contracts`

### Naming Conventions

| Element | Convention | Example |
|---------|------------|---------|
| Contracts | PascalCase | `DSCEngine`, `DecentralizedStableCoin` |
| Interfaces | `I` prefix | `IERC20` |
| Errors | `ContractName__ErrorReason` | `DSCEngine__NeedsMoreThanZero` |
| Events | PascalCase noun-verb | `CollateralDeposited` |
| Private/immutable vars | `s_`/`i_` prefix | `s_collateralDeposited`, `i_dsc` |
| Constants | UPPER_SNAKE_CASE | `MIN_HEALTH_FACTOR` |
| Functions | camelCase | `depositCollateral` |
| Parameters | camelCase | `tokenCollateralAddress` |

### Custom Errors (over require)

```solidity
error DSCEngine__NeedsMoreThanZero();
error DSCEngine__BreaksHealthFactor(uint256 healthFactorValue);
```

### Types

- Use `uint256` explicitly (never `uint`)
- Use `int256` for signed integers
- Precision constants: `uint256 private constant PRECISION = 1e18;`

### State Variable Order

1. Immutables (`i_` prefix)  2. Constants (`UPPER_CASE`)  3. Private (`s_` prefix)  4. Public  5. Internal

### Reentrancy Protection (CEI Pattern)

```solidity
function withdrawCollateral(address token, uint256 amount) external {
    // Checks
    if (s_collateralDeposited[msg.sender][token] < amount) revert NotEnoughCollateral();
    // Effects
    s_collateralDeposited[msg.sender][token] -= amount;
    // Interactions
    bool success = IERC20(token).transfer(msg.sender, amount);
    if (!success) revert TransferFailed();
}
```

### Health Factor Validation

Always validate health factor after modifying user positions:

```solidity
if (userHealthFactor < MIN_HEALTH_FACTOR) {
    revert DSCEngine__BreaksHealthFactor(userHealthFactor);
}
```

### Testing

```solidity
vm.startPrank(user);
vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
dsce.depositCollateral(weth, 0);
vm.stopPrank();
```

- Use `vm.startPrank(address)`/`vm.stopPrank()` for different actors
- Use `vm.expectRevert()` for testing reverts
- Test both success and failure cases

### Solidity Version

Current pragma: `^0.8.19` - do not use versions below 0.8.19
