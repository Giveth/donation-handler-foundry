// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {DonationHandler} from '../src/contracts/DonationHandler.sol';
import {ProxyAdmin} from '@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol';
import {ITransparentUpgradeableProxy} from '@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol';
import {Script} from 'forge-std/Script.sol';
import {console} from 'forge-std/console.sol';

contract UpgradeDonationHandler is Script {
  // ProxyAdmin addresses for each network
  address public constant ETHEREUM_PROXY_ADMIN = 0x7cD4eAAed06fA2270e0C063B7aBDa576a0ad149F;
  address public constant GNOSIS_PROXY_ADMIN = 0x076C250700D210e6cf8A27D1EB1Fd754FB487986;
  address public constant OPTIMISM_PROXY_ADMIN = 0x2f2c819210191750F2E11F7CfC5664a0eB4fd5e6;
  address public constant POLYGON_PROXY_ADMIN = 0x7a5D2A00a25b95fd8739bc52Cd79f8F971C37Ca1;

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

  // Helper function to upgrade on a specific network
  function upgradeOnEthereum(address proxyAddress) external {
    _upgrade(proxyAddress, ETHEREUM_PROXY_ADMIN);
  }

  function upgradeOnGnosis(address proxyAddress) external {
    _upgrade(proxyAddress, GNOSIS_PROXY_ADMIN);
  }

  function upgradeOnOptimism(address proxyAddress) external {
    _upgrade(proxyAddress, OPTIMISM_PROXY_ADMIN);
  }

  function upgradeOnPolygon(address proxyAddress) external {
    _upgrade(proxyAddress, POLYGON_PROXY_ADMIN);
  }

  function _upgrade(address proxyAddress, address proxyAdminAddress) internal {
    uint256 deployerPrivateKey = vm.envUint('PRIVATE_KEY');

    console.log('=== Upgrading DonationHandler ===');
    console.log('Proxy Address:', proxyAddress);
    console.log('ProxyAdmin Address:', proxyAdminAddress);

    vm.startBroadcast(deployerPrivateKey);

    DonationHandler newImplementation = new DonationHandler();
    console.log('New Implementation deployed to:', address(newImplementation));

    ProxyAdmin proxyAdmin = ProxyAdmin(proxyAdminAddress);
    proxyAdmin.upgradeAndCall(
      ITransparentUpgradeableProxy(proxyAddress),
      address(newImplementation),
      ''
    );

    console.log('Proxy upgraded successfully!');

    vm.stopBroadcast();
  }
}
