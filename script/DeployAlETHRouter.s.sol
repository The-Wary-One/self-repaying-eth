// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { Script } from "forge-std/Script.sol";

import { AlETHRouter } from "src/AlETHRouter.sol";
import { Toolbox } from "script/Toolbox.s.sol";

contract DeployAlETHRouter is Script {

    /// @dev Deploy the contract on the target chain.
    function run() external returns (AlETHRouter) {
        // Get the config.
        Toolbox toolbox = new Toolbox();
        Toolbox.Config memory config = toolbox.getConfig();

        vm.startBroadcast();

        // Deploy the AlETHRouter contract.
        AlETHRouter router = new AlETHRouter(
            config.alchemist,
            config.alETHPool,
            config.curveCalc
        );

        vm.stopBroadcast();

        return router;
    }
}
