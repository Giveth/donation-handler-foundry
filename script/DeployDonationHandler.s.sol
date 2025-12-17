// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {DonationHandler} from '../src/contracts/DonationHandler.sol';
import {ProxyAdmin} from '@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol';
import {TransparentUpgradeableProxy} from '@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol';
import {Script} from 'forge-std/Script.sol';
import {console} from 'forge-std/console.sol';

contract DeployDonationHandler is Script {
  address public constant ethereumProxyAdmin = 0x7cD4eAAed06fA2270e0C063B7aBDa576a0ad149F;
  address public constant gnosisProxyAdmin = 0x076C250700D210e6cf8A27D1EB1Fd754FB487986;
  address public constant optimismProxyAdmin = 0x2f2c819210191750F2E11F7CfC5664a0eB4fd5e6;
  address public constant polygonProxyAdmin = 0x7a5D2A00a25b95fd8739bc52Cd79f8F971C37Ca1;

  function run() external {
    uint256 deployerPrivateKey = vm.envUint('PRIVATE_KEY');

    vm.startBroadcast(deployerPrivateKey);

    DonationHandler donationHandler = new DonationHandler();

    ProxyAdmin proxyAdmin = new ProxyAdmin(msg.sender);
    TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
      address(donationHandler), address(proxyAdmin), abi.encodeWithSelector(DonationHandler.initialize.selector)
    );

    vm.stopBroadcast();
    console.log('DonationHandler Implementation deployed to:', address(donationHandler));
    console.log('ProxyAdmin deployed to:', address(proxyAdmin));
    console.log('TransparentUpgradeableProxy deployed to:', address(proxy));
  }
}
