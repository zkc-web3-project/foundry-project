
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


/**
这里以接口的形式暴露添加流动性、代币交换函数等实现在ShibaStyleToken中调用，更灵活，可以在不同版本之间来回切换，
前提是只要函数签名一致,相对于在ShibaStyleToken中通过abi来调用更灵活，实现解耦
IUniswapV2Factory同理
*/
interface IUniswapV2Router {
    
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    //添加流动性，函数签名必须与uniswapV2Router合约源码中的函数一致
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);

    //带手续费的代币交换，函数签名必须与uniswapV2Router合约源码中的函数一致
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}