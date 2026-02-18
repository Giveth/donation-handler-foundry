// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {DonationHandler} from '../src/contracts/DonationHandler.sol';
import {ProxyAdmin} from '@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol';
import {ITransparentUpgradeableProxy} from '@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol';
import {Script} from 'forge-std/Script.sol';
import {console} from 'forge-std/console.sol';

/// @title TestUpgrade
/// @notice Script to test the upgrade locally or on a fork before deploying to mainnet
contract TestUpgrade is Script {
  function run() external {
    address proxyAddress = vm.envAddress('PROXY_ADDRESS');
    address proxyAdminAddress = vm.envAddress('PROXY_ADMIN_ADDRESS');
    uint256 deployerPrivateKey = vm.envUint('PRIVATE_KEY');

    console.log('=== Testing DonationHandler Upgrade ===');
    console.log('Proxy:', proxyAddress);
    console.log('ProxyAdmin:', proxyAdminAddress);

    // Get current implementation before upgrade
    DonationHandler proxy = DonationHandler(payable(proxyAddress));
    bytes32 implSlot = bytes32(uint256(keccak256('eip1967.proxy.implementation')) - 1);
    address oldImplementation = address(uint160(uint256(vm.load(proxyAddress, implSlot))));
    console.log('Old Implementation:', oldImplementation);

    vm.startBroadcast(deployerPrivateKey);

    // Deploy new implementation
    DonationHandler newImplementation = new DonationHandler();
    console.log('New Implementation:', address(newImplementation));

    // Upgrade
    ProxyAdmin proxyAdmin = ProxyAdmin(proxyAdminAddress);
    proxyAdmin.upgradeAndCall(ITransparentUpgradeableProxy(proxyAddress), address(newImplementation), '');

    vm.stopBroadcast();

    // Verify upgrade
    address currentImplementation = address(uint160(uint256(vm.load(proxyAddress, implSlot))));
    console.log('Current Implementation:', currentImplementation);

    require(currentImplementation == address(newImplementation), 'Upgrade failed - implementation not updated');
    console.log('SUCCESS: Upgrade completed!');

    // Test the new validation
    console.log('\n=== Testing Bug Fix ===');
    _testBugFix(proxy);
  }

  function _testBugFix(DonationHandler proxy) internal {
    address recipient = address(0x1234567890123456789012345678901234567890);

    // Test 1: Should revert when amounts sum < totalAmount
    console.log('Test 1: amounts sum < totalAmount should revert');
    address[] memory recipients1 = new address[](1);
    recipients1[0] = recipient;
    uint256[] memory amounts1 = new uint256[](1);
    amounts1[0] = 8 ether; // Only 8 ETH allocated
    bytes[] memory data1 = new bytes[](1);

    vm.expectRevert('Amounts do not match total');
    proxy.donateManyETH{value: 10 ether}(10 ether, recipients1, amounts1, data1);
    console.log('  PASS: Correctly reverted');

    // Test 2: Should revert when amounts sum > totalAmount
    console.log('Test 2: amounts sum > totalAmount should revert');
    address[] memory recipients2 = new address[](1);
    recipients2[0] = recipient;
    uint256[] memory amounts2 = new uint256[](1);
    amounts2[0] = 12 ether; // 12 ETH allocated
    bytes[] memory data2 = new bytes[](1);

    vm.expectRevert('Amounts do not match total');
    proxy.donateManyETH{value: 10 ether}(10 ether, recipients2, amounts2, data2);
    console.log('  PASS: Correctly reverted');

    // Test 3: Should succeed when amounts sum == totalAmount
    console.log('Test 3: amounts sum == totalAmount should succeed');
    address[] memory recipients3 = new address[](2);
    recipients3[0] = recipient;
    recipients3[1] = address(0x9876543210987654321098765432109876543210);
    uint256[] memory amounts3 = new uint256[](2);
    amounts3[0] = 6 ether;
    amounts3[1] = 4 ether; // Total = 10 ETH
    bytes[] memory data3 = new bytes[](2);

    uint256 contractBalanceBefore = address(proxy).balance;
    proxy.donateManyETH{value: 10 ether}(10 ether, recipients3, amounts3, data3);
    uint256 contractBalanceAfter = address(proxy).balance;

    require(contractBalanceAfter == contractBalanceBefore, 'ETH stuck in contract!');
    console.log('  PASS: Donation succeeded and no ETH stuck');

    console.log('\n=== All Tests Passed! ===');
  }
}
