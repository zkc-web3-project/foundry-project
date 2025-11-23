// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {Operation} from "../src/Operation.sol";

import "forge-std/console.sol";

contract OperationScript is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        // 部署合约
        Operation token = new Operation();

        console.log("my contract 'operation' is deployed at:", address(token));
        console.log("Deployer address:", msg.sender);

        vm.stopBroadcast();
    }
}
