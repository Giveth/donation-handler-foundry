// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import '../src/contracts/DonationHandler.sol';

import {DonationHandlerSetup, FailingMockERC20, MockERC20} from './DonationHandlerSetup.t.sol';
import '@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import 'forge-std/Test.sol';

// Mock ERC20 token for testing

contract DummyMultisig {
  address public owner;
  bool public shouldRevert;
  bool public shouldReturnExcess;
  uint256 public gasStipend = 2300; // Default gas stipend for transfers

  constructor(address _owner) {
    owner = _owner;
  }

  // Configure multisig behavior
  function configure(bool _shouldRevert, bool _shouldReturnExcess, uint256 _gasStipend) external {
    shouldRevert = _shouldRevert;
    shouldReturnExcess = _shouldReturnExcess;
    gasStipend = _gasStipend;
  }

  // Execute a call to the donation handler
  function executeTransaction(address target, uint256 value, bytes memory data) external payable returns (bool success) {
    require(msg.sender == owner, 'Not authorized');

    if (shouldRevert) {
      revert('Multisig execution reverted');
    }

    // Execute the call
    (success,) = target.call{value: value, gas: gasleft() - gasStipend}(data);

    // Return any excess ETH if configured to do so
    if (shouldReturnExcess && address(this).balance > 0) {
      (bool refundSuccess,) = owner.call{value: address(this).balance}('');
      require(refundSuccess, 'Failed to return excess ETH');
    }
  }

  // Function to simulate a delegate call
  function executeDelegateCall(
    address target,
    bytes memory data
  ) external returns (bool success, bytes memory returnData) {
    require(msg.sender == owner, 'Not authorized');

    if (shouldRevert) {
      revert('Multisig execution reverted');
    }

    // Execute the delegate call
    (success, returnData) = target.delegatecall(data);
  }

  // Function to approve tokens for the donation handler
  function approveToken(address token, address spender, uint256 amount) external {
    require(msg.sender == owner, 'Not authorized');
    IERC20(token).approve(spender, amount);
  }

  // Receive function to accept ETH
  receive() external payable {}
}

contract DonationHandlerMultisigCalls is DonationHandlerSetup {
  DummyMultisig public dummyMultisig;
  address public multisigOwner = makeAddr('multisigOwner');
  address public multisigRecipient = makeAddr('multisigRecipient');
  address public multisigRecipient2 = makeAddr('multisigRecipient2');
  MockERC20 public mockERC20;

  function setUp() public {
    // Deploy contracts
    _setUp();
    dummyMultisig = new DummyMultisig(multisigOwner);
    mockERC20 = new MockERC20();

    // Give ETH to the multisig
    vm.deal(address(dummyMultisig), 2 ether);

    // Give ERC20 tokens to the multisig
    // The MockERC20 constructor mints tokens to the deployer (this contract)
    // So we need to transfer them to the multisig
    mockERC20.transfer(address(dummyMultisig), 1000e18);

    // Label for debugging
    vm.label(address(dummyMultisig), 'DummyMultisig');
    vm.label(address(mockERC20), 'MockERC20');
    vm.label(multisigOwner, 'MultisigOwner');
    vm.label(multisigRecipient, 'MultisigRecipient');
    vm.label(multisigRecipient2, 'MultisigRecipient2');
  }

  function testMultisigDonateETH() public {
    // Setup
    uint256 donationAmount = 1 ether;
    bytes memory data = abi.encode('test data');

    // Fund the multisig
    vm.deal(address(dummyMultisig), 2 ether);

    vm.prank(multisigOwner);
    bool success = dummyMultisig.executeTransaction(
      address(donationHandler),
      donationAmount,
      abi.encodeWithSelector(donationHandler.donateETH.selector, multisigRecipient, donationAmount, data)
    );

    assertTrue(success);
    assertEq(multisigRecipient.balance, donationAmount);
  }

  function testMultisigDonateManyETH() public {
    // Setup
    uint256[] memory amounts = new uint256[](2);
    amounts[0] = 0.5 ether;
    amounts[1] = 0.5 ether;

    address[] memory recipients = new address[](2);
    recipients[0] = multisigRecipient;
    recipients[1] = multisigRecipient2;

    bytes[] memory dataArray = new bytes[](2);
    dataArray[0] = abi.encode('data1');
    dataArray[1] = abi.encode('data2');

    uint256 totalAmount = 1 ether;

    // Fund the multisig
    vm.deal(address(dummyMultisig), 2 ether);

    vm.prank(multisigOwner);
    bool success = dummyMultisig.executeTransaction(
      address(donationHandler),
      totalAmount,
      abi.encodeWithSelector(donationHandler.donateManyETH.selector, totalAmount, recipients, amounts, dataArray)
    );

    assertTrue(success);
    assertEq(multisigRecipient.balance, amounts[0]);
    assertEq(multisigRecipient2.balance, amounts[1]);
  }

  function testMultisigDonateERC20() public {
    // Setup
    uint256 donationAmount = 100e18;
    bytes memory data = abi.encode('test data');

    // Mint tokens to multisig

    // Approve tokens
    vm.prank(multisigOwner);
    dummyMultisig.approveToken(address(mockERC20), address(donationHandler), donationAmount);

    vm.prank(multisigOwner);
    bool success = dummyMultisig.executeTransaction(
      address(donationHandler),
      0,
      abi.encodeWithSelector(
        donationHandler.donateERC20.selector, address(mockERC20), multisigRecipient, donationAmount, data
      )
    );

    assertTrue(success);
    assertEq(mockERC20.balanceOf(multisigRecipient), donationAmount);
  }

  function testMultisigDonateManyERC20() public {
    // Setup
    uint256[] memory amounts = new uint256[](2);
    amounts[0] = 50e18;
    amounts[1] = 50e18;

    address[] memory recipients = new address[](2);
    recipients[0] = multisigRecipient;
    recipients[1] = multisigRecipient2;

    bytes[] memory dataArray = new bytes[](2);
    dataArray[0] = abi.encode('data1');
    dataArray[1] = abi.encode('data2');

    uint256 totalAmount = 100e18;

    vm.prank(multisigOwner);
    dummyMultisig.approveToken(address(mockERC20), address(donationHandler), totalAmount);

    vm.prank(multisigOwner);
    bool success = dummyMultisig.executeTransaction(
      address(donationHandler),
      0,
      abi.encodeWithSelector(
        donationHandler.donateManyERC20.selector, address(mockERC20), totalAmount, recipients, amounts, dataArray
      )
    );

    assertTrue(success);
    assertEq(mockERC20.balanceOf(multisigRecipient), amounts[0]);
    assertEq(mockERC20.balanceOf(multisigRecipient2), amounts[1]);
  }
}
