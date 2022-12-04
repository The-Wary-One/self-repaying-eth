// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { Script } from "../lib/forge-std/src/Script.sol";

import {
    AlETHRouter,
    IAlchemistV2,
    ICurvePool,
    ICurveCalc
} from "../src/AlETHRouter.sol";
import { Toolbox } from "./Toolbox.s.sol";

contract DeployAlETHRouter is Script {

    /// @dev Deploy the contract on the target chain.
    function run() external returns (AlETHRouter) {
        // Get the config.
        Toolbox toolbox = new Toolbox();
        Toolbox.Config memory config = toolbox.getConfig();

        return deploy(
            config.alchemist,
            config.alETHPool,
            config.curveCalc
        );
    }

    /// @dev Deploy the contract.
    function deploy(
        IAlchemistV2 alchemist,
        ICurvePool alETHPool,
        ICurveCalc curveCalc
    ) public returns (AlETHRouter) {
        // Deploy the AlETHRouter contract.
        vmSafe.broadcast();
        AlETHRouter router = new AlETHRouter(
            alchemist,
            alETHPool,
            curveCalc
        );

        return router;
    }
}
