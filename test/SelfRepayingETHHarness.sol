// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../src/SelfRepayingETH.sol";

/// @dev This indirection allows us to expose internal functions.
contract SelfRepayingETHHarness is SelfRepayingETH {
    constructor(IAlchemistV2 _alchemist, ICurvePool _alETHPool, ICurveCalc _curveCalc)
        SelfRepayingETH(_alchemist, _alETHPool, _curveCalc)
    {}

    receive() external payable override {}

    /* --- EXPOSED INTERNAL FUNCTIONS --- */

    function exposed_borrowSelfRepayingETHFrom(address owner, uint256 amount) external {
        return _borrowSelfRepayingETHFrom(owner, amount);
    }

    function exposed_getAlETHToMint(uint256 amount) external view returns (uint256) {
        return _getAlETHToMint(amount);
    }
}
