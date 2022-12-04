// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { Script, stdJson, console2 } from "../lib/forge-std/src/Script.sol";
import { WETHGateway } from "../lib/alchemix/src/WETHGateway.sol";
import { Whitelist } from "../lib/alchemix/src/utils/Whitelist.sol";

import {
    AlETHRouter,
    IAlchemistV2,
    AlchemicTokenV2,
    ICurvePool,
    ICurveCalc
} from "../src/AlETHRouter.sol";

contract Toolbox is Script {

    using stdJson for string;

    // We must follow the alphabetical order of the json file.
    struct Config {
        IAlchemistV2 alchemist;
        ICurvePool alETHPool;
        ICurveCalc curveCalc;
        WETHGateway wethGateway;
    }

    AlETHRouter private _router;
    Config private _config;

    /// @dev Check the last contract deployment on the target chain.
    function getLastRouterDeployment() public returns (AlETHRouter) {
        // Try to get the cached value.
        if (address(_router) != address(0)) {
            return _router;
        }
        // Get the last deployment address on this chain.
        string memory root = vmSafe.projectRoot();
        string memory path = string.concat(
            root,
            "/broadcast/DeployAlETHRouter.s.sol/",
            vmSafe.toString(block.chainid),
            "/run-latest.json"
        );
        // Will throw if the file is missing.
        string memory json = vmSafe.readFile(path);
        // Get the value at `contractAddress` of a `CREATE` transaction.
        address addr = json.readAddress(
            // FIXME: This should be correct "$.transactions.[?(@.transactionType == 'CREATE' && @.contractName == 'AlETHRouter')].contractAddress"
            "transactions[?(@.transactionType == 'CREATE')].contractAddress"
        );
        AlETHRouter router = AlETHRouter(payable(addr));

        // Cache value.
        _router = router;
        return router;
    }

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
        bytes memory raw = json.parseRaw(string.concat("chainId.", vmSafe.toString(block.chainid)));
        Config memory config = abi.decode(raw, (Config));
        // Cache value.
        _config = config;
        return config;
    }

    /// @dev Check if the last deployed `AlETHRouter` contract is ready to be used.
    function check() public returns (bool isReady, string memory message) {
        // Get the last deployment address on this chain.
        AlETHRouter router = getLastRouterDeployment();
        return check(router);
    }

    /// @dev Check if a `AlETHRouter` contract is ready to be used.
    function check(AlETHRouter router) public returns (bool isReady, string memory message) {
        // Check if `router` was deployed.
        if (address(router).code.length == 0) {
            return (false, "Not Deployed");
        }

        // Get the chain config.
        Config memory config = getConfig();
        // Check if `router` is whitelisted by Alchemix's AlchemistV2 alETH contract.
        Whitelist whitelist = Whitelist(config.alchemist.whitelist());
        if (!whitelist.isWhitelisted(address(router))) {
            return (false, "Alchemix must whitelist the contract");
        }

        // All checks passed.
        return (true, "Contract ready !");
    }

    /// @dev Approve the last deployed router contract to mint alETH debt.
    function approveMint() external {
        // Get the config.
        Config memory config = getConfig();
        // Get the last deployment address on this chain.
        AlETHRouter router = getLastRouterDeployment();

        // Approve router to mint debt.
        vmSafe.broadcast();
        config.alchemist.approveMint(address(router), type(uint256).max);
    }

    /// @dev Approve the use of the last deployed router contract for `borrower`.
    function approve(address borrower) external {
        // Get the last deployment address on this chain.
        AlETHRouter router = getLastRouterDeployment();

        // Approve `borrower` to use router.
        vmSafe.broadcast();
        router.approve(borrower, type(uint256).max);
    }

    /// @dev Call `AlETHRouter.borrowAndSendETHFrom()` on the last deployed router.
    function borrowAndSendETHFrom(address owner, address recipient, uint256 amount) external {
        // Get the last deployment address on this chain.
        AlETHRouter router = getLastRouterDeployment();

        // Borrow and send ETH.
        vmSafe.broadcast();
        router.borrowAndSendETHFrom(owner, recipient, amount);
    }

    /// @dev Create an Alchemix account.
    function depositUnderlying() external {
        // Get the config.
        Config memory config = getConfig();

        // Get the first supported yield ETH token.
        address[] memory supportedTokens = config.alchemist.getSupportedYieldTokens();
        // Create an Alchemix account.
        vmSafe.broadcast();
        config.wethGateway.depositUnderlying{value: 10 ether}(
            address(config.alchemist),
            supportedTokens[0],
            10 ether,
            msg.sender,
            1
        );
    }
}
