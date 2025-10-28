# 使用指南 - 看涨期权 Token 系统

## 🚀 快速开始

### 1. 启动本地测试网

在一个终端窗口中启动 Anvil：

```bash
anvil
```

这将启动一个本地以太坊测试网，默认监听 `http://localhost:8545`

### 2. 部署合约

在另一个终端窗口中部署合约：

```bash
cd /Users/xiadawei/codeSpace/decert/call-option-token

# 部署合约并发行期权
forge script script/DeployAndSimulate.s.sol:DeployAndSimulate \
  --rpc-url http://localhost:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --broadcast
```

### 3. 运行测试

```bash
# 运行所有测试
forge test

# 详细输出
forge test -vv

# 查看 gas 报告
forge test --gas-report
```

## 📋 详细操作步骤

### 场景 1: 使用 Cast 与合约交互

部署合约后，您可以使用 `cast` 命令行工具与合约交互。

#### 设置环境变量

```bash
# 从部署日志中获取合约地址
export OPTION_TOKEN=0x5FbDB2315678afecb367f032d93F642f64180aa3
export USDT=0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
export POOL=0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0

# 账户地址（Anvil 默认账户）
export PROJECT=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
export USER1=0x70997970C51812dc3A010C7d01b50e0d17dc79C8
export USER2=0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC

# 私钥
export PROJECT_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
export USER1_KEY=0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d
export USER2_KEY=0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a
```

#### 查询期权信息

```bash
# 查询期权池信息
cast call $POOL "getPoolInfo()" --rpc-url http://localhost:8545

# 查询期权代币余额
cast call $OPTION_TOKEN "balanceOf(address)(uint256)" $PROJECT --rpc-url http://localhost:8545

# 查询 USDT 余额
cast call $USDT "balanceOf(address)(uint256)" $PROJECT --rpc-url http://localhost:8545
```

#### User1 购买期权

```bash
# 1. 给 User1 铸造 USDT
cast send $USDT "mintTo(address,uint256)" $USER1 100000000000000000000000 \
  --private-key $PROJECT_KEY \
  --rpc-url http://localhost:8545

# 2. User1 授权 USDT
cast send $USDT "approve(address,uint256)" $POOL 500000000000000000000 \
  --private-key $USER1_KEY \
  --rpc-url http://localhost:8545

# 3. 项目方授权期权代币转移
cast send $OPTION_TOKEN "approve(address,uint256)" $POOL 5000000000000000000 \
  --private-key $PROJECT_KEY \
  --rpc-url http://localhost:8545

# 4. User1 购买期权
cast send $POOL "purchaseOptions(uint256)" 5000000000000000000 \
  --private-key $USER1_KEY \
  --rpc-url http://localhost:8545

# 5. 验证 User1 的期权代币余额
cast call $OPTION_TOKEN "balanceOf(address)(uint256)" $USER1 --rpc-url http://localhost:8545
```

#### User1 行权（需要等到到期日）

```bash
# 1. User1 授权 USDT（执行价）
cast send $USDT "approve(address,uint256)" $POOL 10000000000000000000000 \
  --private-key $USER1_KEY \
  --rpc-url http://localhost:8545

# 2. User1 行权
cast send $POOL "exerciseOptions(uint256)" 5000000000000000000 \
  --private-key $USER1_KEY \
  --rpc-url http://localhost:8545

# 3. 验证 User1 的 ETH 余额
cast balance $USER1 --rpc-url http://localhost:8545
```

### 场景 2: 使用 Foundry 脚本

创建一个自定义脚本来执行完整流程：

```solidity
// script/CustomDemo.s.sol
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/OptionPool.sol";
import "../src/CallOptionToken.sol";
import "../src/MockUSDT.sol";

contract CustomDemo is Script {
    function run() external {
        // 使用 vm.broadcast() 发送交易
        vm.startBroadcast();
        
        // 您的自定义逻辑
        
        vm.stopBroadcast();
    }
}
```

运行脚本：

```bash
forge script script/CustomDemo.s.sol:CustomDemo \
  --rpc-url http://localhost:8545 \
  --private-key YOUR_PRIVATE_KEY \
  --broadcast
```

## 🧪 测试场景

### 测试用例说明

