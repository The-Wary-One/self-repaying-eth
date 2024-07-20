// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {stdError} from "../../lib/forge-std/src/Test.sol";

import {TestBase} from "../TestBase.sol";

import {SelfRepayingETH} from "../../src/SelfRepayingETH.sol";

contract BorrowSelfRepayingETHFromTests is TestBase {
    /// @dev Test `sreth._borrowSelfRepayingETHFrom()` happy path.
    function testFork_borrowSelfRepayingETHFrom_happy() external {
        // Techno needs to allow `sreth` to mint alETH debt token.
        vm.prank(techno, techno);
        config.alchemist.approveMint(address(sreth), type(uint256).max);

        // Check `sreth` balances before use.
        assertEq(address(sreth).balance, 0, "sreth shouldn't have ETH");
        assertEq(alETH.balanceOf(address(sreth)), 0, "sreth shouldn't have alETH");
        assertEq(config.weth.balanceOf(address(sreth)), 0, "sreth shouldn't have WETH");

        // Borrow `ethAmount` of `ETH` from `techno`.
        (int256 oldDebt,) = config.alchemist.accounts(techno);
        uint256 oldEthAmount = address(techno).balance;
        uint256 ethAmount = 1 ether;
        uint256 alETHToMint = sreth.exposed_getAlETHToMint(ethAmount);
        vm.expectEmit(true, true, true, true, address(sreth));
        emit SelfRepayingETH.Borrowed(
            techno,
            alETHToMint,
            ethAmount
        );
        sreth.exposed_borrowSelfRepayingETHFrom(techno, ethAmount);

        // Check it increased `techno`'s Alchemix debt.
        (int256 newDebt,) = config.alchemist.accounts(techno);
        assertGt(newDebt, oldDebt + int256(ethAmount), "techno's debt should have increased by at least ethAmount");
        // Check `sreth` balances after use.
        assertEq(address(sreth).balance, ethAmount, "sreth should have ethAmount of ETH");
        assertEq(alETH.balanceOf(address(sreth)), 0, "sreth shouldn't have any alETH");
        assertEq(config.weth.balanceOf(address(sreth)), 0, "sreth shouldn't have any alETH");
        // Check it sent the left over `ETH` back to `techno`.
        assertGt(address(techno).balance, oldEthAmount, "techno should have received the left over ETH");
    }

    /// @dev Test `sreth._borrowSelfRepayingETHFrom()` with a large ETH amount.
    ///
    /// @dev 💀 A large ETH exchange will be taken advantage off by MEV bots in a sandwich attack.
    function testFork_borrowSelfRepayingETHFrom_withALargeETHAmount() external {
        // Give `koala` a large ETH amount. 😀
        address koala = address(0xdeaddead);
        vm.label(koala, "koala");
        uint256 ethAmount = 3000 ether;
        vm.deal(koala, ethAmount);

        vm.deal(address(this), 100000 ether);
        config.weth.deposit{value: 10000 ether}();
        config.weth.approve(address(config.alETHPool), type(uint256).max);
        uint256[] memory amounts = new uint256[](2);
        amounts[1] = 10000 ether;
        config.alETHPool.add_liquidity(amounts, 0);

        // Create an Alchemix account.
        _createAlchemixAccount(koala, ethAmount);

        // Act as koala, an EOA.
        vm.prank(koala, koala);
        // `koala` needs to allow `sreth` to mint alETH debt token.
        config.alchemist.approveMint(address(sreth), type(uint256).max);

        ethAmount = 1200 ether;
        (int256 oldDebt,) = config.alchemist.accounts(koala);
        // Borrow `ethAmount` of ETH from `koala`.
        uint256 alETHToMint = sreth.exposed_getAlETHToMint(ethAmount);
        vm.expectEmit(true, true, true, true, address(sreth));
        emit SelfRepayingETH.Borrowed(koala, alETHToMint, ethAmount);
        sreth.exposed_borrowSelfRepayingETHFrom(koala, ethAmount);
        // Check `koala` new debt amount.
        (int256 newDebt,) = config.alchemist.accounts(koala);
        assertApproxEqRel(
            newDebt, oldDebt + int256(ethAmount), 0.02e18, "koala's debt should have increased by at least ethAmount"
        );
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
