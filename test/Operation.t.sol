
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Operation.sol";

contract OperationTest is Test {
    Operation public op;

    function setUp() public {
        op = new Operation();
    }
    function testAdd() public {
        op.add(1, 2);
    }
    function testSub() public {
        op.subtract(5, 2);
    }
    function testMul() public {
        op.multiply(3, 2);
    }
    function testDiv() public {
        op.divide(2, 2);
    } 
}