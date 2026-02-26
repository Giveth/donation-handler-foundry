// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {DonationHandler} from '../src/contracts/DonationHandler.sol';
import {ProxyAdmin} from '@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol';
import {ITransparentUpgradeableProxy} from '@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol';
import {Script} from 'forge-std/Script.sol';
import {console} from 'forge-std/console.sol';

contract UpgradeDonationHandler is Script {
  /// @notice Upgrade existing proxy. Set PROXY_ADDRESS and PROXY_ADMIN_ADDRESS in .env (or pass via CLI).
  function run() external {
    uint256 deployerPrivateKey = vm.envUint('PRIVATE_KEY');
    address proxyAddress = vm.envAddress('PROXY_ADDRESS');
    address proxyAdminAddress = vm.envAddress('PROXY_ADMIN_ADDRESS');

    console.log('=== Upgrading DonationHandler ===');
    console.log('Proxy Address:', proxyAddress);
    console.log('ProxyAdmin Address:', proxyAdminAddress);

    vm.startBroadcast(deployerPrivateKey);

    // Step 1: Deploy new implementation
    DonationHandler newImplementation = new DonationHandler();
    console.log('New Implementation deployed to:', address(newImplementation));

    // Step 2: Upgrade the proxy to point to new implementation
    ProxyAdmin proxyAdmin = ProxyAdmin(proxyAdminAddress);
    proxyAdmin.upgradeAndCall(
      ITransparentUpgradeableProxy(proxyAddress),
      address(newImplementation),
      '' // No initialization data needed for upgrade
    );

    console.log('Proxy upgraded successfully!');
    console.log('Proxy now points to implementation:', address(newImplementation));

    vm.stopBroadcast();
  }
}
