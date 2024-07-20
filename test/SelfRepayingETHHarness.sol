// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {SelfRepayingETH, IAlchemistV2, IWETH9, AlchemicTokenV2, ICurveStableSwapNG} from "../src/SelfRepayingETH.sol";

/// @dev This indirection allows us to expose internal functions.
contract SelfRepayingETHHarness is SelfRepayingETH {
    constructor(IAlchemistV2 _alchemist, ICurveStableSwapNG _alETHPool, IWETH9 _weth)
        SelfRepayingETH(_alchemist, _alETHPool, _weth)
    {}

    receive() external payable override {}

    /* --- EXPOSED INTERNAL FUNCTIONS --- */

    function exposed_borrowSelfRepayingETHFrom(address owner, uint256 amount) external {
        return _borrowSelfRepayingETHFrom(owner, amount);
    }

    function exposed_getAlETHToMint(uint256 amount) external view returns (uint256) {
        return _getAlETHToMint(amount);
    }

    /* --- REFERENCE IMPLEMENTATIONS --- */
}
