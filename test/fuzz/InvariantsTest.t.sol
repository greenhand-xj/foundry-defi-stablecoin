// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
// import {ERC20Mock} from "../../mocks/ERC20Mock.sol";

contract InvariantsTest is StdInvariant, Test {
    DSCEngine public dsce;
    DecentralizedStableCoin public dsc;
    HelperConfig public helperConfig;

    address public ethUsdPriceFeed;
    address public btcUsdPriceFeed;
    address public weth;
    address public wbtc;

    uint256 amountCollateral = 10 ether;
    uint256 amountToMint = 100 ether;

    uint256 public constant STARTING_USER_BALANCE = 10 ether;
    address public constant USER = address(1);
    uint256 public constant MIN_HEALTH_FACTOR = 1e18;
    uint256 public constant LIQUIDATION_THRESHOLD = 50;

    // Liquidation
    address public liquidator = makeAddr("liquidator");
    uint256 public collateralToCover = 20 ether;

    function setUp() external {
        DeployDSC deployer = new DeployDSC();
        (dsc, dsce, helperConfig) = deployer.run();
        HelperConfig.NetworkConfig memory config = helperConfig.getActiveNetworkConfig();
        ethUsdPriceFeed = config.wethUsdPriceFeed;
        btcUsdPriceFeed = config.wbtcUsdPriceFeed;
        weth = config.weth;
        wbtc = config.wbtc;
    }
}
