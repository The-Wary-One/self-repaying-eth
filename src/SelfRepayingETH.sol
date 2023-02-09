// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {AlchemicTokenV2} from "../lib/alchemix/src/AlchemicTokenV2.sol";
import {IAlchemistV2} from "../lib/alchemix/src/interfaces/IAlchemistV2.sol";

import {ICurveCalc} from "./interfaces/ICurveCalc.sol";
import {ICurvePool} from "./interfaces/ICurvePool.sol";

/// @title SelfRepayingETH
/// @author Wary
///
/// @notice An contract helper to borrow alETH from an Alchemix account, exchange it for ETH.
abstract contract SelfRepayingETH {
    /// @notice The Alchemix alETH alchemistV2 contract.
    IAlchemistV2 public immutable alchemist;

    /// @notice The Alchemix alETH AlchemicTokenV2 contract.
    AlchemicTokenV2 public immutable alETH;

    /// @notice The CurveCalc contract.
    ICurveCalc public immutable curveCalc;

    /// @notice The alETH-ETH Curve Pool contract.
    ICurvePool public immutable alETHPool;

    /// @notice Emitted when `sreth` borrows `alETHAmount` of alETH from `owner` for `ethAmount` of ETH.
    ///
    /// @param owner The address of the Alchemix account owner.
    /// @param alETHAmount The amount of alETH debt tokens that were minted in wei.
    /// @param ethAmount The amount of exchanged ETH received in wei.
    event Borrow(address indexed owner, uint256 alETHAmount, uint256 ethAmount);

    /// @notice Initialize the contract.
    //
    /// @dev We annotate it payable to make it cheaper. Do not send ETH.
    constructor(IAlchemistV2 _alchemist, ICurvePool _alETHPool, ICurveCalc _curveCalc) payable {
        alchemist = _alchemist;
        alETHPool = _alETHPool;
        curveCalc = _curveCalc;

        alETH = AlchemicTokenV2(alchemist.debtToken());

        // Approve the `alETHPool` Curve Pool to transfer an (almost) unlimited amount of `alETH` tokens.
        alETH.approve(address(_alETHPool), type(uint256).max);
    }

    /// @notice Borrow some self repaying ETH `amount` from the `alETH` account owned by `owner`.
    ///
    /// @notice Emits a {Borrow} event.
    ///
    /// @notice **_NOTE:_** The `SelfRepayingETH` contract must have enough `AlchemistV2.mintAllowance()` to borrow `amount` ETH. The can be done via the `AlchemistV2.approveMint()` method.
    ///
    /// @dev **_NOTE:_** 💀 There is no protection against the alETH-ETH depeg.
    /// @dev **_NOTE:_** 💀 A large `amount` exchange will be taken advantage off by MEV bots in a sandwich attack.
    ///
    /// @param owner The address of the Alchemix account owner to mint alETH from.
    /// @param amount The amount of ETH to borrow in wei.
    function _borrowSelfRepayingETHFrom(address owner, uint256 amount) internal {
        // Get the EXACT amount of ETH debt (i.e. alETH) to mint from the Curve Pool by asking the CurveCalc contract.
        // ⚠️ Due to a Curve Pool limitation, we use `curveCalc.get_dx()` to get the EXACT ETH amount back in a transaction when ideally it should be called in a staticcall.
        // ⚠️ We do not check the alETH-ETH depeg.
        uint256 alETHToMint = _getAlETHToMint(amount);

        // Mint `alETHToMint` amount of alETH (i.e. debt token) from `owner` to `recipient` Alchemix account.
        alchemist.mintFrom(owner, alETHToMint, address(this));
        // Execute a Curve Pool exchange for `alETHToMint` amount of alETH tokens to at least `amount` ETH.
        alETHPool.exchange(
            1, // alETH
            0, // ETH
            alETHToMint,
            amount
        );

        emit Borrow(owner, alETHToMint, amount);
    }

    /// @dev Get the current alETH amount to get `amount` ETH amount back in from a Curve Pool exchange.
    ///
    /// @param amount The ETH amount to get back from the Curve alETH exchange in wei.
    /// @return The exact alETH amount to swap to get `amount` ETH back from a Curve exchange.
    function _getAlETHToMint(uint256 amount) internal view returns (uint256) {
        unchecked {
            uint256[2] memory b = alETHPool.get_balances();
            return curveCalc.get_dx(
                2,
                [b[0], b[1], 0, 0, 0, 0, 0, 0],
                alETHPool.A(),
                alETHPool.fee(),
                [uint256(1e18), 1e18, 0, 0, 0, 0, 0, 0],
                [uint256(1), 1, 0, 0, 0, 0, 0, 0],
                false,
                1, // alETH
                0, // ETH
                amount + 1 // Because of rounding errors
            );
        }
    }

    /// @notice To receive ETH payments.
    /// @dev To receive ETH from alETHPool.exchange(). ⚠️ The contract can receive ETH from another Ethereum account.
    receive() external payable virtual;
}
