// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {AlETHRouter} from "src/AlETHRouter.sol";

/// @dev Send ETH for a user by minting AlETH debt.
contract Sender {
    AlETHRouter router;

    constructor(AlETHRouter _router) {
        router = _router;
    }

    function send(address to, uint256 amount) external {
        router.borrowAndSendETHFrom(msg.sender, to, amount);
    }
}
