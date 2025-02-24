// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';

import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import '@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol';
import '@openzeppelin/contracts/interfaces/IERC20.sol';

contract DonationHandler is OwnableUpgradeable, ReentrancyGuardUpgradeable {
  address private constant ETH_TOKEN_ADDRESS = address(0);

  /// @notice Event emitted when a donation is made
  /// @param recipientAddress The address of the recipient of the donation
  /// @param amount The amount of the donation
  /// @param tokenAddress The address of the token being donated
  event DonationMade(address indexed recipientAddress, uint256 amount, address indexed tokenAddress);

  // Custom errors
  /// @notice Error emitted when the input is invalid
  error InvalidInput();
  /// @notice Error emitted when the allowance is insufficient
  error InsufficientAllowance();

  // Structs
  /// @notice Struct to store the allocations of a donation
  /// @param tokenAddress The address of the token being donated
  /// @param totalAmount The total amount of the donation
  /// @param recipientAddresses The addresses of the recipients of the donation
  /// @param amounts The amounts of the donation to each recipient
  /// @param data The data of the donation to each recipient
  struct Allocations {
    address tokenAddress;
    uint256 totalAmount;
    address[] recipientAddresses;
    uint256[] amounts;
    bytes[] data;
  }

  constructor() {
    _disableInitializers();
  }

  function initialize() public initializer {
    __Ownable_init(msg.sender);
    __ReentrancyGuard_init();
  }

  // Modifiers
  /// @notice Modifier to validate the input lengths of the donation
  /// @param recipientAddresses The addresses of the recipients of the donation
  /// @param amounts The amounts of the donation to each recipient
  /// @param data The data of the donation to each recipient
  modifier validateInputLengths(
    address[] calldata recipientAddresses,
    uint256[] calldata amounts,
    bytes[] calldata data
  ) {
    if (recipientAddresses.length != data.length || recipientAddresses.length != amounts.length) {
      revert InvalidInput();
    }
    _;
  }

  /// @notice Modifier to check the ERC20 allowance of the owner
  /// @param tokenAddress The address of the token being donated
  /// @param requiredAmount The required amount of the allowance
  /// @param owner The owner of the token
  modifier checkERC20Allowance(address tokenAddress, uint256 requiredAmount, address owner) {
    uint256 allowance = IERC20(tokenAddress).allowance(owner, address(this));
    if (allowance < requiredAmount) {
      revert InsufficientAllowance();
    }
    _;
  }
  // ETH Donations
  // Donate multiple ETH donations at once
  /// @notice Donate multiple ETH donations at once
  /// @param totalAmount The total amount of the donation
  /// @param recipientAddresses The addresses of the recipients of the donation
  /// @param amounts The amounts of the donation to each recipient
  /// @param data The data of the donation to each recipient

  function donateManyETH(
    uint256 totalAmount,
    address[] calldata recipientAddresses,
    uint256[] calldata amounts,
    bytes[] calldata data
  ) external payable nonReentrant validateInputLengths(recipientAddresses, amounts, data) {
    Allocations memory allocations = Allocations(ETH_TOKEN_ADDRESS, totalAmount, recipientAddresses, amounts, data);
    require(allocations.tokenAddress == ETH_TOKEN_ADDRESS, 'Invalid token address for ETH');
    require(msg.value == allocations.totalAmount, 'Incorrect ETH amount sent');

    uint256 length = recipientAddresses.length;
    for (uint256 i = 0; i < length;) {
      _handleETH(allocations.amounts[i], allocations.recipientAddresses[i], allocations.data[i]);
      unchecked {
        ++i;
      }
    }
  }

  // Donate a single ETH donation
  /// @notice Donate a single ETH donation
  /// @param recipientAddress The address of the recipient of the donation
  /// @param amount The amount of the donation
  /// @param data The data of the donation
  function donateETH(address recipientAddress, uint256 amount, bytes calldata data) external payable nonReentrant {
    _handleETH(amount, recipientAddress, data);
  }

  // ERC20 Donations
  // Donate multiple ERC20 donations at once
  /// @notice Donate multiple ERC20 donations at once
  /// @param tokenAddress The address of the token being donated
  /// @param totalAmount The total amount of the donation
  /// @param recipientAddresses The addresses of the recipients of the donation
  /// @param amounts The amounts of the donation to each recipient
  /// @param data The data of the donation to each recipient
  function donateManyERC20(
    address tokenAddress,
    uint256 totalAmount,
    address[] calldata recipientAddresses,
    uint256[] calldata amounts,
    bytes[] calldata data
  )
    external
    nonReentrant
    validateInputLengths(recipientAddresses, amounts, data)
    checkERC20Allowance(tokenAddress, totalAmount, msg.sender)
  {
    Allocations memory allocations = Allocations(tokenAddress, totalAmount, recipientAddresses, amounts, data);
    require(allocations.tokenAddress != ETH_TOKEN_ADDRESS, 'Invalid token address');

    uint256 length = recipientAddresses.length;
    for (uint256 i = 0; i < length;) {
      _handleERC20(
        allocations.tokenAddress, allocations.amounts[i], allocations.recipientAddresses[i], allocations.data[i]
      );
      unchecked {
        ++i;
      }
    }
  }

  // Donate a single ERC20 donation
  /// @notice Donate a single ERC20 donation
  /// @param tokenAddress The address of the token being donated
  /// @param recipientAddress The address of the recipient of the donation
  /// @param amount The amount of the donation
  /// @param data The data of the donation
  function donateERC20(
    address tokenAddress,
    address recipientAddress,
    uint256 amount,
    bytes calldata data
  ) external nonReentrant checkERC20Allowance(tokenAddress, amount, msg.sender) {
    require(tokenAddress != ETH_TOKEN_ADDRESS, 'Invalid token address');
    _handleERC20(tokenAddress, amount, recipientAddress, data);
  }

  // Internal functions
  /// @notice Handle a single ETH donation
  /// @param amount The amount of the donation
  /// @param recipientAddress The address of the recipient of the donation
  function _handleETH(uint256 amount, address recipientAddress, bytes memory) internal {
    // Interactions
    (bool success,) = recipientAddress.call{value: amount}('');
    require(success, 'ETH transfer failed');
    // Effects
    emit DonationMade(recipientAddress, amount, ETH_TOKEN_ADDRESS);
  }

  /// @notice Handle a single ERC20 donation
  /// @param token The address of the token being donated
  /// @param amount The amount of the donation
  /// @param recipientAddress The address of the recipient of the donation
  function _handleERC20(address token, uint256 amount, address recipientAddress, bytes memory) internal {
    if (token == address(0) || recipientAddress == address(0)) revert InvalidInput();
    if (amount == 0) revert InvalidInput();
    bool success = IERC20(token).transferFrom(msg.sender, recipientAddress, amount);
    require(success, 'ERC20 transfer failed');

    emit DonationMade(recipientAddress, amount, token);
  }

  // Receive function to accept ETH
  receive() external payable {
    // Only accept ETH through allocateETH function
    revert('Use allocateETH function to send ETH');
  }
}
