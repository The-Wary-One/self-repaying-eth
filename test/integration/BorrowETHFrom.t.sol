// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {stdError} from "../../lib/forge-std/src/Test.sol";

import {TestBase} from "../TestBase.sol";

contract GetAlETHToMintTests is TestBase {
    // Test `sreth._getAlETHToMint()` yul implementation against solidity.
    function testFuzz_getAlETHToMint_implementation(uint256 amount) external {
        assertEqCall(address(sreth), abi.encodeCall(sreth.exposed_getAlETHToMint, amount), abi.encodeCall(sreth.exposed_getAlETHToMint_referenceImplementation, amount));
    }
}

contract BorrowSelfRepayingETHFromTests is TestBase {
    // Test `sreth._borrowSelfRepayingETHFrom()` happy path.
    function testFork_borrowSelfRepayingETHFrom_happy() external {
        // Techno needs to allow `sreth` to mint alETH debt token.
        vm.prank(techno, techno);
        config.alchemist.approveMint(address(sreth), type(uint256).max);

        (int256 oldDebt,) = config.alchemist.accounts(techno);
        uint256 ethAmount = 1 ether;
        // Check `sreth` balances before use.
        assertEq(address(sreth).balance, 0, "sreth shouldn't have ETH");
        assertEq(alETH.balanceOf(address(sreth)), 0, "sreth shouldn't have alETH");

        // Borrow `ethAmount` of ETH from `techno`.
        uint256 alETHToMint = sreth.exposed_getAlETHToMint(ethAmount);
        vm.expectEmit(true, true, true, true, address(sreth));
        emit Borrow(techno, alETHToMint, ethAmount);
        sreth.exposed_borrowSelfRepayingETHFrom(techno, ethAmount);

        // Check it increased `techno`'s Alchemix debt.
        (int256 newDebt,) = config.alchemist.accounts(techno);
        assertTrue(newDebt >= oldDebt + int256(ethAmount), "techno's debt should have increased by at least ethAmount");
        // Check `sreth` balances after use.
        assertEq(address(sreth).balance, ethAmount, "sreth should have ethAmount of ETH");
        assertEq(alETH.balanceOf(address(sreth)), 0, "sreth shouldn't have any alETH");
    }

    /// @dev Test `sreth._borrowSelfRepayingETHFrom()` with a large ETH amount.
    ///
    /// @dev **_NOTE:_** 💀 A large ETH exchange will be taken advantage off by MEV bots in a sandwich attack.
    function testFork_borrowSelfRepayingETHFrom_withALargeETHAmount() external {
        // Give `koala` 3000 ETH. 😀
        address koala = address(0xdeaddead);
        vm.label(koala, "koala");
        uint256 ethAmount = 2600 ether;
        vm.deal(koala, ethAmount);

        // Act as koala, an EOA.
        vm.startPrank(koala, koala);
        // Create an Alchemix account.
        _createAlchemixAccount(koala, ethAmount);

        // `koala` needs to allow `sreth` to mint alETH debt token.
        config.alchemist.approveMint(address(sreth), type(uint256).max);
        vm.stopPrank();

        ethAmount = 1200 ether;
        (int256 oldDebt,) = config.alchemist.accounts(koala);
        // Borrow `ethAmount` of ETH from `koala`.
        uint256 alETHToMint = sreth.exposed_getAlETHToMint(ethAmount);
        vm.expectEmit(true, true, true, true, address(sreth));
        emit Borrow(koala, alETHToMint, ethAmount);
        sreth.exposed_borrowSelfRepayingETHFrom(koala, ethAmount);
        // Check `koala` new debt amount.
        (int256 newDebt,) = config.alchemist.accounts(koala);
        assertApproxEqRel(newDebt, oldDebt + int256(ethAmount), 0.02e18, "koala's debt should have increased by at least ethAmount");
    }
}

contract BorrowSelfRepayingETHFromFailureTests is TestBase {
    /// @dev Test `sreth._borrowSelfRepayingETHFrom()` reverts when owner did not approve it to mint alETH.
    function testFork_borrowSelfRepayingETHFrom_failIfNotApproved() external {
        // Techno did not approve the `sreth` to mint debt.
        vm.prank(techno, techno);
        vm.expectRevert(stdError.arithmeticError);
        sreth.exposed_borrowSelfRepayingETHFrom(techno, 1 ether);
    }
}
