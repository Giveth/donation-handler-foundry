// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/// @notice Deploy DonationHandler implementation via CreateX CREATE2 so the address matches across chains.
/// @dev Build with `FOUNDRY_PROFILE=deterministic` (see foundry.toml) so init code is identical everywhere.
/// See https://www.getfoundry.sh/guides/deterministic-deployments-using-create2

import {DonationHandler} from '../src/contracts/DonationHandler.sol';
import {Script, console} from 'forge-std/Script.sol';

interface ICreateX {
  function deployCreate2(bytes32 salt, bytes memory initCode) external payable returns (address deployed);
  function computeCreate2Address(bytes32 salt, bytes32 initCodeHash) external view returns (address computed);
}

contract DeployDonationHandlerImplementation is Script {
  /// @dev CreateX factory at the same address on supported chains.
  ICreateX internal constant CREATEX = ICreateX(0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed);

  /// @dev Bump version when starting a new implementation lineage (changes CREATE2 address).
  bytes32 internal constant IMPLEMENTATION_SALT = keccak256('donation-handler.implementation.v1');

  function run() external {
    uint256 deployerPrivateKey = vm.envUint('PRIVATE_KEY');

    require(address(CREATEX).code.length > 0, 'CreateX not deployed on this chain');

    bytes memory initCode = type(DonationHandler).creationCode;
    bytes32 initCodeHash = keccak256(initCode);

    address predicted = CREATEX.computeCreate2Address(IMPLEMENTATION_SALT, initCodeHash);

    console.log('=== CREATE2 DonationHandler implementation (CreateX) ===');
    console.log('Predicted address:', predicted);

    vm.startBroadcast(deployerPrivateKey);

    address deployed = CREATEX.deployCreate2(IMPLEMENTATION_SALT, initCode);

    vm.stopBroadcast();

    require(deployed == predicted, 'CREATE2 address mismatch');
    console.log('Deployed at:', deployed);
    console.log('Upgrade via ProxyAdmin.upgradeAndCall(proxy, implementation, 0x) when ready.');
  }
}
