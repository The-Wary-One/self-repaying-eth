// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {IAlchemistV2} from "../lib/alchemix/src/interfaces/IAlchemistV2.sol";
import {AlchemicTokenV2} from "../lib/alchemix/src/AlchemicTokenV2.sol";

import {ICurvePool} from "./interfaces/ICurvePool.sol";
import {ICurveCalc} from "./interfaces/ICurveCalc.sol";

/// @title AlETHRouter
/// @author Wary
///
/// @notice An contract helper to borrow alETH from an Alchemix account, exchange them for ETH and send them.
contract AlETHRouter {
    /// @notice The Alchemix alETH alchemistV2 contract.
    IAlchemistV2 public immutable alchemist;

    /// @notice The Alchemix alETH AlchemicTokenV2 contract.
    AlchemicTokenV2 public immutable alETH;

    /// @notice The alETH-ETH Curve Pool contract.
    ICurvePool public immutable alETHPool;

    /// @notice The CurveCalc contract.
    ICurveCalc public immutable curveCalc;

    /// @notice The allowance for using the router.
    mapping(address => mapping(address => uint256)) public allowance;

    /// @notice Emitted when `owner` grants `borrower` the ability to mint debt tokens on their behalf.
    ///
    /// @param owner The address of the account owner.
    /// @param borrower The address which is being permitted to mint tokens on the behalf of `owner`.
    /// @param amount The amount of debt tokens that `borrower` is allowed to mint in wei.
    event Approve(address indexed owner, address indexed borrower, uint256 amount);

    /// @notice Emitted when `borrower` borrows `alETHAmount` from `owner` and send `ethAmount` to `recipient`.
    ///
    /// @param borrower The address using the router.
    /// @param owner The address of the Alchemix account owner.
    /// @param recipient The address that received the borrowed ETH.
    /// @param alETHAmount The amount of debt tokens that router minted in wei.
    /// @param ethAmount The amount of exchanged ETH sent to `recipient` in wei.
    event Borrow(
        address indexed borrower,
        address indexed owner,
        address indexed recipient,
        uint256 alETHAmount,
        uint256 ethAmount
    );

    /// @notice Initialize the contract.
    ///
    /// @dev We annotate it payable to make it cheaper. Do not send ETH.
    constructor(IAlchemistV2 _alchemist, ICurvePool _alETHPool, ICurveCalc _curveCalc) payable {
        alchemist = _alchemist;
        alETHPool = _alETHPool;
        curveCalc = _curveCalc;

        alETH = AlchemicTokenV2(alchemist.debtToken());

        // Approve the `alETHPool` Curve Pool to transfer an (almost) unlimited amount of `alETH` tokens.
        alETH.approve(address(_alETHPool), type(uint256).max);
    }

    /// @notice Borrow and send ETH `amount` from the AlETH account owned by `msg.sender` to `recipient`.
    ///
    /// @notice Emits a {Borrow} event.
    ///
    /// @notice **_NOTE:_** The `AlETHRouter` contract must have enough `AlchemistV2.mintAllowance()` to borrow `amount` ETH. The can be done via the `AlchemistV2.approveMint()` method.
    ///
    /// @dev **_NOTE:_** 💀 There is no protection against the alETH-ETH depeg.
    /// @dev **_NOTE:_** 💀 A large `amount` to exchange will be taken advantage off by MEV bots in a sandwich attack.
    ///
    /// @param recipient The address to send the borrowed ETH to.
    /// @param amount The amount of ETH to borrow in wei.
    function borrowAndSendETH(address recipient, uint256 amount) external {
        _borrowAndSendETH(msg.sender, recipient, amount);
    }

    /// @notice Borrow and send ETH `amount` from the AlETH account owned by `owner` to `recipient`.
    ///
    /// @notice Emits a {Borrow} event.
    ///
    /// @notice **_NOTE:_** The `AlETHRouter` contract must have enough `AlchemistV2.mintAllowance()` to borrow `amount` ETH. The can be done via the `AlchemistV2.approveMint()` method.
    /// @notice **_NOTE:_** The `msg.sender` (i.e. borrower) must make sure they have at least `amount` allowance.
    ///
    /// @dev **_NOTE:_** 💀 There is no protection against the alETH-ETH depeg.
    /// @dev **_NOTE:_** 💀 A large `amount` exchange will be taken advantage off by MEV bots in a sandwich attack.
    ///
    /// @param owner The address of the Alchemix account owner to mint alETH from.
    /// @param recipient The address to send the borrowed ETH to.
    /// @param amount The amount of ETH to borrow in wei.
    function borrowAndSendETHFrom(address owner, address recipient, uint256 amount) external {
        // Decrease `recipient` mint allowance for `owner`. Reverts if does not have enough allowance.
        // ⚠️ Prevents a reentrancy attack here.
        allowance[owner][msg.sender] -= amount;

        _borrowAndSendETH(owner, recipient, amount);
    }

    function _borrowAndSendETH(address owner, address recipient, uint256 amount) internal {
        // Get the EXACT amount of ETH debt (i.e. alETH) to mint from the Curve Pool by asking the CurveCalc contract.
        // ⚠️ Due to a Curve Pool limitation, we use `curveCalc.get_dx()` to get the EXACT ETH amount back in a transaction when ideally it should be called in a staticcall.
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

        // Send all the received ETH to `recipient`. No ETH will be stuck in this contract.
        // ⚠️ .transfer() prevents a reentrancy attack.
        payable(recipient).transfer(address(this).balance);

        emit Borrow(msg.sender, owner, recipient, alETHToMint, amount);
    }

    /// @notice Approve `borrower` to borrow and send `amount` of ETH using this contract.
    ///
    /// @param borrower The address allowed to borrow.
    /// @param amount The ETH amount allowed for `borrower` in wei.
    function approve(address borrower, uint256 amount) external {
        allowance[msg.sender][borrower] = amount;
        emit Approve(msg.sender, borrower, amount);
    }

    /// @dev Get the current alETH amount to get `amount` ETH amount back in from a Curve Pool exchange.
    ///
    /// @param amount The ETH amount to get back from the Curve alETH exchange in wei.
    /// @return The exact alETH amount to swap to get `amount` ETH back form a Curve exchange.
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
                amount + 1 // Because of Curve rounding errors
            );
        }
    }

    /// @notice To receive ETH payments.
    /// @dev To receive ETH from alETHPool.exchange().
    /// @dev All other received ETH will be sent to the next borrowAndSendETH() and borrowAndSendETHFrom() recipient.
    receive() external payable {}
}
