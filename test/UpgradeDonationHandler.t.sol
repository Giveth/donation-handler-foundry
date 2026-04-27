// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {DonationHandler} from '../src/contracts/DonationHandler.sol';
import {ProxyAdmin} from '@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol';
import {
  ITransparentUpgradeableProxy,
  TransparentUpgradeableProxy
} from '@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol';
import {Test} from 'forge-std/Test.sol';

contract DonationHandlerUpgradeTest is Test {
  DonationHandler public donationHandler;
  TransparentUpgradeableProxy public proxy;
  ProxyAdmin public proxyAdmin;

  bytes32 internal constant IMPLEMENTATION_SLOT = bytes32(uint256(keccak256('eip1967.proxy.implementation')) - 1);
  bytes32 internal constant ADMIN_SLOT = bytes32(uint256(keccak256('eip1967.proxy.admin')) - 1);

  function setUp() public {
    DonationHandler implementation = new DonationHandler();
    proxy = new TransparentUpgradeableProxy(
      address(implementation), address(this), abi.encodeCall(DonationHandler.initialize, ())
    );
    donationHandler = DonationHandler(payable(address(proxy)));
    proxyAdmin = ProxyAdmin(_slotAddress(address(proxy), ADMIN_SLOT));

    vm.deal(address(this), 20 ether);
  }

  function testUpgradeKeepsOwnerAndUpdatesImplementation() public {
    address oldImplementation = _slotAddress(address(proxy), IMPLEMENTATION_SLOT);
    assertEq(donationHandler.owner(), address(this));

    DonationHandler newImplementation = new DonationHandler();

    proxyAdmin.upgradeAndCall(ITransparentUpgradeableProxy(payable(address(proxy))), address(newImplementation), '');

    address currentImplementation = _slotAddress(address(proxy), IMPLEMENTATION_SLOT);

    assertEq(currentImplementation, address(newImplementation));
    assertTrue(currentImplementation != oldImplementation);
    assertEq(donationHandler.owner(), address(this));
  }

  function testUpgradedProxyPreservesDonationChecks() public {
    DonationHandler newImplementation = new DonationHandler();
    proxyAdmin.upgradeAndCall(ITransparentUpgradeableProxy(payable(address(proxy))), address(newImplementation), '');

    address[] memory recipients = new address[](2);
    recipients[0] = makeAddr('recipient1');
    recipients[1] = makeAddr('recipient2');

    uint256[] memory amounts = new uint256[](2);
    amounts[0] = 6 ether;
    amounts[1] = 4 ether;

    bytes[] memory data = new bytes[](2);

    uint256 recipient1Before = recipients[0].balance;
    uint256 recipient2Before = recipients[1].balance;

    donationHandler.donateManyETH{value: 10 ether}(10 ether, recipients, amounts, data);

    assertEq(recipients[0].balance, recipient1Before + 6 ether);
    assertEq(recipients[1].balance, recipient2Before + 4 ether);
    assertEq(address(donationHandler).balance, 0);
    assertEq(donationHandler.owner(), address(this));
  }

  function testUpgradedProxyRejectsMismatchedAmounts() public {
    DonationHandler newImplementation = new DonationHandler();
    proxyAdmin.upgradeAndCall(ITransparentUpgradeableProxy(payable(address(proxy))), address(newImplementation), '');

    address[] memory recipients = new address[](1);
    recipients[0] = makeAddr('recipient');

    uint256[] memory amounts = new uint256[](1);
    amounts[0] = 8 ether;

    bytes[] memory data = new bytes[](1);

    vm.expectRevert('Amounts do not match total');
    donationHandler.donateManyETH{value: 10 ether}(10 ether, recipients, amounts, data);
  }

  function _slotAddress(address target, bytes32 slot) internal view returns (address) {
    return address(uint160(uint256(vm.load(target, slot))));
  }
}
