# Call Option Token (看涨期权代币)

一个基于 ERC20 的去中心化看涨期权系统，使用 Foundry 开发。

## 📋 项目概述

本项目实现了一个完整的看涨期权代币系统，包括：

- **期权代币发行**：项目方质押 ETH，按 1:1 比例发行期权代币
- **期权交易**：用户支付权利金购买期权代币
- **期权行权**：到期日当天，用户可用执行价格兑换 ETH
- **过期清算**：项目方可赎回未行权的 ETH

## 🏗️ 系统架构

### 核心合约

1. **CallOptionToken.sol**
   - ERC20 代币，代表看涨期权
   - 只有 OptionPool 合约可以铸造/销毁代币
   - 可自由转让

2. **OptionPool.sol**
   - 管理期权的完整生命周期
   - 控制发行、购买、行权和清算流程
   - 管理 ETH 池和期权状态

3. **MockUSDT.sol**
   - 测试用的 USDT 代币
   - 支持免费铸造（仅测试网）

### 期权状态

- **Active（活跃期）**：可以购买期权
- **Exercisable（可行权期）**：到期日当天，可以行权
- **Expired（已过期）**：可以清算

## 🚀 快速开始

### 环境要求

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Solidity ^0.8.20

### 安装依赖

```bash
# 克隆仓库
git clone git@github.com:davidweb3-ctrl/call-option-token.git
cd call-option-token

# 安装依赖
forge install
```

### 编译合约

```bash
forge build
```

### 运行测试

```bash
# 运行所有测试
forge test

# 详细输出
forge test -vv

# 运行特定测试
forge test --match-test testExerciseOptions -vvv
```

## 📝 使用流程

### 1. 部署合约

```bash
# 启动本地测试网
anvil

# 在新终端部署合约
forge script script/DeployAndSimulate.s.sol:DeployAndSimulate \
  --rpc-url http://localhost:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --broadcast
```

### 2. 项目方操作

**发行期权**：
```solidity
// 项目方质押 10 ETH，发行 10 个期权代币
pool.issueOptions{value: 10 ether}();
```

**配置期权参数**：
```solidity
uint256 strikePrice = 2000e18;   // 执行价格：2000 USDT/ETH
uint256 premiumPrice = 100e18;    // 权利金：100 USDT/代币
uint256 expiryTime = block.timestamp + 7 days;

pool.configureOption(strikePrice, premiumPrice, expiryTime);
```

**过期清算**：
```solidity
// 过期后，项目方赎回未行权的 ETH
pool.settleExpiredOptions();
```

### 3. 用户操作

**购买期权**：
```solidity
// 用户支付权利金购买期权
uint256 optionAmount = 5 ether;
usdt.approve(address(pool), premiumCost);
pool.purchaseOptions(optionAmount);
```

**行权**：
```solidity
// 到期日当天，用户支付执行价格行权
uint256 optionAmount = 5 ether;
usdt.approve(address(pool), strikeCost);
pool.exerciseOptions(optionAmount);
// 用户获得 5 ETH，期权代币被销毁
```

## 📊 示例场景

### 场景参数
- 执行价格（Strike Price）：2000 USDT/ETH
- 权利金（Premium）：100 USDT/代币
- 到期时间：7 天后

### 完整流程

1. **项目方发行**：质押 10 ETH → 获得 10 个期权代币

2. **用户购买**：
   - User1: 支付 500 USDT → 获得 5 个期权代币
   - User2: 支付 300 USDT → 获得 3 个期权代币

3. **用户行权**（到期日）：
   - User1: 支付 10,000 USDT → 获得 5 ETH
   - User2: 支付 6,000 USDT → 获得 3 ETH

4. **项目方清算**（过期后）：
   - 赎回剩余 2 ETH
   - 总收入：16,800 USDT

### 收益分析

**项目方**：
- 支出：8 ETH
- 收入：16,800 USDT
- 如果市场价 ETH = 2500 USDT，实际损失：3,200 USDT

**用户（假设行权时 ETH 市场价 = 2500 USDT）**：
- User1: 支付 10,500 USDT → 获得价值 12,500 USDT 的 5 ETH → 盈利 2,000 USDT
- User2: 支付 6,300 USDT → 获得价值 7,500 USDT 的 3 ETH → 盈利 1,200 USDT

## 🧪 测试用例

测试覆盖以下场景：

- ✅ 期权配置
- ✅ 期权发行
- ✅ 期权购买
- ✅ 期权行权
- ✅ 过期清算
- ✅ 到期前无法行权
- ✅ 过期后无法购买
- ✅ 多用户场景
- ✅ 合约信息查询

运行测试：
```bash
forge test -vv
```

## 📄 合约接口

### OptionPool 主要函数

```solidity
// 配置期权参数
function configureOption(uint256 strikePrice, uint256 premiumPrice, uint256 expiryTime)

// 项目方发行期权
function issueOptions() payable

// 用户购买期权
function purchaseOptions(uint256 optionAmount)

// 用户行权
function exerciseOptions(uint256 optionAmount)

// 项目方清算过期期权
function settleExpiredOptions()

// 查询合约信息
function getPoolInfo() returns (...)
```

## 🔐 安全特性

- ✅ 使用 OpenZeppelin 标准库
- ✅ ReentrancyGuard 防重入攻击
- ✅ Ownable 权限控制
- ✅ 状态机管理期权生命周期
- ✅ 完整的事件日志
- ✅ 输入参数验证

## 🛠️ 技术栈

- **框架**: Foundry
- **语言**: Solidity ^0.8.20
- **库**: OpenZeppelin Contracts v5.4.0
- **测试网**: Anvil (本地)

## 📂 项目结构

```
call-option-token/
├── src/
│   ├── CallOptionToken.sol    # 期权代币合约
│   ├── MockUSDT.sol           # 测试 USDT
│   └── OptionPool.sol         # 期权池合约
├── test/
│   └── OptionPool.t.sol       # 测试用例
├── script/
│   ├── DeployAndSimulate.s.sol    # 部署脚本
│   └── SimulateComplete.s.sol     # 完整模拟脚本
├── foundry.toml               # Foundry 配置
└── README.md
```

## 📝 执行日志

详见 [EXECUTION_LOG.md](./EXECUTION_LOG.md)

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📜 许可证

MIT License

## 👤 作者

David - [@davidweb3-ctrl](https://github.com/davidweb3-ctrl)

## 🔗 相关链接

- [Foundry Book](https://book.getfoundry.sh/)
- [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts/)
- [Solidity Documentation](https://docs.soliditylang.org/)
