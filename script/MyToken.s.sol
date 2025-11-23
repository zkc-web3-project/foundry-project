// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {MyToken} from "../src/MyToken.sol";

import "forge-std/console.sol";

contract MyTokenScript is Script {
    function setUp() public {}

    function run() public {
        // 获取私钥（在实际部署中从环境变量获取）
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // 部署合约
        MyToken token = new MyToken("My Token", "MTK", 1000000 * 10 ** 18);

        console.log("Token deployed at:", address(token));
        console.log("Deployer address:", msg.sender);

        vm.stopBroadcast();
    }
}
