// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract FailingMockERC20 is ERC20 {
  constructor() ERC20('FailingToken', 'FAIL') {
    _mint(msg.sender, 1_000_000 * 10 ** 18);
  }

  function transferFrom(address, address, uint256) public pure override returns (bool) {
    return false;
  }
}
