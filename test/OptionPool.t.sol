// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/CallOptionToken.sol";
import "../src/MockUSDT.sol";
import "../src/OptionPool.sol";

/**
 * @title OptionPoolTest
 * @notice 完整的期权池测试用例
 */
contract OptionPoolTest is Test {
    CallOptionToken public optionToken;
    MockUSDT public usdt;
    OptionPool public pool;

    address public owner = address(1);
    address public user1 = address(2);
    address public user2 = address(3);

    uint256 public constant STRIKE_PRICE = 2000e18; // 2000 USDT per ETH
    uint256 public constant PREMIUM_PRICE = 100e18; // 100 USDT per Option Token
    uint256 public expiryTime;

    event OptionConfigured(uint256 strikePrice, uint256 premiumPrice, uint256 expiryTime);
    event OptionsIssued(address indexed issuer, uint256 ethAmount, uint256 optionAmount);
    event OptionsPurchased(address indexed buyer, uint256 optionAmount, uint256 usdtAmount);
    event OptionsExercised(address indexed exerciser, uint256 optionAmount, uint256 ethAmount, uint256 usdtAmount);
    event ExpiredOptionsSettled(uint256 ethReturned, uint256 optionsBurned);

    function setUp() public {
        // 设置到期时间为 7 天后
        expiryTime = block.timestamp + 7 days;

        // 部署合约
        vm.startPrank(owner);
        optionToken = new CallOptionToken("ETH Call Option", "ETHCALL");
        usdt = new MockUSDT();
        pool = new OptionPool(address(optionToken), address(usdt));
        
        // 设置期权池为代币的铸造者
        optionToken.setOptionPool(address(pool));
        
        // 配置期权参数
        pool.configureOption(STRIKE_PRICE, PREMIUM_PRICE, expiryTime);
        vm.stopPrank();

        // 给用户一些 USDT 用于测试
        usdt.mintTo(user1, 1000000e18);
        usdt.mintTo(user2, 1000000e18);

        // 给用户一些 ETH
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
        vm.deal(owner, 100 ether);
    }

    function testConfigureOption() public {
        // 验证配置是否正确
        (
            uint256 strikePrice,
            uint256 premiumPrice,
            uint256 _expiryTime,
            ,
            ,
            ,
            ,
            
        ) = pool.getPoolInfo();

        assertEq(strikePrice, STRIKE_PRICE);
        assertEq(premiumPrice, PREMIUM_PRICE);
        assertEq(_expiryTime, expiryTime);
    }

    function testIssueOptions() public {
        vm.startPrank(owner);
        
        uint256 ethAmount = 10 ether;
        
        // 期望发出事件
        vm.expectEmit(true, true, true, true);
        emit OptionsIssued(owner, ethAmount, ethAmount);
        
        // 发行期权
        pool.issueOptions{value: ethAmount}();
        
        // 验证
        assertEq(optionToken.balanceOf(owner), ethAmount);
        assertEq(address(pool).balance, ethAmount);
        
        vm.stopPrank();
    }

    function testPurchaseOptions() public {
        // 先由项目方发行期权
        vm.prank(owner);
        pool.issueOptions{value: 10 ether}();

        // 用户购买期权
        vm.startPrank(user1);
        
        uint256 optionAmount = 5 ether;
        uint256 expectedUSDT = (optionAmount * PREMIUM_PRICE) / 1e18;
        
        // 授权 USDT
        usdt.approve(address(pool), expectedUSDT);
        
        // 授权期权代币转移
        vm.stopPrank();
        vm.prank(owner);
        optionToken.approve(address(pool), optionAmount);
        
        vm.startPrank(user1);
        
        // 期望发出事件
        vm.expectEmit(true, true, true, true);
        emit OptionsPurchased(user1, optionAmount, expectedUSDT);
        
        // 购买期权
        pool.purchaseOptions(optionAmount);
        
        // 验证
        assertEq(optionToken.balanceOf(user1), optionAmount);
        assertEq(usdt.balanceOf(owner), 1000000e18 + expectedUSDT);
        
        vm.stopPrank();
    }

    function testExerciseOptions() public {
        // 项目方发行期权
        vm.prank(owner);
        pool.issueOptions{value: 10 ether}();

        // 用户购买期权
        vm.startPrank(user1);
        uint256 optionAmount = 5 ether;
        uint256 premiumUSDT = (optionAmount * PREMIUM_PRICE) / 1e18;
        usdt.approve(address(pool), premiumUSDT);
        vm.stopPrank();
        
        vm.prank(owner);
        optionToken.approve(address(pool), optionAmount);
        
        vm.prank(user1);
        pool.purchaseOptions(optionAmount);

        // 时间快进到到期日
        vm.warp(expiryTime);

        // 用户行权
        vm.startPrank(user1);
        
        uint256 strikeUSDT = (optionAmount * STRIKE_PRICE) / 1e18;
        usdt.approve(address(pool), strikeUSDT);
        
        uint256 userETHBefore = user1.balance;
        
        // 期望发出事件
        vm.expectEmit(true, true, true, true);
        emit OptionsExercised(user1, optionAmount, optionAmount, strikeUSDT);
        
        // 行权
        pool.exerciseOptions(optionAmount);
        
        // 验证
        assertEq(user1.balance, userETHBefore + optionAmount);
        assertEq(optionToken.balanceOf(user1), 0);
        assertEq(usdt.balanceOf(owner), 1000000e18 + premiumUSDT + strikeUSDT);
        
        vm.stopPrank();
    }

    function testSettleExpiredOptions() public {
        // 项目方发行期权
        vm.prank(owner);
        pool.issueOptions{value: 10 ether}();

        // 用户购买部分期权
        vm.startPrank(user1);
        uint256 optionAmount = 3 ether;
        usdt.approve(address(pool), (optionAmount * PREMIUM_PRICE) / 1e18);
        vm.stopPrank();
        
        vm.prank(owner);
        optionToken.approve(address(pool), optionAmount);
        
        vm.prank(user1);
        pool.purchaseOptions(optionAmount);

        // 时间快进到过期后
        vm.warp(expiryTime + 2 days);

        // 项目方清算
        vm.startPrank(owner);
        
        uint256 ownerETHBefore = owner.balance;
        uint256 remainingETH = address(pool).balance;
        
        // 清算
        pool.settleExpiredOptions();
        
        // 验证项目方收回了所有剩余的 ETH
        assertEq(owner.balance, ownerETHBefore + remainingETH);
        assertEq(address(pool).balance, 0);
        
        vm.stopPrank();
    }

    function testCannotExerciseBeforeExpiry() public {
        // 项目方发行期权
        vm.prank(owner);
        pool.issueOptions{value: 10 ether}();

        // 用户购买期权
        vm.startPrank(user1);
        uint256 optionAmount = 5 ether;
        usdt.approve(address(pool), (optionAmount * PREMIUM_PRICE) / 1e18);
        vm.stopPrank();
        
        vm.prank(owner);
        optionToken.approve(address(pool), optionAmount);
        
        vm.prank(user1);
        pool.purchaseOptions(optionAmount);

        // 尝试在到期前行权（应该失败）
        vm.startPrank(user1);
        usdt.approve(address(pool), (optionAmount * STRIKE_PRICE) / 1e18);
        
        vm.expectRevert("Not in exercise period");
        pool.exerciseOptions(optionAmount);
        
        vm.stopPrank();
    }

    function testCannotPurchaseAfterExpiry() public {
        // 项目方发行期权
        vm.prank(owner);
        pool.issueOptions{value: 10 ether}();

        // 时间快进到到期后
        vm.warp(expiryTime + 1 days);

        // 尝试购买期权（应该失败）
        vm.startPrank(user1);
        uint256 optionAmount = 5 ether;
        usdt.approve(address(pool), (optionAmount * PREMIUM_PRICE) / 1e18);
        
        vm.stopPrank();
        vm.prank(owner);
        optionToken.approve(address(pool), optionAmount);
        
        vm.prank(user1);
        vm.expectRevert("Can only purchase when active");
        pool.purchaseOptions(optionAmount);
        
        vm.stopPrank();
    }

    function testMultipleUsersScenario() public {
        // 项目方发行 20 ETH 的期权
        vm.prank(owner);
        pool.issueOptions{value: 20 ether}();

        // User1 购买 8 ETH 的期权
        vm.startPrank(user1);
        uint256 user1Options = 8 ether;
        usdt.approve(address(pool), (user1Options * PREMIUM_PRICE) / 1e18);
        vm.stopPrank();
        
        vm.prank(owner);
        optionToken.approve(address(pool), user1Options);
        
        vm.prank(user1);
        pool.purchaseOptions(user1Options);

        // User2 购买 5 ETH 的期权
        vm.startPrank(user2);
        uint256 user2Options = 5 ether;
        usdt.approve(address(pool), (user2Options * PREMIUM_PRICE) / 1e18);
        vm.stopPrank();
        
        vm.prank(owner);
        optionToken.approve(address(pool), user2Options);
        
        vm.prank(user2);
        pool.purchaseOptions(user2Options);

        // 验证余额
        assertEq(optionToken.balanceOf(user1), user1Options);
        assertEq(optionToken.balanceOf(user2), user2Options);
        assertEq(optionToken.balanceOf(owner), 20 ether - user1Options - user2Options);

        // 时间快进到到期日
        vm.warp(expiryTime);

        // User1 行权 5 ETH
        vm.startPrank(user1);
        uint256 user1Exercise = 5 ether;
        usdt.approve(address(pool), (user1Exercise * STRIKE_PRICE) / 1e18);
        pool.exerciseOptions(user1Exercise);
        vm.stopPrank();

        // User2 行权全部
        vm.startPrank(user2);
        usdt.approve(address(pool), (user2Options * STRIKE_PRICE) / 1e18);
        pool.exerciseOptions(user2Options);
        vm.stopPrank();

        // 验证行权后的余额
        assertEq(optionToken.balanceOf(user1), user1Options - user1Exercise);
        assertEq(optionToken.balanceOf(user2), 0);

        // 时间快进到过期后
        vm.warp(expiryTime + 2 days);

        // 项目方清算剩余 ETH
        vm.prank(owner);
        pool.settleExpiredOptions();

        // 验证最终状态
        assertEq(address(pool).balance, 0);
    }

    function testGetPoolInfo() public {
        vm.prank(owner);
        pool.issueOptions{value: 10 ether}();

        (
            uint256 strikePrice,
            uint256 premiumPrice,
            uint256 _expiryTime,
            uint256 totalETHDeposited,
            uint256 totalOptionsIssued,
            uint256 remainingETH,
            uint256 remainingOptions,
            OptionPool.OptionState state
        ) = pool.getPoolInfo();

        assertEq(strikePrice, STRIKE_PRICE);
        assertEq(premiumPrice, PREMIUM_PRICE);
        assertEq(_expiryTime, expiryTime);
        assertEq(totalETHDeposited, 10 ether);
        assertEq(totalOptionsIssued, 10 ether);
        assertEq(remainingETH, 10 ether);
        assertEq(remainingOptions, 10 ether);
        assertEq(uint(state), uint(OptionPool.OptionState.Active));
    }
}

