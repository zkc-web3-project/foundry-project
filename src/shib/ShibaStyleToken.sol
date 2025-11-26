
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IUniswapV2Router.sol";
import "./IUniswapV2Factory.sol";

contract ShibaStyleToken {
    //代币名
    string public constant name = "ShibaStyleToken";
    //代币符号
    string public constant symbol = "SST";
    //代币精度
    uint8 public constant decimals = 18;
    //代币总量
    uint256 public constant totalSupply = 1_000_000_000 * 10**decimals; // 10亿代币
    
    //账户余额映射
    mapping(address => uint256) private _balances;
    //授权映射
    mapping(address => mapping(address => uint256)) private _allowances;
    //标记哪些地址免除交易费用，为true则表示该地址在进行代币转移时不收取任何税费
    mapping(address => bool) public isExcludedFromFee;
    //标记哪些地址免受交易限制约束
    mapping(address => bool) public isExcludedFromLimit;
    //记录每个地址的最后交易时间
    mapping(address => uint256) public lastTradeTime;
    //记录每个地址的每天交易金额
    mapping(address => uint256) public dailyTradedAmount;

    //合约所有者地址
    address public owner;
    //税费收入的接受钱包地址(接收交易税费收益)
    address public taxWallet;
    //流动性资金的接收钱包地址(接收流动性资金)
    address public liquidityWallet;
    //uniswap交易对合约地址
    address public uniswapPair;
    
    //uniswap V2 路由器接口实例    sepolia-0xeE567Fe1712Faf6149d80dA1E6934E354124CfE3
    IUniswapV2Router public uniswapRouter;
    
    //买入税率
    uint256 public buyTax = 300; // 3%
    //卖出税率
    uint256 public sellTax = 500; // 5%
    //转账税率
    uint256 public transferTax = 100; // 1%
    
    //单笔交易的最大金额限制
    uint256 public maxTxAmount = totalSupply / 100; // 总量的1%
    //单日累计交易金额的最大限制
    uint256 public maxDailyAmount = totalSupply / 50; // 总量的2%
    //连续交易的最小间隔时间
    uint256 public tradeCooldown = 30 minutes; // 交易冷却时间
    
    //累计收益的税费总额(达到阈值时自动分配)
    uint256 private taxCollected;
    //标记是否正在进行swap操作，用于防止重入攻击
    bool private inSwap;
    
    //普通转账事件
    event Transfer(address indexed from, address indexed to, uint256 value);
    //授权事件
    event Approval(address indexed owner, address indexed spender, uint256 value);
    /** 
      税费分配事件
      liquidityAmount: 流动性adding的代币数量
      taxWalletAmount: 发送到税务钱包的代币数量
     */
    event TaxesDistributed(uint256 liquidityAmount, uint256 taxWalletAmount);

    /** 
      流动性添加事件
      tokenAmount: 添加到流动性池的代币数量
      ethAmount: 添加到流动性池的ETH数量
      liquidity: 生成的流动性代币数量
     */
    event LiquidityAdded(uint256 tokenAmount, uint256 ethAmount, uint256 liquidity);
    
    //修饰符号，只有创建者可以调用
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    //修饰符，在函数执行期间锁定swap操作，防止重入攻击
    modifier lockTheSwap() {
        inSwap = true;
        _;
        inSwap = false;
    }
    
    //构造函数，创建代币并初始化参数
    constructor(address _router) {
        owner = msg.sender;
        taxWallet = msg.sender;
        liquidityWallet = msg.sender;
        
        //将全部代币余额分配给部署者
        _balances[msg.sender] = totalSupply;
        //从零地址创建代币给部署者
        emit Transfer(address(0), msg.sender, totalSupply);
        
        //传入uniswap 路由器地址
        uniswapRouter = IUniswapV2Router(_router);
        //通过路由器获取工厂合约地址并创建本代币与ETH的代币对
        uniswapPair = IUniswapV2Factory(uniswapRouter.factory()).createPair(
            address(this), //当前代币SST
            uniswapRouter.WETH() //ETH代币
        );
        
        //以下为部署这的特权，免手续费、交易限制等
        isExcludedFromFee[owner] = true;
        isExcludedFromFee[address(this)] = true;
        isExcludedFromFee[taxWallet] = true;
        
        isExcludedFromLimit[owner] = true;
        isExcludedFromLimit[address(this)] = true;
    }

    //获取账户余额
    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }
    
    //代币转账
    function transfer(address recipient, uint256 amount) public returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }
    
    //授权转账
    function transferFrom(address sender, address recipient, uint256 amount) public returns (bool) {
        _transfer(sender, recipient, amount);
        //减少sender对调用者的授权额度，更新授权额度映射关系，这里的sender是代币的拥有者
        _approve(sender, msg.sender, _allowances[sender][msg.sender] - amount);
        return true;
    }
    
    //授权
    function approve(address spender, uint256 amount) public returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }
    
    //查询授权额度
    function allowance(address _owner, address spender) public view returns (uint256) {
        return _allowances[_owner][spender];
    }
    
    //内部转账函数
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
            //所有DEX交易都必须经过uniswapPair合约，只要sender或recipient是这个地址，就可确定是DEX交易
            //买入：sender 是 uniswapPair → 代币从 DEX 发出
            //卖出：recipient 是 uniswapPair → 代币进入 DEX
            if (sender == uniswapPair) { // 购买交易
                taxAmount = (amount * buyTax) / 10000;
            } else if (recipient == uniswapPair) { // 出售交易
                taxAmount = (amount * sellTax) / 10000;
                
                // 自动执行流动性添加和税费分配
                if (!inSwap && taxCollected > totalSupply / 1000) { // 当税费积累到总量的0.1%时执行
                    //执行税费分配
                    _distributeTaxes();
                }
            } else { // 普通转账
                taxAmount = (amount * transferTax) / 10000;
            }
            
            if (taxAmount > 0) {
                //如果有税费产生，则计算实际转账金额(原金额-税额)
                transferAmount = amount - taxAmount;
                //将税费添加到合约地址的余额中
                _balances[address(this)] += taxAmount;
                //累计税费
                taxCollected += taxAmount;
                //触发转账事件(税费转账到当前合约)
                emit Transfer(sender, address(this), taxAmount);
            }
        }
        //更新转账方余额
        _balances[sender] -= amount;
        //更新接收方余额
        _balances[recipient] += transferAmount;
        //触发转账事件(实际转账)
        emit Transfer(sender, recipient, transferAmount);
    }
    
    //执行税费分配(当达到代币总供应量的0.1%时执行)
    function _distributeTaxes() internal lockTheSwap {
        uint256 totalTax = taxCollected;
        if (totalTax == 0) return;
        
        // 50% 的税费添加到流动性池(一半用于增加流动性，一半作为项目方收益)
        uint256 liquidityAmount = totalTax / 2;
        // 50% 的税费发送到税费钱包 即项目方收益
        uint256 taxWalletAmount = totalTax - liquidityAmount;
        
        // 交换代币为 ETH 用于添加流动性
        //调用前合约的余额
        uint256 initialETHBalance = address(this).balance;
        //使用liquidityAmount数量的SST通过uniswap路由器兑换为ETH
        _swapTokensForETH(liquidityAmount);
        //计算出此次兑换获得的ETH数量(新余额-初始余额)
        uint256 newETHBalance = address(this).balance - initialETHBalance;
        
        // 添加流动性
        if (newETHBalance > 0) {
            _addLiquidity(liquidityAmount, newETHBalance);
        }
        
        // 剩余 ETH 发送到税费钱包(可能由于滑点导致还有剩余的ETH)
        if (address(this).balance > initialETHBalance) {
            payable(taxWallet).transfer(address(this).balance - initialETHBalance);
        }
        //重置税费累计
        taxCollected = 0;
        //触发税费分配事件
        emit TaxesDistributed(liquidityAmount, taxWalletAmount);
    }
    
    //使用代币(SST)兑换ETH
    function _swapTokensForETH(uint256 tokenAmount) internal {
        //指定代币交换路径[BTC,ETH] ,在uniswapRouter v2中，表示从BTC兑换为ETH,Uniswap V2 使用 WETH（而不是原生 ETH）进行交易,所以需先将ETH包装成WETH
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapRouter.WETH();
        
        //需提前授权才能执行swap操作
        _approve(address(this), address(uniswapRouter), tokenAmount);
        
        uniswapRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount, //代币数量
            0,  //最小输出 ETH 数量（0 表示无最低要求）
            path, //交易路径 [SST, WETH]
            address(this), //收益接收地址
            block.timestamp //交易截止时间（防止过期）
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