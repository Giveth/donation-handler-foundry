// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {DonationHandler} from '../src/contracts/DonationHandler.sol';
import {ProxyAdmin} from '@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol';
import {TransparentUpgradeableProxy} from '@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol';
import {Script} from 'forge-std/Script.sol';
import {console} from 'forge-std/console.sol';

contract DeployDonationHandler is Script {
  function run() external {
    uint256 deployerPrivateKey = vm.envUint('PRIVATE_KEY');

    vm.startBroadcast(deployerPrivateKey);

    DonationHandler donationHandler = new DonationHandler();

    ProxyAdmin proxyAdmin = new ProxyAdmin(address(this));
    TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
      address(donationHandler), address(proxyAdmin), abi.encodeWithSelector(DonationHandler.initialize.selector)
    );

    vm.stopBroadcast();
    console.log('DonationHandler Implementation deployed to:', address(donationHandler));
    console.log('ProxyAdmin deployed to:', address(proxyAdmin));
    console.log('TransparentUpgradeableProxy deployed to:', address(proxy));
  }
}
