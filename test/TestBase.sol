// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Test} from "../lib/forge-std/src/Test.sol";

import {Whitelist} from "../lib/alchemix/src/utils/Whitelist.sol";

import {AlchemicTokenV2, SelfRepayingETHHarness} from "./SelfRepayingETHHarness.sol";

import {Toolbox} from "../script/Toolbox.s.sol";

contract TestBase is Test {
    Toolbox toolbox;
    Toolbox.Config config;
    SelfRepayingETHHarness sreth;
    AlchemicTokenV2 alETH;
    address techno = address(0xbadbabe);

    /// @dev Copied from the `SelfRepayingETH` contract.
    event Borrow(address indexed owner, uint256 alETHAmount, uint256 ethAmount);

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
        sreth = new SelfRepayingETHHarness(config.alchemist, config.alETHPool, config.curveCalc);

        // Add the `SelfRepayingETH` harness contract address to alETH AlchemistV2's whitelist.
        Whitelist whitelist = Whitelist(config.alchemist.whitelist());
        vm.prank(whitelist.owner());
        whitelist.add(address(sreth));
        assertTrue(whitelist.isWhitelisted(address(sreth)), "Should be whitelisted");

        // Give `techno` 100 ETH. 😀
        vm.label(techno, "techno");
        vm.deal(techno, 100 ether);

        // Act as Techno, an EOA. Alchemix checks msg.sender === tx.origin to know if sender is an EOA.
        vm.startPrank(techno, techno);

        // Get the first supported yield ETH token.
        address[] memory supportedTokens = config.alchemist.getSupportedYieldTokens();
        // Create an Alchemix account.
        config.wethGateway.depositUnderlying{value: 10 ether}(
            address(config.alchemist), supportedTokens[0], 10 ether, techno, 1
        );

        vm.stopPrank();
    }
}
