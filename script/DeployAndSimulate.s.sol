// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/CallOptionToken.sol";
import "../src/MockUSDT.sol";
import "../src/OptionPool.sol";

/**
 * @title DeployAndSimulate
 * @notice 部署合约并模拟完整的期权生命周期
 */
contract DeployAndSimulate is Script {
    CallOptionToken public optionToken;
    MockUSDT public usdt;
    OptionPool public pool;

    // 配置参数
    uint256 public constant STRIKE_PRICE = 2000e18; // 执行价格：2000 USDT per ETH
    uint256 public constant PREMIUM_PRICE = 100e18; // 权利金：100 USDT per Option Token
    
    function run() external {
        // 获取私钥
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("=================================================");
        console.log("Deployer Address:", deployer);
        console.log("Deployer Balance:", deployer.balance / 1e18, "ETH");
        console.log("=================================================\n");

        vm.startBroadcast(deployerPrivateKey);

        // ========================================
        // 1. 部署合约
        // ========================================
        console.log("Step 1: Deploying Contracts...");
        
        optionToken = new CallOptionToken("ETH Call Option", "ETHCALL");
        console.log("  - CallOptionToken deployed at:", address(optionToken));
        
        usdt = new MockUSDT();
        console.log("  - MockUSDT deployed at:", address(usdt));
        
        pool = new OptionPool(address(optionToken), address(usdt));
        console.log("  - OptionPool deployed at:", address(pool));
        
        // 设置期权池为代币的铸造者
        optionToken.setOptionPool(address(pool));
        console.log("  - Option pool authorized to mint/burn tokens\n");

        // ========================================
        // 2. 配置期权参数
        // ========================================
        console.log("Step 2: Configuring Option Parameters...");
        
        uint256 expiryTime = block.timestamp + 7 days;
        pool.configureOption(STRIKE_PRICE, PREMIUM_PRICE, expiryTime);
        
        console.log("  - Strike Price:", STRIKE_PRICE / 1e18, "USDT per ETH");
        console.log("  - Premium Price:", PREMIUM_PRICE / 1e18, "USDT per Option Token");
        console.log("  - Expiry Time:", expiryTime);
        console.log("  - Current Time:", block.timestamp);
        console.log("  - Days Until Expiry: 7 days\n");

        // ========================================
        // 3. 项目方发行期权（质押 10 ETH）
        // ========================================
        console.log("Step 3: Issuing Options (Project deposits 10 ETH)...");
        
        uint256 issueAmount = 10 ether;
        pool.issueOptions{value: issueAmount}();
        
        console.log("  - ETH Deposited:", issueAmount / 1e18, "ETH");
        console.log("  - Option Tokens Minted:", optionToken.balanceOf(deployer) / 1e18);
        console.log("  - Pool ETH Balance:", address(pool).balance / 1e18, "ETH\n");

        vm.stopBroadcast();

        // ========================================
        // 4. 模拟用户操作（需要在 anvil 上）
        // ========================================
        console.log("Step 4: Simulating User Operations...");
        console.log("  Note: The following steps would be executed by users:\n");
        
        console.log("  4.1 User purchases options:");
        console.log("      - User approves USDT for premium payment");
        console.log("      - Project approves option tokens transfer");
        console.log("      - User calls purchaseOptions()");
        console.log("      - User receives option tokens\n");
        
        console.log("  4.2 Wait until expiry date (7 days)\n");
        
        console.log("  4.3 User exercises options (on expiry date):");
        console.log("      - User approves USDT for strike price payment");
        console.log("      - User calls exerciseOptions()");
        console.log("      - User pays", STRIKE_PRICE / 1e18, "USDT per option");
        console.log("      - User receives 1 ETH per option");
        console.log("      - Option tokens are burned\n");
        
        console.log("  4.4 After expiry (if options not exercised):");
        console.log("      - Project calls settleExpiredOptions()");
        console.log("      - Project retrieves remaining ETH");
        console.log("      - Unexercised options are settled\n");

        // 输出最终合约地址
        console.log("=================================================");
        console.log("Deployment Summary:");
        console.log("=================================================");
        console.log("CallOptionToken:", address(optionToken));
        console.log("MockUSDT:", address(usdt));
        console.log("OptionPool:", address(pool));
        console.log("=================================================\n");
    }
}

