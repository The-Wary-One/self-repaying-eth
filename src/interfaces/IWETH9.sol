// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {IERC20} from "../../lib/forge-std/src/interfaces/IERC20.sol";

/// @dev Interface of the WETH9 solidity contract.
interface IWETH9 is IERC20 {
    function withdraw(uint256 wad) external;
    function deposit() external payable;
}
