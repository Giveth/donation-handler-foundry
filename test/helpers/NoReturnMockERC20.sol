// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

/// @dev Minimal ERC20-like token with no return value from transferFrom (USDT-style).
contract NoReturnMockERC20 {
  string public name = 'NoReturnToken';
  string public symbol = 'NRT';
  uint8 public decimals = 6;
  uint256 public totalSupply = 1_000_000 * 10 ** 6;

  mapping(address => uint256) public balanceOf;
  mapping(address => mapping(address => uint256)) public allowance;

  event Transfer(address indexed from, address indexed to, uint256 value);
  event Approval(address indexed owner, address indexed spender, uint256 value);

  constructor() {
    balanceOf[msg.sender] = totalSupply;
    emit Transfer(address(0), msg.sender, totalSupply);
  }

  function approve(address spender, uint256 value) external {
    allowance[msg.sender][spender] = value;
    emit Approval(msg.sender, spender, value);
  }

  function transferFrom(address from, address to, uint256 value) external {
    require(to != address(0), 'Invalid recipient');
    require(balanceOf[from] >= value, 'Insufficient balance');
    require(allowance[from][msg.sender] >= value, 'Insufficient allowance');

    allowance[from][msg.sender] -= value;
    balanceOf[from] -= value;
    balanceOf[to] += value;

    emit Transfer(from, to, value);
  }
}
