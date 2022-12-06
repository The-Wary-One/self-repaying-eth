// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {Test, stdError} from "../lib/forge-std/src/Test.sol";
import {Whitelist} from "../lib/alchemix/src/utils/Whitelist.sol";

import {AlETHRouter, AlchemicTokenV2} from "../src/AlETHRouter.sol";
import {Sender} from "./mocks/Sender.sol";
import {Toolbox} from "../script/Toolbox.s.sol";
import {DeployAlETHRouter} from "../script/DeployAlETHRouter.s.sol";

contract AlETHRouterTest is Test {
    Toolbox toolbox;
    Toolbox.Config config;
    AlETHRouter router;
    AlchemicTokenV2 alETH;
    Sender sender;
    address techno = address(0xbadbabe);

    /// @dev Copied from the `AlETHRouter` contract.
    event Approve(address indexed owner, address indexed spender, uint256 amount);
    event Borrow(
        address indexed borrower,
        address indexed owner,
        address indexed recipient,
        uint256 alETHAmount,
        uint256 ethAmount
    );

    /// @dev Setup the environment for the tests.
    function setUp() external {
        // Make sure we run the tests on a mainnet fork to reuse the prod env.
        string memory RPC_MAINNET = vm.envString("RPC_MAINNET");
        uint256 BLOCK_NUMBER_MAINNET = vm.envUint("BLOCK_NUMBER_MAINNET");
        vm.createSelectFork(RPC_MAINNET, BLOCK_NUMBER_MAINNET);
        require(block.chainid == 1, "Tests should be run on a mainnet fork");

        // Get the mainnet config.
        toolbox = new Toolbox();
        config = toolbox.getConfig();

        // Deploy the router using the deployment script.
        DeployAlETHRouter deployer = new DeployAlETHRouter();
        router = deployer.run();

        // The contract should not be ready for use.
        {
            (bool isReady1, string memory message1) = toolbox.check(router);
            assertFalse(isReady1);
            assertEq(message1, "Alchemix must whitelist the contract");
        }

        // Add the `router` contract address to alETH AlchemistV2's whitelist.
        Whitelist whitelist = Whitelist(config.alchemist.whitelist());
        vm.prank(whitelist.owner());
        whitelist.add(address(router));
        assertTrue(whitelist.isWhitelisted(address(router)));

        // The contract is ready to be used.
        (bool isReady, string memory message) = toolbox.check(router);
        assertTrue(isReady);
        assertEq(message, "Contract ready !");

        // Give `techno` 100 ETH. 😀
        vm.label(techno, "techno");
        vm.deal(techno, 100 ether);

        alETH = AlchemicTokenV2(config.alchemist.debtToken());

        // Act as Techno, an EOA. Alchemix checks msg.sender === tx.origin to know if sender is an EOA.
        vm.startPrank(techno, techno);

        // Get the first supported yield ETH token.
        address[] memory supportedTokens = config.alchemist.getSupportedYieldTokens();
        // Create an Alchemix account.
        config.wethGateway.depositUnderlying{value: 10 ether}(
            address(config.alchemist), supportedTokens[0], 10 ether, techno, 1
        );

        // Deploy a contract that uses the router for testing.
        sender = new Sender(router);

        vm.stopPrank();
    }

    /// @dev Simulate an entire user interaction with `router`.
    function testFullInteraction() external {
        // Act as Techno, an EOA.
        vm.startPrank(techno, techno);

        // Techno needs to allow `router` to mint alETH debt token.
        config.alchemist.approveMint(address(router), type(uint256).max);
        // Techno needs to allow `sender` contract to use the router.
        router.approve(address(sender), type(uint256).max);

        address nano = address(0xdeaddead);
        vm.label(nano, "nano");
        // Check `nano` balance before router use.
        assertEq(nano.balance, 0);
        // Test `sender`, a contract can use `router` by sending `amount` ETH from `techno`'s debt to `nano`.
        uint256 amount = 1 ether;
        sender.send(nano, amount);
        // Check `nano` balance after use.
        assertEq(nano.balance, amount);
    }

    /// @dev Test `router` approved the `alETHPool` to transfer an (almost) unlimited amount of `alETH` tokens.
    function testAlETHPoolIsApprovedAtDeployment() external {
        alETH = AlchemicTokenV2(config.alchemist.debtToken());
        assertEq(alETH.allowance(address(router), address(config.alETHPool)), type(uint256).max);
    }

    /// @dev Test `router.approve()` should set `spender` allowance.
    function testApprove() public {
        // Act as techno, an EOA.
        vm.prank(techno, techno);

        // Allow `sender` contract to use the `router` for `techno`.
        vm.expectEmit(true, true, true, true, address(router));
        emit Approve(techno, address(sender), type(uint256).max);
        router.approve(address(sender), type(uint256).max);

        // Check allowance.
        assertEq(router.allowance(techno, address(sender)), type(uint256).max);
    }

    /// @dev Test we can reset an approval by setting allowance to zero.
    function testApproveReset() public {
        // In the past we approve `sender`.
        testApprove();

        // Act as techno, an EOA.
        vm.prank(techno, techno);

        // Remove approval by setting allowance to zero.
        vm.expectEmit(true, true, true, true, address(router));
        emit Approve(techno, address(sender), 0);
        router.approve(address(sender), 0);

        // Check allowance.
        assertEq(router.allowance(techno, address(sender)), 0);
    }

    /// @dev Test `router.borrowAndSendETH()` happy path.
    function testBorrowAndSendETH() external {
        // Act as Techno, an EOA.
        vm.startPrank(techno, techno);

        // Techno needs to allow `router` to mint alETH debt token.
        config.alchemist.approveMint(address(router), type(uint256).max);

        uint256 amount = 1 ether;
        address koala = address(0xdeadbabe);
        vm.label(koala, "koala");
        // Techno needs to allow `koala` to use the router.
        router.approve(koala, amount);
        // Techno needs to allow `sender` to use the router.
        router.approve(address(sender), amount);

        vm.stopPrank();

        uint256 oldBalance = techno.balance;
        (int256 oldDebt,) = config.alchemist.accounts(techno);
        // Check `router` balances before router use.
        assertEq(address(router).balance, 0);
        assertEq(alETH.balanceOf(address(router)), 0);
        // Check `sender` balances before router use.
        assertEq(address(sender).balance, 0);
        assertEq(alETH.balanceOf(address(sender)), 0);
        // Check `koala` balances before router use.
        assertEq(koala.balance, 0);
        assertEq(alETH.balanceOf(koala), 0);

        // Test can use the `router` themselves.
        vm.prank(techno, techno);
        vm.expectEmit(true, true, true, false, address(router));
        emit Borrow(techno, techno, techno, 0, amount);
        router.borrowAndSendETH(techno, amount);
        // Test `sender`, a contract, can use `router`.
        vm.prank(techno, techno);
        vm.expectEmit(true, true, true, false, address(router));
        emit Borrow(address(sender), techno, techno, 0, amount);
        sender.send(techno, amount);
        // Test `koala`, an EOA, can use `router`.
        vm.prank(koala, koala);
        vm.expectEmit(true, true, true, false, address(router));
        emit Borrow(koala, techno, techno, 0, amount);
        router.borrowAndSendETHFrom(techno, techno, amount);

        // Check it increased `techno`'s Alchemix debt.
        (int256 newDebt,) = config.alchemist.accounts(techno);
        assertTrue(newDebt >= oldDebt + int256(3 * amount));
        // Check `techno` balances after router use.
        assertEq(techno.balance, oldBalance + 3 * amount);
        assertEq(alETH.balanceOf(techno), 0);
        // Check `router` balances after router use.
        assertEq(address(router).balance, 0);
        assertEq(alETH.balanceOf(address(router)), 0);
        // Check `sender` balances after router use.
        assertEq(address(sender).balance, 0);
        assertEq(alETH.balanceOf(address(sender)), 0);
        // Check `koala` balances after use.
        assertEq(koala.balance, 0);
        assertEq(alETH.balanceOf(koala), 0);
    }

    /// @dev Test `router.borrowAndSendETH()` with a large amount.
    ///
    /// @dev **_NOTE:_** 💀 A large ETH exchange will be taken advantage off by MEV bots in a sandwich attack.
    function testBorrowAndSendETHWithALargeAmount() external {
        // Give `nano` 3000 ETH. 😀
        address nano = address(0xdeaddead);
        vm.label(nano, "nano");
        uint256 ethAmount = 3000 ether;
        vm.deal(nano, ethAmount);

        // Act as nano, an EOA.
        vm.startPrank(nano, nano);

        // Get the first supported yield ETH token.
        address[] memory supportedTokens = config.alchemist.getSupportedYieldTokens();
        // Create an Alchemix account.
        config.wethGateway.depositUnderlying{value: ethAmount}(
            address(config.alchemist), supportedTokens[0], ethAmount, nano, 1
        );

        // `nano` needs to allow `router` to mint alETH debt token.
        config.alchemist.approveMint(address(router), type(uint256).max);

        (int256 oldDebt,) = config.alchemist.accounts(nano);
        // Test can use the `router` themselves.
        vm.expectEmit(true, true, true, false, address(router));
        emit Borrow(nano, nano, nano, 0, 0);
        router.borrowAndSendETH(nano, 1400 ether);

        // Check `nano` new debt amount.
        (int256 newDebt,) = config.alchemist.accounts(nano);
        assertApproxEqRel(newDebt, oldDebt + int256(1400 ether), 0.02e18);
    }

    /// @dev Test `router.borrowAndSendETH()` reverts when `router` is not approved by the user.
    function testBorrowAndSendETHWhenRouterNotApproved() external {
        // Act as Techno, an EOA.
        vm.startPrank(techno, techno);

        // Techno did not approve the `router` to mint debt.
        vm.expectRevert(stdError.arithmeticError);
        router.borrowAndSendETH(techno, 1 ether);
    }

    /// @dev Test `router.borrowAndSendETH()` reverts when the borrower is not approved by the user.
    function testBorrowAndSendETHWhenBorrowerNotApproved() external {
        // Act as Techno, an EOA.
        vm.startPrank(techno, techno);

        // Techno allows `router` to mint alETH debt token.
        config.alchemist.approveMint(address(router), type(uint256).max);
        // Techno did not approve the borrower to use `router`.
        vm.expectRevert(stdError.arithmeticError);
        router.borrowAndSendETHFrom(techno, techno, 1 ether);
    }
}
