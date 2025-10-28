// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title CallOptionToken
 * @notice ERC20 代币，代表看涨期权
 * @dev 只有 OptionPool 合约可以铸造和销毁代币
 */
contract CallOptionToken is ERC20, Ownable {
    // 期权池合约地址
    address public optionPool;

    // 事件
    event OptionPoolSet(address indexed optionPool);

    constructor(
        string memory name,
        string memory symbol
    ) ERC20(name, symbol) Ownable(msg.sender) {}

    /**
     * @notice 设置期权池合约地址
     * @param _optionPool 期权池合约地址
     */
    function setOptionPool(address _optionPool) external onlyOwner {
        require(_optionPool != address(0), "Invalid option pool address");
        optionPool = _optionPool;
        emit OptionPoolSet(_optionPool);
    }

    /**
     * @notice 铸造期权代币
     * @param to 接收地址
     * @param amount 铸造数量
     */
    function mint(address to, uint256 amount) external {
        require(msg.sender == optionPool, "Only option pool can mint");
        _mint(to, amount);
    }

    /**
     * @notice 销毁期权代币
     * @param from 销毁地址
     * @param amount 销毁数量
     */
    function burn(address from, uint256 amount) external {
        require(msg.sender == optionPool, "Only option pool can burn");
        _burn(from, amount);
    }
}

