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

contract DonationHandlerTest is Test {
  DonationHandler public donationHandler;
  MockERC20 public mockToken;

  address public owner;
  address public recipient1;
  address public recipient2;
  address public recipient3;

  uint256 public constant INITIAL_BALANCE = 100 ether;
  uint256 public constant INITIAL_TOKEN_BALANCE = 1_000_000 * 10 ** 18;

  event DonationMade(address indexed recipientAddress, uint256 amount, address indexed tokenAddress);

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
    emit DonationMade(recipient, amount, token);
  }

  // Helper function => recipient that reverts on ETH receive
  function _deployRevertingRecipient() internal returns (address) {
    bytes memory bytecode = hex'60806040523415600e57600080fd5b600080fdfe';
    address recipient;
    assembly {
      recipient := create(0, add(bytecode, 0x20), mload(bytecode))
    }
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
    // Test revert when sending incorrect amount
    vm.expectRevert('ETH transfer failed');
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

    // TODO FIX REVERTS WITH CUSTOM ERRORS
    vm.expectRevert();
    donationHandler.donateERC20(address(0), recipient1, donationAmount, data);

    vm.expectRevert();
    donationHandler.donateERC20(address(mockToken), address(0), donationAmount, data);

    vm.expectRevert();
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
}
