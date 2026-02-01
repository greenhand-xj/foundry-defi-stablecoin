// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/*
 * @title DSCEngine
 * @author Eric
 *
 * The system is designed to be as minimal as possible, and have the tokens maintain a 1 token == $1 peg at all times.
 * This is a stablecoin with the properties:
 * - Exogenously Collateralized
 * - Dollar Pegged
 * - Algorithmically Stable
 *
 * It is similar to DAI if DAI had no governance, no fees, and was backed by only WETH and WBTC.
 *
 * Our DSC system should always be "overcollateralized". At no point, should the value of
 * all collateral < the $ backed value of all the DSC.
 *
 * @notice This contract is the core of the Decentralized Stablecoin system. It handles all the logic
 * for minting and redeeming DSC, as well as depositing and withdrawing collateral.
 * @notice This contract is based on the MakerDAO DSS system
 */
contract DecentralizedStableCoin is ERC20Burnable, Ownable {
    error DecentralizedStableCoin__AmountLessThanZero();
    error DecentralizedStableCoin__BurnAmountExceedsBalance(
        uint256 burnAmount,
        uint256 balance
    );
    error DecentralizedStableCoin__MintToZeroAddress();

    constructor()
        ERC20("Decentralized Stable Coin", "DSC")
        Ownable(msg.sender)
    {
        // _mint(msg.sender, 1000000 * 10 ** decimals());
    }

    function burn(uint256 amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);
        if (amount <= 0) {
            revert DecentralizedStableCoin__AmountLessThanZero();
        }
        if (amount > balance) {
            revert DecentralizedStableCoin__BurnAmountExceedsBalance(
                amount,
                balance
            );
        }
        super.burn(amount);
    }

    function mint(
        address to,
        uint256 amount
    ) external onlyOwner returns (bool) {
        if (to == address(0)) {
            revert DecentralizedStableCoin__MintToZeroAddress();
        }
        if (amount <= 0) {
            revert DecentralizedStableCoin__AmountLessThanZero();
        }
        _mint(to, amount);
        return true;
    }
}
