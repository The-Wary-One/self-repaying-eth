// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {AlchemicTokenV2} from "../lib/alchemix/src/AlchemicTokenV2.sol";
import {IAlchemistV2} from "../lib/alchemix/src/interfaces/IAlchemistV2.sol";

import {ICurveStableSwapNG} from "./interfaces/ICurveStableSwapNG.sol";
import {IWETH9} from "./interfaces/IWETH9.sol";

/// @title SelfRepayingETH
/// @author Wary
///
/// @notice An contract helper to borrow `alETH` from an Alchemix account, exchange it for ETH.
abstract contract SelfRepayingETH {
    /// @notice The Alchemix `alETH` alchemistV2 contract.
    IAlchemistV2 immutable alchemist;

    /// @notice The Alchemix `alETH` AlchemicTokenV2 contract.
    AlchemicTokenV2 immutable alETH;

    /// @notice The `alETH`-`WETH` Curve Pool contract.
    ICurveStableSwapNG immutable alETHPool;

    /// @notice The weth contract.
    IWETH9 immutable weth;

    /// @notice The `alETH`-`WETH` exchange slippage protection.
    uint256 constant SLIPPAGE_PROTECTION = 0.01 * 1e18; // 1%

    /// @notice Emitted when `sreth` borrows `alETHAmount` of `alETH` from `owner` for `ethAmount` of ETH.
    ///
    /// @param owner The address of the Alchemix account owner.
    /// @param alETHAmount The amount of `alETH` debt tokens that were minted in wei.
    /// @param ethAmount The amount of exchanged `ETH` received in wei.
    event Borrowed(address indexed owner, uint256 alETHAmount, uint256 ethAmount);

    /// @notice Initialize the contract.
    //
    /// @dev We annotate it payable to make it cheaper. Do not send ETH.
    constructor(IAlchemistV2 _alchemist, ICurveStableSwapNG _alETHPool, IWETH9 _weth) payable {
        alchemist = _alchemist;
        alETHPool = _alETHPool;
        weth = _weth;

        alETH = AlchemicTokenV2(alchemist.debtToken());
    }

    /// @notice Borrow self repaying `ethAmount` amount of `ETH` from the `alETH` account owned by `owner`.
    ///
    /// @notice Emits a {Borrow} event.
    ///
    /// @notice 📝 The `SelfRepayingETH` contract must have enough `AlchemistV2.mintAllowance()` to mint at least `ethAmount` and some slippage protection amount of `alETH`. The can be done via the `AlchemistV2.approveMint()` method.
    ///
    /// @dev 💀 A large `ethAmount` value exchange WILL be taken advantage off by MEV bots in a sandwich attack.
    ///
    /// @param owner The address of the Alchemix account owner to mint `alETH` from.
    /// @param ethAmount The amount of `ETH` to borrow in wei.
    function _borrowSelfRepayingETHFrom(address owner, uint256 ethAmount) internal {
        // Get the amount of `ETH` debt (i.e. alETH) to mint to get at least `ethAmount` amount of `WETH` from the Curve Pool.
        // ⚠️  Due to a Curve Pool limitation, we use `alETHPool.get_dx()` to get the `WETH` amount back in a transaction when ideally it should be called in a staticcall.
        // ⚠️  We do not check the `alETH`-`WETH` depeg.
        uint256 alETHToMint = _getAlETHToMint(ethAmount);

        // Mint `alETHToMint` amount of `alETH` (i.e. debt token) from `owner` to this contrat Alchemix account.
        alchemist.mintFrom(owner, alETHToMint, address(this));
        // Execute a Curve Pool exchange for `alETHToMint` amount of `alETH` tokens to at least `ethAmount` of `WETH`.
        // 📝 The Curve pool checks the `exchange output received >= ethAmount` invariant.
        // 📝 We use the `exchange_received` method which consume less gas.
        alETH.transfer(address(alETHPool), alETHToMint);
        uint256 wethReceived = alETHPool.exchange_received(
            0, // alETH
            1, // WETH
            alETHToMint,
            ethAmount
        );
        // Convert the `WETH` back to `ETH`.
        weth.withdraw(wethReceived);

        // Send the non needed `ETH` back to `owner`.
        // 📝 `wethReceived` > `ethAmount`.
        uint256 nonNeededEthAmount;
        unchecked {
            nonNeededEthAmount = wethReceived - ethAmount;
        }
        // ⚠️  This transfer can revert if `owner` is a contract without `receive()`, `fallback()` or if they revert. The caller must make sure it won't cause a DOS attack.
        payable(owner).transfer(nonNeededEthAmount);

        emit Borrowed(owner, alETHToMint, ethAmount);
    }

    /// @dev Get the current `alETH` amount to get `ethAmount` amount of `WETH` back in from a Curve Pool exchange.
    ///
    /// @param ethAmount The minimum `WETH` amount to get back from the Curve `alETH` exchange in wei.
    /// @return The `alETH` amount to swap to get `ethAmount` amount of `WETH` back from a Curve exchange.
    function _getAlETHToMint(uint256 ethAmount) internal view returns (uint256) {
        return alETHPool.get_dx(
            0, // alETH
            1, // WETH
            ethAmount * (1e18 + SLIPPAGE_PROTECTION) / 1e18
        );
    }

    /// @notice To receive `ETH` payments.
    /// @dev To receive `ETH` from weth.withdraw(). ⚠️  The contract can receive `ETH` from another Ethereum account.
    receive() external payable virtual;
}
