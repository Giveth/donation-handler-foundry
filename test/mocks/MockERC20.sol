// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract MockERC20 is ERC20 {
  constructor() ERC20('MockToken', 'MTK') {
    _mint(msg.sender, 1_000_000 * 10 ** 18);
  }
}
