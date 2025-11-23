// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {MyToken} from "../src/MyToken.sol";

contract MyTokenTest is Test {
    MyToken public token;
    address public owner = address(1);
    address public user1 = address(2);
    address public user2 = address(3);

    function setUp() public {
        // 在每个测试前运行
        token = new MyToken("My Token", "MTK", 1000 * 10 ** 18);
        // 将代币转移给owner
        token.transfer(owner, 1000 * 10 ** 18);
    }

    function testInitialSupply() public {
        assertEq(token.totalSupply(), 1000 * 10 ** 18);
    }

    function testTransfer() public {
        vm.prank(owner); // 模拟owner调用
        token.transfer(user1, 100 * 10 ** 18);

        assertEq(token.balanceOf(user1), 100 * 10 ** 18);
        assertEq(token.balanceOf(owner), 900 * 10 ** 18);
    }

    function testApproveAndTransferFrom() public {
        vm.prank(owner);
        token.approve(user1, 50 * 10 ** 18);

        assertEq(token.allowance(owner, user1), 50 * 10 ** 18);

        vm.prank(user1);
        token.transferFrom(owner, user2, 30 * 10 ** 18);

        assertEq(token.balanceOf(user2), 30 * 10 ** 18);
        assertEq(token.balanceOf(owner), 970 * 10 ** 18);
        assertEq(token.allowance(owner, user1), 20 * 10 ** 18);
    }

    function testFailInsufficientBalanceTransfer() public {
        vm.prank(user1); // user1没有代币
        token.transfer(owner, 1 * 10 ** 18); // 应该失败
    }

    function testFuzz_Transfer(uint256 amount) public {
        vm.assume(amount <= token.balanceOf(owner)); // 确保金额合理
        vm.prank(owner);
        token.transfer(user1, amount);

        assertEq(token.balanceOf(user1), amount);
    }
}
