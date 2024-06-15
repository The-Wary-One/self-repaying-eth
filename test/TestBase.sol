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

        // Create an Alchemix account with the first supported yield ETH token available.
        _createAlchemixAccount(techno, 10 ether);

        vm.stopPrank();
    }

    /// @dev Create an Alchemix account with the first supported yield ETH token available.
    function _createAlchemixAccount(address target, uint256 value) internal returns (address) {
        address[] memory supportedTokens = config.alchemist.getSupportedYieldTokens();
        address yieldToken;
        // Try to create an Alchemix account with the supported yield ETH tokens until we find their vaults not yet full.
        for (uint8 i = 0; i < supportedTokens.length; i++) {
            yieldToken = supportedTokens[i];
            try config.wethGateway.depositUnderlying{value: value}(
                address(config.alchemist), yieldToken, value, target, 1
            ) {
                break;
            } catch {
                continue;
            }
        }
        assertTrue(yieldToken != address(0), "Couldn't find any available yield tokens");
        return yieldToken;
    }
}