1. **testConfigureOption**: 验证期权参数配置
2. **testIssueOptions**: 测试期权发行
3. **testPurchaseOptions**: 测试期权购买
4. **testExerciseOptions**: 测试期权行权
5. **testSettleExpiredOptions**: 测试过期清算
6. **testCannotExerciseBeforeExpiry**: 验证到期前不能行权
7. **testCannotPurchaseAfterExpiry**: 验证过期后不能购买
8. **testMultipleUsersScenario**: 多用户完整场景测试
9. **testGetPoolInfo**: 测试信息查询功能

### 运行特定测试

```bash
# 运行单个测试
forge test --match-test testExerciseOptions

# 运行多个测试
forge test --match-test "testIssue|testPurchase"

# 查看详细日志
forge test --match-test testMultipleUsersScenario -vvvv
```

## 📊 Gas 优化

查看 gas 使用报告：

```bash
forge test --gas-report
```

示例输出：

```
| Function              | Gas     |
|-----------------------|---------|
| issueOptions          | 130,000 |
| purchaseOptions       | 95,000  |
| exerciseOptions       | 115,000 |
| settleExpiredOptions  | 85,000  |
```

## 🔍 调试技巧

### 1. 使用 Forge 调试器

```bash
forge test --match-test testExerciseOptions --debug
```

### 2. 查看事件日志

```bash
forge test -vvvv
```

### 3. 使用 console.log

在合约中添加：

```solidity
import "forge-std/console.sol";

function someFunction() public {
    console.log("Value:", someValue);
}
```

## 📈 监控合约状态

### 使用 Cast 监控

```bash
# 持续监控期权池状态
watch -n 5 'cast call $POOL "getPoolInfo()" --rpc-url http://localhost:8545'

# 监控余额变化
watch -n 5 'cast balance $USER1 --rpc-url http://localhost:8545'
```

### 解析事件日志

```bash
# 获取最近的事件
cast logs --address $POOL --rpc-url http://localhost:8545
```

## 🎯 实际场景模拟

### 场景：ETH 价格上涨，用户盈利

```bash
# 假设参数：
# - 执行价：2000 USDT/ETH
# - 权利金：100 USDT
# - 市场价：2500 USDT/ETH（到期时）

# 用户成本：100 + 2000 = 2100 USDT
# 用户获得：1 ETH = 2500 USDT
# 用户盈利：2500 - 2100 = 400 USDT (19% 收益率)
```

### 场景：ETH 价格下跌，用户放弃行权

```bash
# 假设参数：
# - 执行价：2000 USDT/ETH
# - 权利金：100 USDT
# - 市场价：1800 USDT/ETH（到期时）

# 用户选择不行权（因为市场价 < 执行价）
# 用户损失：100 USDT（权利金）
# 项目方收益：100 USDT（权利金）+ 1 ETH（未被行权）
```

## 🔐 安全注意事项

1. **私钥管理**：
   - 永远不要在生产环境使用示例私钥
   - 使用硬件钱包或安全的密钥管理方案

2. **合约交互**：
   - 交易前验证合约地址
   - 检查授权金额
   - 在主网部署前进行充分测试

3. **Gas 费用**：
   - 在测试网测试时注意 gas 消耗
   - 使用 gas 估算避免交易失败

## 🛠️ 故障排除

### 常见问题

1. **"Only option pool can mint" 错误**
   - 确保已调用 `optionToken.setOptionPool()`

2. **"Not in exercise period" 错误**
   - 检查当前时间是否在可行权期内
   - 使用 `vm.warp()` 在测试中模拟时间推进

3. **"Insufficient options available" 错误**
   - 确保项目方有足够的期权代币
   - 检查是否已授权足够的代币转移

4. **USDT 转账失败**
   - 确保已调用 `usdt.approve()`
   - 检查 USDT 余额是否足够

## 📞 获取帮助

- GitHub Issues: https://github.com/davidweb3-ctrl/call-option-token/issues
- Foundry 文档: https://book.getfoundry.sh/
- OpenZeppelin 文档: https://docs.openzeppelin.com/

## 🎓 学习资源

- [Foundry Book](https://book.getfoundry.sh/)
- [Solidity by Example](https://solidity-by-example.org/)
- [Smart Contract Security](https://consensys.github.io/smart-contract-best-practices/)
- [期权基础知识](https://www.investopedia.com/terms/c/calloption.asp)

