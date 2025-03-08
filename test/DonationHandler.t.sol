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

contract DonationHandlerTest is Test {
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

  function setUp() public {
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

  function test_WhenMakingASingleETHDonation() external whenMakingETHDonations {
    uint256 donationAmount = 1 ether;
    bytes memory data = '';

    uint256 recipientBalanceBefore = recipient1.balance;

    _expectDonationEvent(recipient1, donationAmount, address(0));
    donationHandler.donateETH{value: donationAmount}(recipient1, donationAmount, data);

    assertEq(
      recipient1.balance - recipientBalanceBefore,
      donationAmount,
      'Recipient balance should increase by donation amount'
    );

    vm.expectRevert('Incorrect ETH amount sent');
    donationHandler.donateETH{value: donationAmount - 0.1 ether}(recipient1, donationAmount, data);
  }

  function test_WhenMakingMultipleETHDonations() external whenMakingETHDonations {
    (address[] memory recipients, uint256[] memory amounts, bytes[] memory data) = _setupMultipleRecipients();
    uint256 totalAmount = amounts[0] + amounts[1] + amounts[2];

    // Initial balances
    uint256[] memory initialBalances = new uint256[](3);
    for (uint256 i = 0; i < recipients.length; i++) {
      initialBalances[i] = recipients[i].balance;
      _expectDonationEvent(recipients[i], amounts[i], address(0));
    }

    donationHandler.donateManyETH{value: totalAmount}(totalAmount, recipients, amounts, data);

    // Verify balances
    for (uint256 i = 0; i < recipients.length; i++) {
      assertEq(
        recipients[i].balance - initialBalances[i], amounts[i], 'Recipient balance should increase by donation amount'
      );
    }

    // Test revert when msg.value doesn't match totalAmount
    vm.expectRevert('Incorrect ETH amount sent');
    donationHandler.donateManyETH{value: totalAmount - 0.1 ether}(totalAmount, recipients, amounts, data);

    // Test revert with mismatched array lengths
    address[] memory shortRecipients = new address[](2);
    vm.expectRevert(DonationHandler.InvalidInput.selector);
    donationHandler.donateManyETH{value: totalAmount}(totalAmount, shortRecipients, amounts, data);
  }

  function test_WhenMakingASingleERC20Donation() external whenMakingERC20Donations {
    uint256 donationAmount = 100 * 10 ** 18;
    bytes memory data = '';

    uint256 recipientBalanceBefore = mockToken.balanceOf(recipient1);

    _expectDonationEvent(recipient1, donationAmount, address(mockToken));
    donationHandler.donateERC20(address(mockToken), recipient1, donationAmount, data);

    assertEq(
      mockToken.balanceOf(recipient1) - recipientBalanceBefore,
      donationAmount,
      'Recipient token balance should increase by donation amount'
    );

    // expect revert when calling donate ERC20 with native token address
    vm.expectRevert('Invalid token address');
    donationHandler.donateERC20(address(0), recipient1, donationAmount, data);
    // expect revert when calling donateERC20 with null recipient address
    vm.expectRevert(DonationHandler.InvalidInput.selector);
    donationHandler.donateERC20(address(mockToken), address(0), donationAmount, data);
    // expect revert when calling donateERC20 with 0 amount
    vm.expectRevert(DonationHandler.InvalidInput.selector);
    donationHandler.donateERC20(address(mockToken), recipient1, 0, data);

    // Test insufficient allowance
    mockToken.approve(address(donationHandler), donationAmount - 1);
    vm.expectRevert();
    donationHandler.donateERC20(address(mockToken), recipient1, donationAmount, data);
  }

  function test_WhenMakingMultipleERC20Donations() external whenMakingERC20Donations {
    (address[] memory recipients, uint256[] memory amounts, bytes[] memory data) = _setupMultipleRecipients();
    uint256 totalAmount = amounts[0] + amounts[1] + amounts[2];

    // Record initial balances
    uint256[] memory initialBalances = new uint256[](3);
    for (uint256 i = 0; i < recipients.length; i++) {
      initialBalances[i] = mockToken.balanceOf(recipients[i]);
      _expectDonationEvent(recipients[i], amounts[i], address(mockToken));
    }

    donationHandler.donateManyERC20(address(mockToken), totalAmount, recipients, amounts, data);

    // Verify balances
    for (uint256 i = 0; i < recipients.length; i++) {
      assertEq(
        mockToken.balanceOf(recipients[i]) - initialBalances[i],
        amounts[i],
        'Recipient token balance should increase by donation amount'
      );
    }

    // Test revert with mismatched array lengths
    address[] memory shortRecipients = new address[](2);
    vm.expectRevert(DonationHandler.InvalidInput.selector);
    donationHandler.donateManyERC20(address(mockToken), totalAmount, shortRecipients, amounts, data);

    // Test insufficient allowance
    mockToken.approve(address(donationHandler), totalAmount - 1);
    vm.expectRevert(DonationHandler.InsufficientAllowance.selector);
    donationHandler.donateManyERC20(address(mockToken), totalAmount, recipients, amounts, data);
  }

  function test_RevertWhen_ReceivingDirectETHTransfers() external {
    vm.deal(address(this), 1 ether);
    vm.expectRevert();
    payable(address(donationHandler)).transfer(1 ether);
  }

  function test_RevertWhen_DonatingZeroETH() external whenMakingETHDonations {
    bytes memory data = '';
    vm.expectRevert(DonationHandler.InvalidInput.selector);
    donationHandler.donateETH{value: 0}(recipient1, 0, data);
  }

  function test_RevertWhen_DonatingETHToZeroAddress() external whenMakingETHDonations {
    bytes memory data = '';
    uint256 amount = 1 ether;
    vm.expectRevert(DonationHandler.InvalidInput.selector);
    donationHandler.donateETH{value: amount}(address(0), amount, data);
  }

  function test_RevertWhen_ETHValueMismatch() external whenMakingETHDonations {
    bytes memory data = '';
    uint256 amount = 1 ether;
    vm.expectRevert('Incorrect ETH amount sent');
    donationHandler.donateETH{value: 2 ether}(recipient1, amount, data);
  }

  function test_RevertWhen_ERC20TransferFails() external {
    FailingMockERC20 failingToken = new FailingMockERC20();
    bytes memory data = '';
    uint256 amount = 100 * 10 ** 18;
    failingToken.approve(address(donationHandler), amount);

    vm.expectRevert('ERC20 transfer failed');
    donationHandler.donateERC20(address(failingToken), recipient1, amount, data);
  }

  function test_RevertWhen_InitializingTwice() external {
    vm.expectRevert(Initializable.InvalidInitialization.selector);
    donationHandler.initialize();
  }

  function test_OwnershipTransfer() external {
    address newOwner = makeAddr('newOwner');
    donationHandler.transferOwnership(newOwner);
    assertEq(donationHandler.owner(), newOwner);
  }

  function test_RevertWhen_SingleETHTransferFails() external whenMakingETHDonations {
    // Deploy a contract that rejects ETH transfers
    address revertingRecipient = _deployRevertingRecipient();
    uint256 amount = 1 ether;
    bytes memory data = '';

    // Should revert when trying to send ETH to a contract that rejects it
    vm.expectRevert('ETH transfer failed');
    donationHandler.donateETH{value: amount}(revertingRecipient, amount, data);
  }

  function test_RevertWhen_MultipleETHTransferFailsOnOneRecipient() external whenMakingETHDonations {
    // Setup regular recipients and a reverting one
    address[] memory recipients = new address[](3);
    recipients[0] = recipient1;
    recipients[1] = _deployRevertingRecipient(); // This one will fail
    recipients[2] = recipient3;

    uint256[] memory amounts = new uint256[](3);
    amounts[0] = 1 ether;
    amounts[1] = 2 ether;
    amounts[2] = 3 ether;

    bytes[] memory data = new bytes[](3);
    data[0] = '';
    data[1] = '';
    data[2] = '';

    uint256 totalAmount = amounts[0] + amounts[1] + amounts[2];

    // Record initial balances to verify state is unchanged after revert
    uint256[] memory initialBalances = new uint256[](3);
    for (uint256 i = 0; i < recipients.length; i++) {
      initialBalances[i] = recipients[i].balance;
    }

    // Should revert when trying to send ETH to the reverting contract
    vm.expectRevert('ETH transfer failed');
    donationHandler.donateManyETH{value: totalAmount}(totalAmount, recipients, amounts, data);

    // Verify no balances changed (transaction was reverted)
    for (uint256 i = 0; i < recipients.length; i++) {
      assertEq(recipients[i].balance, initialBalances[i], 'Recipient balance should remain unchanged after revert');
    }
  }

  function test_RevertWhen_MultipleETHTransfersFailOnAllRecipients() external whenMakingETHDonations {
    // Setup all recipients as reverting contracts
    address[] memory recipients = new address[](3);
    recipients[0] = _deployRevertingRecipient();
    recipients[1] = _deployRevertingRecipient();
    recipients[2] = _deployRevertingRecipient();

    uint256[] memory amounts = new uint256[](3);
    amounts[0] = 1 ether;
    amounts[1] = 2 ether;
    amounts[2] = 3 ether;

    bytes[] memory data = new bytes[](3);
    data[0] = '';
    data[1] = '';
    data[2] = '';

    uint256 totalAmount = amounts[0] + amounts[1] + amounts[2];

    // Should revert on the first transfer attempt
    vm.expectRevert('ETH transfer failed');
    donationHandler.donateManyETH{value: totalAmount}(totalAmount, recipients, amounts, data);
  }
}
