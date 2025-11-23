
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;


contract Operation { 

    mapping(string => uint256) public operations;

    //初始化加减乘除的运算次数
    constructor() {
        operations["add"] = 0;
        operations["subtract"] = 0;
        operations["multiply"] = 0;
        operations["divide"] = 0;
    }

    function add(uint256 a, uint256 b) public returns (uint256){
        operations["add"]++;
        return a + b;
    }
    function subtract(uint256 a, uint256 b) public  returns (uint256){
        operations["subtract"]++;
        return a - b;
    }
    function multiply(uint256 a, uint256 b) public returns (uint256){
        operations["multiply"]++;
        return a * b;
    }
    function divide(uint256 a, uint256 b) public returns (uint256){
        operations["divide"]++;
        return a / b;
    }
}