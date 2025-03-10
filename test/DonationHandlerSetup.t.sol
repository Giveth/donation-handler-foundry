// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import '../src/contracts/DonationHandler.sol';

import '@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import 'forge-std/Test.sol';

// Mock ERC20 token for testing
contract MockERC20 is ERC20 {
  constructor() ERC20('MockToken', 'MTK') {
    _mint(msg.sender, 1_000_000 * 10 ** 18);
  }
}

contract FailingMockERC20 is ERC20 {
  constructor() ERC20('FailingToken', 'FAIL') {
    _mint(msg.sender, 1_000_000 * 10 ** 18);
  }

  function transferFrom(address, address, uint256) public pure override returns (bool) {
    return false;
  }
}

contract DonationHandlerSetup is Test {
  DonationHandler public donationHandler;
  MockERC20 public mockToken;

  address public owner;
  address public recipient1;
  address public recipient2;
  address public recipient3;

  uint256 public constant INITIAL_BALANCE = 100 ether;
  uint256 public constant INITIAL_TOKEN_BALANCE = 1_000_000 * 10 ** 18;

  event DonationMade(address indexed recipientAddress, uint256 amount, address indexed tokenAddress, bytes data);

  error InvalidInitialization();

  function _setUp() internal {
    // Deploy contracts
    donationHandler = new DonationHandler();
    donationHandler = DonationHandler(
      payable(address(new ERC1967Proxy(address(donationHandler), abi.encodeCall(DonationHandler.initialize, ()))))
    );
    mockToken = new MockERC20();
    // accounts
    owner = address(this);
    recipient1 = makeAddr('recipient1');
    recipient2 = makeAddr('recipient2');
    recipient3 = makeAddr('recipient3');

    // add funds to the owner address
    vm.deal(owner, INITIAL_BALANCE);

    // Approve tokens in the contract
    mockToken.approve(address(donationHandler), type(uint256).max);

    vm.label(address(donationHandler), 'DonationHandler');
    vm.label(address(mockToken), 'MockToken');
    vm.label(owner, 'owner');
    vm.label(recipient1, 'recipient1');
    vm.label(recipient2, 'recipient2');
    vm.label(recipient3, 'recipient3');
  }

  // Helper functions
  function _setupMultipleRecipients()
    internal
    pure
    returns (address[] memory recipients, uint256[] memory amounts, bytes[] memory data)
  {
    recipients = new address[](3);
    recipients[0] = address(0x1);
    recipients[1] = address(0x2);
    recipients[2] = address(0x3);

    amounts = new uint256[](3);
    amounts[0] = 1 ether;
    amounts[1] = 2 ether;
    amounts[2] = 3 ether;

    data = new bytes[](3);
    data[0] = '';
    data[1] = '';
    data[2] = '';
  }

  function _expectDonationEvent(address recipient, uint256 amount, address token) internal {
    vm.expectEmit(true, true, false, true);
    emit DonationMade(recipient, amount, token, '');
  }

  // Helper function => recipient that reverts on ETH receive
  function _deployRevertingRecipient() internal returns (address) {
    // This bytecode creates a contract that exists and has a fallback function that reverts
    bytes memory bytecode =
      hex'6080604052348015600f57600080fd5b5060868061001e6000396000f3fe6080604052348015600f57600080fd5b506004361060285760003560e01c8063600560001460375763600560001460375760285760003560e01c8063600560001460375763600560001460375b600080fd5b348015604257600080fd5b50600080fd';
    address recipient;
    assembly {
      recipient := create(0, add(bytecode, 0x20), mload(bytecode))
    }
    require(recipient != address(0), 'Failed to deploy reverting recipient');
    return recipient;
  }

  modifier whenMakingETHDonations() {
    vm.deal(address(this), 100 ether);
    _;
  }

  modifier whenMakingERC20Donations() {
    mockToken.approve(address(donationHandler), type(uint256).max);
    _;
  }
}
