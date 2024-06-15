// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {stdJson, Script} from "../lib/forge-std/src/Script.sol";

import {WETHGateway} from "../lib/alchemix/src/WETHGateway.sol";

import {AlchemicTokenV2, IAlchemistV2, ICurveCalc, ICurvePool, SelfRepayingETH} from "../src/SelfRepayingETH.sol";

contract Toolbox is Script {
    using stdJson for string;

    // ⚠️ We must follow the alphabetical order of the json file.
    struct Config {
        IAlchemistV2 alchemist;
        ICurveCalc curveCalc;
        ICurvePool alETHPool;
        WETHGateway wethGateway;
    }

    SelfRepayingETH private _sreth;
    Config private _config;

    /// @dev Get the environment config.
    function getConfig() public returns (Config memory) {
        // Try to get the cached value.
        if (address(_config.alchemist) != address(0)) {
            return _config;
        }

        // Get the deployed contracts addresses from the json config file.
        string memory root = vmSafe.projectRoot();
        string memory path = string.concat(root, "/deployments/external.json");
        string memory json = vmSafe.readFile(path);
        // Will panic if the network config is missing.
        bytes memory raw = json.parseRaw(string.concat(".chainId.", vmSafe.toString(block.chainid)));
        Config memory config = abi.decode(raw, (Config));
        // Cache value.
        _config = config;
        return config;
    }
}
