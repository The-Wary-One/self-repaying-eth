// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {TestBase} from "../TestBase.sol";

contract SelfRepayingETHTests is TestBase {
    /// @dev Test `sreth` approved the `alETHPool` to transfer an (almost) unlimited amount of `alETH` tokens.
    function testFork_constructor_alETHPoolIsApprovedAtDeployment() external {
        assertEq(alETH.allowance(address(sreth), address(config.alETHPool)), type(uint256).max);
    }
}
