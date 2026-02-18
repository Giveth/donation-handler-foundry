// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {DonationHandler} from '../src/contracts/DonationHandler.sol';
import {ProxyAdmin} from '@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol';
import {TransparentUpgradeableProxy} from '@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol';
import {Script} from 'forge-std/Script.sol';
import {console} from 'forge-std/console.sol';

contract DeployDonationHandler is Script {
  address public constant ETHEREUM_PROXY_ADMIN = 0x7cD4eAAed06fA2270e0C063B7aBDa576a0ad149F;
  address public constant GNOSIS_PROXY_ADMIN = 0x076C250700D210e6cf8A27D1EB1Fd754FB487986;
  address public constant OPTIMISM_PROXY_ADMIN = 0x2f2c819210191750F2E11F7CfC5664a0eB4fd5e6;
  address public constant POLYGON_PROXY_ADMIN = 0x7a5D2A00a25b95fd8739bc52Cd79f8F971C37Ca1;

  function run() external {
    uint256 deployerPrivateKey = vm.envUint('PRIVATE_KEY');
    address deployer = vm.addr(deployerPrivateKey);

    console.log('=== Deploying DonationHandler ===');
    console.log('Deployer:', deployer);
    console.log('Deployer balance:', deployer.balance);

    vm.startBroadcast(deployerPrivateKey);

    // Deploy implementation
    DonationHandler implementation = new DonationHandler();
    console.log('Implementation deployed to:', address(implementation));

    // Deploy proxy (ProxyAdmin created automatically)
    TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
      address(implementation), deployer, abi.encodeWithSelector(DonationHandler.initialize.selector)
    );
    console.log('Proxy deployed to:', address(proxy));

    // Get ProxyAdmin address
    bytes32 adminSlot = bytes32(uint256(keccak256('eip1967.proxy.admin')) - 1);
    address proxyAdmin = address(uint160(uint256(vm.load(address(proxy), adminSlot))));
    console.log('ProxyAdmin deployed to:', proxyAdmin);

    vm.stopBroadcast();

    console.log('\n=== Deployment Summary ===');
    console.log('Implementation:', address(implementation));
    console.log('Proxy:', address(proxy));
    console.log('ProxyAdmin:', proxyAdmin);
    console.log('\n=== Save these for upgrading ===');
    console.log('export PROXY_ADDRESS=', address(proxy));
    console.log('export PROXY_ADMIN_ADDRESS=', proxyAdmin);
  }
}
