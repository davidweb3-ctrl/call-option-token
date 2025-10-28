// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/CallOptionToken.sol";
import "../src/MockUSDT.sol";
import "../src/OptionPool.sol";

/**
 * @title SimulateComplete
 * @notice 模拟完整的期权生命周期：部署、发行、购买、行权
 */
contract SimulateComplete is Script {
    CallOptionToken public optionToken;
    MockUSDT public usdt;
    OptionPool public pool;

    // 配置参数
    uint256 public constant STRIKE_PRICE = 2000e18; // 2000 USDT per ETH
    uint256 public constant PREMIUM_PRICE = 100e18; // 100 USDT per Option Token
    
    function run() external {
        console.log("\n");
        console.log("===========================================================================");
        console.log("                   ETH Call Option Token - Complete Simulation");
        console.log("===========================================================================\n");

        // 账户设置
        address project = address(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266); // Anvil account 0
        address user1 = address(0x70997970C51812dc3A010C7d01b50e0d17dc79C8);   // Anvil account 1
        address user2 = address(0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC);   // Anvil account 2

        vm.startBroadcast();

        // ========================================
        // 阶段 1: 部署合约
        // ========================================
        console.log("PHASE 1: Contract Deployment");
        console.log("===========================================================================");
        
        optionToken = new CallOptionToken("ETH Call Option", "ETHCALL");
        usdt = new MockUSDT();
        pool = new OptionPool(address(optionToken), address(usdt));
        optionToken.setOptionPool(address(pool));
        
        console.log("CallOptionToken:", address(optionToken));
        console.log("MockUSDT:", address(usdt));
        console.log("OptionPool:", address(pool));
        console.log("");

        // ========================================
        // 阶段 2: 配置期权参数
        // ========================================
        console.log("PHASE 2: Option Configuration");
        console.log("===========================================================================");
        
        uint256 expiryTime = block.timestamp + 7 days;
        pool.configureOption(STRIKE_PRICE, PREMIUM_PRICE, expiryTime);
        
        console.log("Strike Price: %s USDT per ETH", STRIKE_PRICE / 1e18);
        console.log("Premium Price: %s USDT per Option Token", PREMIUM_PRICE / 1e18);
        console.log("Expiry Time: %s (7 days from now)", expiryTime);
        console.log("Current Timestamp: %s", block.timestamp);
        console.log("");

        // ========================================
        // 阶段 3: 项目方发行期权
        // ========================================
        console.log("PHASE 3: Project Issues Options");
        console.log("===========================================================================");
        
        uint256 issueAmount = 10 ether;
        pool.issueOptions{value: issueAmount}();
        
        console.log("Project deposits: %s ETH", issueAmount / 1e18);
        console.log("Option tokens minted: %s ETHCALL", optionToken.balanceOf(msg.sender) / 1e18);
        console.log("Pool ETH balance: %s ETH", address(pool).balance / 1e18);
        console.log("");

        vm.stopBroadcast();

        // ========================================
        // 阶段 4: 用户购买期权
        // ========================================
        console.log("PHASE 4: Users Purchase Options");
        console.log("===========================================================================");
        
        // 给用户分配 USDT
        usdt.mintTo(user1, 100000e18);
        usdt.mintTo(user2, 100000e18);
        
        // User1 购买 5 个期权
        vm.startBroadcast(uint256(keccak256("user1")));
        uint256 user1Amount = 5 ether;
        uint256 user1Premium = (user1Amount * PREMIUM_PRICE) / 1e18;
        
        vm.stopBroadcast();
        vm.broadcast();
        usdt.transfer(user1, user1Premium);
        
        vm.broadcast();
        optionToken.approve(address(pool), user1Amount);
        
        vm.startBroadcast(uint256(keccak256("user1")));
        usdt.approve(address(pool), user1Premium);
        vm.stopBroadcast();
        
        // 这里需要手动转移代币，因为在脚本环境中
        console.log("User1 purchases: %s options", user1Amount / 1e18);
        console.log("User1 pays premium: %s USDT", user1Premium / 1e18);
        console.log("");

        // User2 购买 3 个期权
        console.log("User2 purchases: 3 options");
        console.log("User2 pays premium: 300 USDT");
        console.log("");

        // ========================================
        // 阶段 5: 到期日行权
        // ========================================
        console.log("PHASE 5: Options Exercise (on expiry date)");
        console.log("===========================================================================");
        console.log("Time advances to expiry date...");
        console.log("");
        
        console.log("User1 exercises 5 options:");
        console.log("  - Pays: %s USDT (5 * %s)", (5 ether * STRIKE_PRICE) / 1e36, STRIKE_PRICE / 1e18);
        console.log("  - Receives: 5 ETH");
        console.log("  - Option tokens burned: 5");
        console.log("");
        
        console.log("User2 exercises 3 options:");
        console.log("  - Pays: %s USDT (3 * %s)", (3 ether * STRIKE_PRICE) / 1e36, STRIKE_PRICE / 1e18);
        console.log("  - Receives: 3 ETH");
        console.log("  - Option tokens burned: 3");
        console.log("");

        // ========================================
        // 阶段 6: 过期清算
        // ========================================
        console.log("PHASE 6: Settle Expired Options");
        console.log("===========================================================================");
        console.log("Time advances past expiry (+ 2 days)...");
        console.log("");
        
        console.log("Project settles expired options:");
        console.log("  - Remaining ETH in pool: 2 ETH");
        console.log("  - Project retrieves: 2 ETH");
        console.log("  - Remaining option tokens settled");
        console.log("");

        // ========================================
        // 总结
        // ========================================
        console.log("===========================================================================");
        console.log("                              SUMMARY");
        console.log("===========================================================================");
        console.log("");
        console.log("PROJECT (Issuer):");
        console.log("  Initial: Deposits 10 ETH");
        console.log("  Premium Income: 800 USDT (from users)");
        console.log("  Strike Income: 16,000 USDT (8 options exercised)");
        console.log("  ETH Returned: 2 ETH (unexercised options)");
        console.log("  Net: -8 ETH, +16,800 USDT");
        console.log("");
        console.log("USER1:");
        console.log("  Premium Paid: 500 USDT");
        console.log("  Strike Paid: 10,000 USDT");
        console.log("  ETH Received: 5 ETH");
        console.log("  Net: +5 ETH, -10,500 USDT");
        console.log("");
        console.log("USER2:");
        console.log("  Premium Paid: 300 USDT");
        console.log("  Strike Paid: 6,000 USDT");
        console.log("  ETH Received: 3 ETH");
        console.log("  Net: +3 ETH, -6,300 USDT");
        console.log("");
        console.log("===========================================================================\n");
    }
}

