// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
// import { ERC20Mock } from "@openzeppelin/contracts/mocks/ERC20Mock.sol"; Updated mock location
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";
// import { MockMoreDebtDSC } from "../mocks/MockMoreDebtDSC.sol";
// import { MockFailedMintDSC } from "../mocks/MockFailedMintDSC.sol";
// import { MockFailedTransferFrom } from "../mocks/MockFailedTransferFrom.sol";
// import { MockFailedTransfer } from "../mocks/MockFailedTransfer.sol";
import {Test, console} from "forge-std/Test.sol";
// import { StdCheats } from "forge-std/StdCheats.sol";

contract DSCEngineTest is Test {
    event CollateralRedeemed(address indexed redeemFrom, address indexed redeemTo, address token, uint256 amount); // if
    // redeemFrom != redeemedTo, then it was liquidated

    DSCEngine public dsce;
    DecentralizedStableCoin public dsc;
    HelperConfig public helperConfig;

    address public ethUsdPriceFeed;
    address public btcUsdPriceFeed;
    address public weth;
    address public wbtc;
    uint256 public deployerKey;

    uint256 amountCollateral = 10 ether;
    uint256 amountToMint = 100 ether;
    address public user = address(1);

    uint256 public constant STARTING_USER_BALANCE = 10 ether;
    uint256 public constant MIN_HEALTH_FACTOR = 1e18;
    uint256 public constant LIQUIDATION_THRESHOLD = 50;

    // Liquidation
    address public liquidator = makeAddr("liquidator");
    uint256 public collateralToCover = 20 ether;

    function setUp() external {
        DeployDSC deployer = new DeployDSC();
        (dsc, dsce, helperConfig) = deployer.run();
        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getActiveNetworkConfig();
        ethUsdPriceFeed = networkConfig.wethUsdPriceFeed;
        btcUsdPriceFeed = networkConfig.wbtcUsdPriceFeed;
        weth = networkConfig.weth;
        wbtc = networkConfig.wbtc;
        deployerKey = networkConfig.deployerKey;

        ERC20Mock(weth).mint(user, STARTING_USER_BALANCE);
    }

    //////////////////
    // Price Tests //
    //////////////////
    function testGetUsdValue() public {
        uint256 ethAmount = 15e18;
        // 15e18 ETH * $2000/ETH = $30,000e18
        uint256 expectedUsd = 30_000e18;
        uint256 usdValue = dsce._getUsdValue(weth, ethAmount);
        assertEq(usdValue, expectedUsd);
    }

    /////////////////////////////
    // depositCollateral Tests //
    /////////////////////////////
    function testRevertIfDepositZero() public {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dsce), amountCollateral);

        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dsce.depositCollateral(weth, 0);
        vm.stopPrank();
    }
}
