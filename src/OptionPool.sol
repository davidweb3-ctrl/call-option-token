// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./CallOptionToken.sol";

/**
 * @title OptionPool
 * @notice 管理看涨期权的生命周期：发行、交易、行权、过期
 * @dev 项目方质押 ETH 发行期权，用户可以用 USDT 购买期权并在到期时行权
 */
contract OptionPool is Ownable, ReentrancyGuard {
    // 期权代币合约
    CallOptionToken public optionToken;
    
    // USDT 合约
    IERC20 public usdt;
    
    // 执行价格（USDT per ETH，18 位小数）
    uint256 public strikePrice;
    
    // 权利金价格（USDT per Option Token，18 位小数）
    uint256 public premiumPrice;
    
    // 到期时间
    uint256 public expiryTime;
    
    // 项目方质押的 ETH 总量
    uint256 public totalETHDeposited;
    
    // 已发行的期权代币总量
    uint256 public totalOptionsIssued;
    
    // 是否已过期并清算
    bool public isExpiredAndSettled;

    // 期权状态枚举
    enum OptionState {
        Active,      // 活跃期（可以购买）
        Exercisable, // 可行权期（到期日当天）
        Expired      // 已过期
    }

    // 事件
    event OptionConfigured(uint256 strikePrice, uint256 premiumPrice, uint256 expiryTime);
    event OptionsIssued(address indexed issuer, uint256 ethAmount, uint256 optionAmount);
    event OptionsPurchased(address indexed buyer, uint256 optionAmount, uint256 usdtAmount);
    event OptionsExercised(address indexed exerciser, uint256 optionAmount, uint256 ethAmount, uint256 usdtAmount);
    event ExpiredOptionsSettled(uint256 ethReturned, uint256 optionsBurned);

    constructor(
        address _optionToken,
        address _usdt
    ) Ownable(msg.sender) {
        require(_optionToken != address(0), "Invalid option token address");
        require(_usdt != address(0), "Invalid USDT address");
        
        optionToken = CallOptionToken(_optionToken);
        usdt = IERC20(_usdt);
    }

    /**
     * @notice 配置期权参数（只能在初始化时调用一次）
     * @param _strikePrice 执行价格（USDT per ETH）
     * @param _premiumPrice 权利金价格（USDT per Option Token）
     * @param _expiryTime 到期时间戳
     */
    function configureOption(
        uint256 _strikePrice,
        uint256 _premiumPrice,
        uint256 _expiryTime
    ) external onlyOwner {
        require(strikePrice == 0, "Option already configured");
        require(_strikePrice > 0, "Invalid strike price");
        require(_premiumPrice > 0, "Invalid premium price");
        require(_expiryTime > block.timestamp, "Expiry time must be in future");

        strikePrice = _strikePrice;
        premiumPrice = _premiumPrice;
        expiryTime = _expiryTime;

        emit OptionConfigured(_strikePrice, _premiumPrice, _expiryTime);
    }

    /**
     * @notice 获取当前期权状态
     */
    function getOptionState() public view returns (OptionState) {
        if (block.timestamp < expiryTime) {
            return OptionState.Active;
        } else if (block.timestamp >= expiryTime && block.timestamp < expiryTime + 1 days) {
            return OptionState.Exercisable;
        } else {
            return OptionState.Expired;
        }
    }

    /**
     * @notice 项目方发行期权代币（质押 ETH）
     * @dev 项目方转入 ETH，按 1:1 比例发行期权代币
     */
    function issueOptions() external payable onlyOwner nonReentrant {
        require(strikePrice > 0, "Option not configured");
        require(msg.value > 0, "Must deposit ETH");
        require(getOptionState() == OptionState.Active, "Can only issue when active");

        uint256 optionAmount = msg.value; // 1 ETH = 1 Option Token
        totalETHDeposited += msg.value;
        totalOptionsIssued += optionAmount;

        // 铸造期权代币给项目方
        optionToken.mint(owner(), optionAmount);

        emit OptionsIssued(msg.sender, msg.value, optionAmount);
    }

    /**
     * @notice 用户购买期权代币（支付权利金）
     * @param optionAmount 购买的期权代币数量
     * @dev 用户用 USDT 支付权利金，从项目方获取期权代币
     */
    function purchaseOptions(uint256 optionAmount) external nonReentrant {
        require(optionAmount > 0, "Invalid amount");
        require(getOptionState() == OptionState.Active, "Can only purchase when active");
        
        // 计算需要支付的 USDT（权利金）
        uint256 usdtAmount = (optionAmount * premiumPrice) / 1e18;
        require(usdtAmount > 0, "Invalid USDT amount");

        // 检查项目方是否有足够的期权代币
        require(optionToken.balanceOf(owner()) >= optionAmount, "Insufficient options available");

        // 用户支付 USDT 给项目方
        require(usdt.transferFrom(msg.sender, owner(), usdtAmount), "USDT transfer failed");

        // 项目方转移期权代币给用户
        require(optionToken.transferFrom(owner(), msg.sender, optionAmount), "Option token transfer failed");

        emit OptionsPurchased(msg.sender, optionAmount, usdtAmount);
    }

    /**
     * @notice 用户行权（到期日当天）
     * @param optionAmount 行权的期权代币数量
     * @dev 用户支付执行价格的 USDT，获得 ETH，期权代币被销毁
     */
    function exerciseOptions(uint256 optionAmount) external nonReentrant {
        require(optionAmount > 0, "Invalid amount");
        require(getOptionState() == OptionState.Exercisable, "Not in exercise period");
        require(optionToken.balanceOf(msg.sender) >= optionAmount, "Insufficient option tokens");

        // 计算需要支付的 USDT（执行价格）
        uint256 usdtAmount = (optionAmount * strikePrice) / 1e18;
        require(usdtAmount > 0, "Invalid USDT amount");

        // 计算可以获得的 ETH（1:1）
        uint256 ethAmount = optionAmount;
        require(address(this).balance >= ethAmount, "Insufficient ETH in pool");

        // 用户支付 USDT 给项目方
        require(usdt.transferFrom(msg.sender, owner(), usdtAmount), "USDT transfer failed");

        // 销毁用户的期权代币
        optionToken.burn(msg.sender, optionAmount);

        // 转 ETH 给用户
        (bool success, ) = msg.sender.call{value: ethAmount}("");
        require(success, "ETH transfer failed");

        emit OptionsExercised(msg.sender, optionAmount, ethAmount, usdtAmount);
    }

    /**
     * @notice 项目方清算过期期权（赎回未行权的 ETH）
     * @dev 过期后，项目方可以取回所有剩余的 ETH，销毁所有未行权的期权代币
     */
    function settleExpiredOptions() external onlyOwner nonReentrant {
        require(getOptionState() == OptionState.Expired, "Options not expired yet");
        require(!isExpiredAndSettled, "Already settled");

        isExpiredAndSettled = true;

        uint256 remainingETH = address(this).balance;
        uint256 remainingOptions = optionToken.totalSupply();

        // 如果还有未行权的期权代币，销毁它们
        if (remainingOptions > 0) {
            // 销毁项目方持有的期权代币
            uint256 ownerBalance = optionToken.balanceOf(owner());
            if (ownerBalance > 0) {
                optionToken.burn(owner(), ownerBalance);
            }
        }

        // 返还所有剩余 ETH 给项目方
        if (remainingETH > 0) {
            (bool success, ) = owner().call{value: remainingETH}("");
            require(success, "ETH transfer failed");
        }

        emit ExpiredOptionsSettled(remainingETH, remainingOptions);
    }

    /**
     * @notice 获取合约信息
     */
    function getPoolInfo() external view returns (
        uint256 _strikePrice,
        uint256 _premiumPrice,
        uint256 _expiryTime,
        uint256 _totalETHDeposited,
        uint256 _totalOptionsIssued,
        uint256 _remainingETH,
        uint256 _remainingOptions,
        OptionState _state
    ) {
        return (
            strikePrice,
            premiumPrice,
            expiryTime,
            totalETHDeposited,
            totalOptionsIssued,
            address(this).balance,
            optionToken.totalSupply(),
            getOptionState()
        );
    }

    // 接收 ETH
    receive() external payable {}
}

