// script/DeployShibaStyleToken.s.sol
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/shib/ShibaStyleToken.sol";

contract DeployShibaStyleToken is Script {
    function run() public {
        //开始广播，启用交易模式(vm为foundry提供的虚拟机工具)
        vm.startBroadcast();

        address router = 0x0eE567Fe1712Faf6149d80dA1E6934E354124CfE3; // Sepolia Uniswap V2 Router

        ShibaStyleToken token = new ShibaStyleToken{value: 0}(router); //{value: 0} 表示不附带ETH

        console.log("ShibaStyleToken deployed to:", address(token));
        console.log("Owner:", token.owner());
        console.log("Tax Wallet:", token.taxWallet()); //项目方收益地址
        console.log("Liquidity Wallet:", token.liquidityWallet());  //流动性资金接收钱包地址
        console.log("Uniswap Pair:", token.uniswapPair());  //由UniswapRouter.factory().createPair()创建的合约地址

        vm.stopBroadcast();
    }
}