// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/// @notice Deploys and verifies only the DonationHandler implementation (no proxy, no upgrade).
/// Use this when you are not the ProxyAdmin owner: deploy + verify, then give the implementation
/// address to the owner so they can call proxyAdmin.upgrade(proxy, implementationAddress).

import {DonationHandler} from '../src/contracts/DonationHandler.sol';
import {Script} from 'forge-std/Script.sol';
import {console} from 'forge-std/console.sol';

contract DeployDonationHandlerImplementation is Script {
  function run() external {
    uint256 deployerPrivateKey = vm.envUint('PRIVATE_KEY');

    console.log('=== Deploying DonationHandler implementation only ===');

    vm.startBroadcast(deployerPrivateKey);

    DonationHandler implementation = new DonationHandler();
    console.log('Implementation deployed to:', address(implementation));

    vm.stopBroadcast();

    console.log('\n=== Hand off to proxy owner ===');
    console.log('Give this address to the ProxyAdmin owner to run:');
    console.log('  proxyAdmin.upgrade(proxy,', address(implementation), ')');
    console.log('export NEW_IMPLEMENTATION_ADDRESS=', address(implementation));
  }
}
