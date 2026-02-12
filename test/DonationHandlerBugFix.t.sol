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

/// @title DonationHandlerBugFixTest
/// @notice Tests for the bug fix that ensures amounts array sums to totalAmount
/// @dev These tests verify the fix for the vulnerability where mismatched amounts could lock or steal ETH/tokens
contract DonationHandlerBugFixTest is Test {
  DonationHandler public handler;
  MockERC20 public mockToken;

  address public alice;
  address public bob;
  address public eve;

  event DonationMade(address indexed recipientAddress, uint256 amount, address indexed tokenAddress, bytes data);

  function setUp() public {
    // Deploy contracts
    handler = new DonationHandler();
    handler = DonationHandler(
      payable(address(new ERC1967Proxy(address(handler), abi.encodeCall(DonationHandler.initialize, ()))))
    );
    mockToken = new MockERC20();

    // Setup accounts
    alice = makeAddr('alice');
    bob = makeAddr('bob');
    eve = makeAddr('eve');

    // Fund accounts
    vm.deal(alice, 100 ether);
    vm.deal(bob, 100 ether);
    vm.deal(eve, 100 ether);

    // Give Alice some tokens
    mockToken.transfer(alice, 10000e18);
  }

  /// @notice Test that donateManyETH reverts when amounts sum is less than totalAmount
  /// @dev This prevents ETH from getting stuck in the contract
  function test_RevertWhen_ETHAmountsSumLessThanTotal() public {
    address[] memory to = new address[](1);
    to[0] = bob;
    uint256[] memory amts = new uint256[](1);
    amts[0] = 8 ether; // Only 8 ETH allocated
    bytes[] memory data = new bytes[](1);

    vm.prank(alice);
    vm.expectRevert('Amounts do not match total');
    handler.donateManyETH{value: 10 ether}(10 ether, to, amts, data); // But sending 10 ETH
  }

  /// @notice Test that donateManyETH reverts when amounts sum is greater than totalAmount
  /// @dev This prevents draining of previously stuck funds
  function test_RevertWhen_ETHAmountsSumGreaterThanTotal() public {
    address[] memory to = new address[](1);
    to[0] = bob;
    uint256[] memory amts = new uint256[](1);
    amts[0] = 12 ether; // 12 ETH allocated
    bytes[] memory data = new bytes[](1);

    vm.prank(alice);
    vm.expectRevert('Amounts do not match total');
    handler.donateManyETH{value: 10 ether}(10 ether, to, amts, data); // But only sending 10 ETH
  }

  /// @notice Test that donateManyETH reverts with empty arrays
  /// @dev This prevents locking all sent ETH with no recipients
  function test_RevertWhen_ETHEmptyArraysWithValue() public {
    address[] memory to = new address[](0);
    uint256[] memory amts = new uint256[](0);
    bytes[] memory data = new bytes[](0);

    vm.prank(alice);
    vm.expectRevert('Amounts do not match total');
    handler.donateManyETH{value: 10 ether}(10 ether, to, amts, data);
  }

  /// @notice Test that donateManyETH succeeds when amounts sum exactly equals totalAmount
  /// @dev This is the correct behavior
  function test_SuccessWhen_ETHAmountsSumEqualsTotal() public {
    address[] memory to = new address[](2);
    to[0] = bob;
    to[1] = eve;
    uint256[] memory amts = new uint256[](2);
    amts[0] = 6 ether;
    amts[1] = 4 ether; // Total = 10 ETH
    bytes[] memory data = new bytes[](2);

    uint256 bobBefore = bob.balance;
    uint256 eveBefore = eve.balance;

    vm.prank(alice);
    handler.donateManyETH{value: 10 ether}(10 ether, to, amts, data);

    assertEq(bob.balance, bobBefore + 6 ether);
    assertEq(eve.balance, eveBefore + 4 ether);
    assertEq(address(handler).balance, 0); // No ETH stuck in contract
  }

  /// @notice Test that the contract balance remains zero after multiple correct donations
  /// @dev This ensures no ETH accumulates in the contract
  function test_ContractBalanceRemainsZeroAfterMultipleDonations() public {
    address[] memory to = new address[](1);
    to[0] = bob;
    uint256[] memory amts = new uint256[](1);
    amts[0] = 5 ether;
    bytes[] memory data = new bytes[](1);

    // First donation
    vm.prank(alice);
    handler.donateManyETH{value: 5 ether}(5 ether, to, amts, data);
    assertEq(address(handler).balance, 0);

    // Second donation
    vm.prank(eve);
    handler.donateManyETH{value: 5 ether}(5 ether, to, amts, data);
    assertEq(address(handler).balance, 0);

    // Third donation
    vm.prank(alice);
    handler.donateManyETH{value: 5 ether}(5 ether, to, amts, data);
    assertEq(address(handler).balance, 0);
  }

  /// @notice Test that donateManyERC20 reverts when amounts sum is less than totalAmount
  /// @dev This prevents inconsistent token transfers
  function test_RevertWhen_ERC20AmountsSumLessThanTotal() public {
    address[] memory to = new address[](1);
    to[0] = bob;
    uint256[] memory amts = new uint256[](1);
    amts[0] = 800e18; // Only 800 tokens allocated
    bytes[] memory data = new bytes[](1);

    vm.startPrank(alice);
    mockToken.approve(address(handler), 1000e18);

    vm.expectRevert('Amounts do not match total');
    handler.donateManyERC20(address(mockToken), 1000e18, to, amts, data); // But claiming 1000 total
    vm.stopPrank();
  }

  /// @notice Test that donateManyERC20 reverts when amounts sum is greater than totalAmount
  /// @dev This prevents over-transfers
  function test_RevertWhen_ERC20AmountsSumGreaterThanTotal() public {
    address[] memory to = new address[](1);
    to[0] = bob;
    uint256[] memory amts = new uint256[](1);
    amts[0] = 1200e18; // 1200 tokens allocated
    bytes[] memory data = new bytes[](1);

    vm.startPrank(alice);
    mockToken.approve(address(handler), 1000e18);

    vm.expectRevert('Amounts do not match total');
    handler.donateManyERC20(address(mockToken), 1000e18, to, amts, data); // But only 1000 approved
    vm.stopPrank();
  }

  /// @notice Test that donateManyERC20 succeeds when amounts sum exactly equals totalAmount
  /// @dev This is the correct behavior
  function test_SuccessWhen_ERC20AmountsSumEqualsTotal() public {
    address[] memory to = new address[](2);
    to[0] = bob;
    to[1] = eve;
    uint256[] memory amts = new uint256[](2);
    amts[0] = 600e18;
    amts[1] = 400e18; // Total = 1000 tokens
    bytes[] memory data = new bytes[](2);

    uint256 aliceBefore = mockToken.balanceOf(alice);
    uint256 bobBefore = mockToken.balanceOf(bob);
    uint256 eveBefore = mockToken.balanceOf(eve);

    vm.startPrank(alice);
    mockToken.approve(address(handler), 1000e18);
    handler.donateManyERC20(address(mockToken), 1000e18, to, amts, data);
    vm.stopPrank();

    assertEq(mockToken.balanceOf(alice), aliceBefore - 1000e18);
    assertEq(mockToken.balanceOf(bob), bobBefore + 600e18);
    assertEq(mockToken.balanceOf(eve), eveBefore + 400e18);
  }

  /// @notice Test multiple recipients with matching sum
  /// @dev Ensures the fix works with more complex scenarios
  function test_SuccessWhen_MultipleRecipientsWithMatchingSum() public {
    address[] memory to = new address[](5);
    to[0] = bob;
    to[1] = eve;
    to[2] = alice;
    to[3] = makeAddr('charlie');
    to[4] = makeAddr('dave');
    
    uint256[] memory amts = new uint256[](5);
    amts[0] = 1 ether;
    amts[1] = 2 ether;
    amts[2] = 3 ether;
    amts[3] = 2.5 ether;
    amts[4] = 1.5 ether; // Total = 10 ETH
    
    bytes[] memory data = new bytes[](5);

    vm.prank(alice);
    handler.donateManyETH{value: 10 ether}(10 ether, to, amts, data);

    assertEq(address(handler).balance, 0);
  }

  /// @notice Test that amounts array with overflow protection still works
  /// @dev Ensures unchecked increment doesn't break the sum validation
  function test_SuccessWhen_LargeNumberOfRecipients() public {
    uint256 numRecipients = 50;
    address[] memory to = new address[](numRecipients);
    uint256[] memory amts = new uint256[](numRecipients);
    bytes[] memory data = new bytes[](numRecipients);

    for (uint256 i = 0; i < numRecipients; i++) {
      to[i] = makeAddr(string(abi.encodePacked('recipient', vm.toString(i))));
      amts[i] = 0.1 ether; // Each gets 0.1 ETH
    }

    vm.prank(alice);
    handler.donateManyETH{value: 5 ether}(5 ether, to, amts, data); // 50 * 0.1 = 5 ETH

    assertEq(address(handler).balance, 0);
  }
}
