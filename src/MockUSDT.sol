// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockUSDT
 * @notice 测试用的 USDT 代币
 */
contract MockUSDT is ERC20 {
    constructor() ERC20("Mock USDT", "USDT") {
        // 铸造 1,000,000 USDT 给部署者
        _mint(msg.sender, 1_000_000 * 10 ** decimals());
    }

    /**
     * @notice 任何人都可以免费获取测试 USDT
     * @param amount 获取数量
     */
    function mint(uint256 amount) external {
        _mint(msg.sender, amount);
    }

    /**
     * @notice 给指定地址铸造 USDT
     * @param to 接收地址
     * @param amount 铸造数量
     */
    function mintTo(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

