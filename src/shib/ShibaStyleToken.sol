
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IUniswapV2Router.sol";
import "./IUniswapV2Factory.sol";

contract ShibaStyleToken {
    string public constant name = "ShibaStyleToken";
    string public constant symbol = "SST";
    uint8 public constant decimals = 18;
    uint256 public constant totalSupply = 1_000_000_000 * 10**decimals; // 10亿代币
    
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) public isExcludedFromFee;
    mapping(address => bool) public isExcludedFromLimit;
    mapping(address => uint256) public lastTradeTime;
    mapping(address => uint256) public dailyTradedAmount;
    
    address public owner;
    address public taxWallet;
    address public liquidityWallet;
    address public uniswapPair;

    IUniswapV2Router public uniswapRouter;
    
    uint256 public buyTax = 300; // 3%
    uint256 public sellTax = 500; // 5%
    uint256 public transferTax = 100; // 1%
    
    uint256 public maxTxAmount = totalSupply / 100; // 总量的1%
    uint256 public maxDailyAmount = totalSupply / 50; // 总量的2%
    uint256 public tradeCooldown = 30 minutes; // 交易冷却时间
    
    uint256 private taxCollected;
    bool private inSwap;
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event TaxesDistributed(uint256 liquidityAmount, uint256 taxWalletAmount);
    event LiquidityAdded(uint256 tokenAmount, uint256 ethAmount, uint256 liquidity);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier lockTheSwap() {
        inSwap = true;
        _;
        inSwap = false;
    }
    
    constructor(address _router) {
        owner = msg.sender;
        taxWallet = msg.sender;
        liquidityWallet = msg.sender;
        
        _balances[msg.sender] = totalSupply;
        emit Transfer(address(0), msg.sender, totalSupply);
        
        uniswapRouter = IUniswapV2Router(_router);
        uniswapPair = IUniswapV2Factory(uniswapRouter.factory()).createPair(
            address(this),
            uniswapRouter.WETH()
        );
        
        isExcludedFromFee[owner] = true;
        isExcludedFromFee[address(this)] = true;
        isExcludedFromFee[taxWallet] = true;
        
        isExcludedFromLimit[owner] = true;
        isExcludedFromLimit[address(this)] = true;
    }
    
    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }
    
    function transfer(address recipient, uint256 amount) public returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }
    
    function transferFrom(address sender, address recipient, uint256 amount) public returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, msg.sender, _allowances[sender][msg.sender] - amount);
        return true;
    }
    
    function approve(address spender, uint256 amount) public returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }
    
    function allowance(address _owner, address spender) public view returns (uint256) {
        return _allowances[_owner][spender];
    }
    
    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "Transfer from zero address");
        require(recipient != address(0), "Transfer to zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        
        // 检查交易限制（排除特定地址）
        if (!isExcludedFromLimit[sender] && !isExcludedFromLimit[recipient]) {
            require(amount <= maxTxAmount, "Exceeds maximum transaction amount");
            
            // 检查每日交易限额
            uint256 currentDay = block.timestamp / 1 days;
            if (lastTradeTime[sender] != currentDay) {
                lastTradeTime[sender] = currentDay;
                dailyTradedAmount[sender] = 0;
            }
            require(dailyTradedAmount[sender] + amount <= maxDailyAmount, "Exceeds daily trading limit");
            dailyTradedAmount[sender] += amount;
            
            // 检查交易冷却时间
            require(block.timestamp >= lastTradeTime[sender] + tradeCooldown, "Trade cooldown not met");
        }
        
        uint256 transferAmount = amount;
        uint256 taxAmount = 0;
        
        // 只在买卖交易时收税，排除特定地址
        if (!isExcludedFromFee[sender] && !isExcludedFromFee[recipient]) {
            if (sender == uniswapPair) { // 购买交易
                taxAmount = (amount * buyTax) / 10000;
            } else if (recipient == uniswapPair) { // 出售交易
                taxAmount = (amount * sellTax) / 10000;
                
                // 自动执行流动性添加和税费分配
                if (!inSwap && taxCollected > totalSupply / 1000) { // 当税费积累到总量的0.1%时执行
                    _distributeTaxes();
                }
            } else { // 普通转账
                taxAmount = (amount * transferTax) / 10000;
            }
            
            if (taxAmount > 0) {
                transferAmount = amount - taxAmount;
                _balances[address(this)] += taxAmount;
                taxCollected += taxAmount;
                emit Transfer(sender, address(this), taxAmount);
            }
        }
        
        _balances[sender] -= amount;
        _balances[recipient] += transferAmount;
        
        emit Transfer(sender, recipient, transferAmount);
    }
    
    function _distributeTaxes() internal lockTheSwap {
        uint256 totalTax = taxCollected;
        if (totalTax == 0) return;
        
        // 50% 的税费添加到流动性池
        uint256 liquidityAmount = totalTax / 2;
        uint256 taxWalletAmount = totalTax - liquidityAmount;
        
        // 交换代币为 ETH 用于添加流动性
        uint256 initialETHBalance = address(this).balance;
        _swapTokensForETH(liquidityAmount);
        uint256 newETHBalance = address(this).balance - initialETHBalance;
        
        // 添加流动性
        if (newETHBalance > 0) {
            _addLiquidity(liquidityAmount, newETHBalance);
        }
        
        // 剩余 ETH 发送到税费钱包
        if (address(this).balance > initialETHBalance) {
            payable(taxWallet).transfer(address(this).balance - initialETHBalance);
        }
        
        taxCollected = 0;
        emit TaxesDistributed(liquidityAmount, taxWalletAmount);
    }
    
    function _swapTokensForETH(uint256 tokenAmount) internal {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapRouter.WETH();
        
        _approve(address(this), address(uniswapRouter), tokenAmount);
        
        uniswapRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }
    
    function _addLiquidity(uint256 tokenAmount, uint256 ethAmount) internal {
        _approve(address(this), address(uniswapRouter), tokenAmount);
        
        uniswapRouter.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0,
            0,
            liquidityWallet,
            block.timestamp
        );
        
        emit LiquidityAdded(tokenAmount, ethAmount, 0);
    }
    
    function _approve(address _owner, address spender, uint256 amount) internal {
        require(_owner != address(0), "Approve from zero address");
        require(spender != address(0), "Approve to zero address");
        
        _allowances[_owner][spender] = amount;
        emit Approval(_owner, spender, amount);
    }
    
    // 所有者功能：更新税费设置
    function updateTaxes(uint256 _buyTax, uint256 _sellTax, uint256 _transferTax) external onlyOwner {
        require(_buyTax <= 1000, "Buy tax too high"); // 最大10%
        require(_sellTax <= 1000, "Sell tax too high"); // 最大10%
        require(_transferTax <= 500, "Transfer tax too high"); // 最大5%
        
        buyTax = _buyTax;
        sellTax = _sellTax;
        transferTax = _transferTax;
    }
    
    // 所有者功能：更新交易限制
    function updateLimits(uint256 _maxTxAmount, uint256 _maxDailyAmount, uint256 _tradeCooldown) external onlyOwner {
        require(_maxTxAmount >= totalSupply / 1000, "Max tx amount too low"); // 最小0.1%
        require(_maxDailyAmount >= totalSupply / 500, "Max daily amount too low"); // 最小0.2%
        require(_tradeCooldown <= 24 hours, "Cooldown too long"); // 最长24小时
        
        maxTxAmount = _maxTxAmount;
        maxDailyAmount = _maxDailyAmount;
        tradeCooldown = _tradeCooldown;
    }
    
    // 所有者功能：排除地址 from 费用/限制
    function excludeAddress(address account, bool fromFee, bool fromLimit) external onlyOwner {
        if (fromFee) {
            isExcludedFromFee[account] = true;
        }
        if (fromLimit) {
            isExcludedFromLimit[account] = true;
        }
    }
    
    // 提取意外发送的 ETH
    function withdrawStuckETH() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }
    
    // 提取意外发送的代币
    function withdrawStuckTokens(address tokenAddress) external onlyOwner {
        IERC20 token = IERC20(tokenAddress);
        uint256 balance = token.balanceOf(address(this));
        token.transfer(owner, balance);
    }
    
    receive() external payable {}
}

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
}