// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Test} from "../lib/forge-std/src/Test.sol";

import {IAlchemistV2State} from "../lib/alchemix/src/interfaces/alchemist/IAlchemistV2State.sol";
import {Whitelist} from "../lib/alchemix/src/utils/Whitelist.sol";

import {AlchemicTokenV2, IWETH9, SelfRepayingETHHarness} from "./SelfRepayingETHHarness.sol";

import {Toolbox} from "../script/Toolbox.s.sol";

contract TestBase is Test {
    Toolbox toolbox;
    Toolbox.Config config;
    SelfRepayingETHHarness sreth;
    AlchemicTokenV2 alETH;
    address techno = address(0xbadbabe);

    /// @dev Setup the environment for the tests.
    function setUp() public virtual {
        // Make sure we run the tests on a mainnet fork.
        Chain memory mainnet = getChain("mainnet");
        uint256 BLOCK_NUMBER_MAINNET = vm.envUint("BLOCK_NUMBER_MAINNET");
        vm.createSelectFork(mainnet.rpcUrl, BLOCK_NUMBER_MAINNET);
        require(block.chainid == 1, "Tests should be run on a mainnet fork");

        // Get the mainnet config.
        toolbox = new Toolbox();
        config = toolbox.getConfig();
        alETH = AlchemicTokenV2(config.alchemist.debtToken());

        // Deploy a contract that uses the sreth for testing.
        sreth = new SelfRepayingETHHarness(config.alchemist, config.alETHPool, config.weth);

        // Add the `SelfRepayingETH` harness contract address to alETH AlchemistV2's whitelist.
        Whitelist whitelist = Whitelist(config.alchemist.whitelist());
        vm.prank(whitelist.owner());
        whitelist.add(address(sreth));
        assertTrue(whitelist.isWhitelisted(address(sreth)), "Should be whitelisted");

        // Give `techno` 100 ETH. 😀
        vm.label(techno, "techno");
        vm.deal(techno, 100 ether);

        // Create an Alchemix account with the first supported yield ETH token available.
        _createAlchemixAccount(techno, 10 ether);
    }

    /// @dev Create an Alchemix account with the first supported yield ETH token.
    function _createAlchemixAccount(address target, uint256 value) internal {
        address[] memory supportedTokens = config.alchemist.getSupportedYieldTokens();
        address yieldToken = supportedTokens[0];

        IAlchemistV2State.YieldTokenParams memory params = config.alchemist.getYieldTokenParameters(yieldToken);
        assertTrue(params.enabled, "Should be enabled");
        vm.prank(config.alchemist.admin());
        config.alchemist.setMaximumExpectedValue(yieldToken, params.maximumExpectedValue + value);

        // Act as `target`, an EOA. Alchemix checks msg.sender === tx.origin to know if sender is an EOA.
        vm.prank(target, target);
        // Create an Alchemix account with the first supported yield ETH token.
        config.wethGateway.depositUnderlying{value: value}(address(config.alchemist), yieldToken, value, target, 1);
    }
}
