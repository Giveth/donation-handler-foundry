// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {ProxyAdmin} from '@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol';
import {ITransparentUpgradeableProxy} from '@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol';
import {Script} from 'forge-std/Script.sol';
import {console} from 'forge-std/console.sol';

contract UpgradeDonationHandler is Script {
  /// @notice Upgrade existing proxy to a pre-deployed implementation.
  /// Set PROXY_ADDRESS, PROXY_ADMIN_ADDRESS, NEW_IMPLEMENTATION_ADDRESS in .env (deploy impl via deploy:implementation first).
  function run() external {
    uint256 deployerPrivateKey = vm.envUint('PRIVATE_KEY');
    address proxyAddress = vm.envAddress('PROXY_ADDRESS');
    address proxyAdminAddress = vm.envAddress('PROXY_ADMIN_ADDRESS');
    address newImplementation = vm.envAddress('NEW_IMPLEMENTATION_ADDRESS');

    console.log('=== Upgrading DonationHandler ===');
    console.log('Proxy Address:', proxyAddress);
    console.log('ProxyAdmin Address:', proxyAdminAddress);
    console.log('New Implementation:', newImplementation);

    vm.startBroadcast(deployerPrivateKey);

    ProxyAdmin proxyAdmin = ProxyAdmin(proxyAdminAddress);
    proxyAdmin.upgradeAndCall(
      ITransparentUpgradeableProxy(proxyAddress),
      newImplementation,
      '' // No initialization data needed for upgrade
    );

    console.log('Proxy upgraded successfully!');
    console.log('Proxy now points to implementation:', newImplementation);

    vm.stopBroadcast();
  }
}
