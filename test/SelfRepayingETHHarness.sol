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

    /* --- REFERENCE IMPLEMENTATIONS --- */

    function exposed_getAlETHToMint_referenceImplementation(uint256 amount) external view returns (uint256) {
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
