# DonationHandler Smart Contract

[![Tests](https://github.com/Giveth/donation-handler-foundry/actions/workflows/tests.yml/badge.svg)](https://github.com/Giveth/donation-handler-foundry/actions/workflows/tests.yml)

A flexible and secure smart contract system for handling both ETH and ERC20 token donations with support for single and batch transactions.

## Overview

The DonationHandler is an upgradeable smart contract that facilitates donations in both ETH and ERC20 tokens. It supports single donations as well as batch donations to multiple recipients, with optional data attachments for each transaction.

### Key Features

- **Multiple Asset Support**: Handle both ETH and ERC20 token donations
- **Batch Processing**: Efficiently process multiple donations in a single transaction
- **Upgradeable**: Uses OpenZeppelin's upgradeable contract pattern
- **Security Features**: 
  - Reentrancy protection
  - Input validation
  - Ownership controls
  - Custom error handling

### Core Functionality

1. **ETH Donations**
   - Single ETH donations via `donateETH()`
   - Batch ETH donations via `donateManyETH()`
   - Direct ETH transfers are prevented

2. **ERC20 Donations**
   - Single token donations via `donateERC20()`
   - Batch token donations via `donateManyERC20()`
   - Automatic allowance checking

### Security Measures

- ReentrancyGuard implementation
- Input validation for array lengths
- Zero address checks
- Amount validation
- ERC20 allowance verification
- Custom error handling for better gas efficiency

### Testing Coverage

The contract includes comprehensive test coverage for:
- Single ETH donations
- Multiple ETH donations
- Single ERC20 token donations
- Multiple ERC20 token donations
- Error cases and edge conditions
- Direct ETH transfer prevention
- Amount validation and sum verification (security fix)

All tests are automatically run on pull requests via GitHub Actions CI.

### Events

```solidity
event DonationMade(
    address indexed recipientAddress,
    uint256 amount,
    address indexed tokenAddress,
    bytes data
);
```

### Custom Errors

```solidity
error InvalidInput();
error InsufficientAllowance();
```

## Usage Examples

### Making a Single ETH Donation
```solidity
// Donate 1 ETH to a recipient
donationHandler.donateETH{value: 1 ether}(
    recipientAddress,
    1 ether,
    "0x" // Optional data
);
```

### Making Multiple ERC20 Donations
```solidity
// Batch donate tokens to multiple recipients
donationHandler.donateManyERC20(
    tokenAddress,
    totalAmount,
    recipientAddresses,
    amounts,
    data
);
```

## Technical Requirements

- Solidity ^0.8.0
- OpenZeppelin Contracts (Upgradeable)
- Foundry for testing and deployment

---

<img src="https://raw.githubusercontent.com/defi-wonderland/brand/v1.0.0/external/solidity-foundry-boilerplate-banner.png" alt="wonderland banner" align="center" />
<br />

<div align="center"><strong>Start your next Solidity project with Foundry in seconds</strong></div>
<div align="center">A highly scalable foundation focused on DX and best practices</div>

<br />

## Features

<dl>
  <dt>Sample contracts</dt>
  <dd>Basic Greeter contract with an external interface.</dd>

  <dt>Foundry setup</dt>
  <dd>Foundry configuration with multiple custom profiles and remappings.</dd>

  <dt>Deployment scripts</dt>
  <dd>Sample scripts to deploy contracts on both mainnet and testnet.</dd>

  <dt>Sample Integration, Unit, Property-based fuzzed and symbolic tests</dt>
  <dd>Example tests showcasing mocking, assertions and configuration for mainnet forking. As well it includes everything needed in order to check code coverage.</dd>
  <dd>Unit tests are built based on the <a href="https://twitter.com/PaulRBerg/status/1682346315806539776">Branched-Tree Technique</a>, using <a href="https://github.com/alexfertel/bulloak">Bulloak</a>.
  <dd>Formal verification and property-based fuzzing are achieved with <a href="https://github.com/a16z/halmos">Halmos</a> and <a href="https://github.com/crytic/medusa">Medusa</a> (resp.).

  <dt>Linter</dt>
  <dd>Simple and fast solidity linting thanks to forge fmt.</dd>
  <dd>Find missing natspec automatically.</dd>

  <dt>Github workflows CI</dt>
  <dd>Run all tests and see the coverage as you push your changes.</dd>
  <dd>Export your Solidity interfaces and contracts as packages, and publish them to NPM.</dd>
</dl>

## Setup

1. Install Foundry by following the instructions from [their repository](https://github.com/foundry-rs/foundry#installation).
2. Copy the `.env.example` file to `.env` and fill in the variables.
3. Install the dependencies by running: `yarn install`. In case there is an error with the commands, run `foundryup` and try them again.

## Build

The default way to build the code is suboptimal but fast, you can run it via:

```bash
yarn build
```

In order to build a more optimized code ([via IR](https://docs.soliditylang.org/en/v0.8.15/ir-breaking-changes.html#solidity-ir-based-codegen-changes)), run:

```bash
yarn build:optimized
```

## Running tests

Unit tests should be isolated from any externalities, while Integration usually run in a fork of the blockchain. In this boilerplate you will find example of both.

In order to run both unit and integration tests, run:

```bash
yarn test
```

In order to just run unit tests, run:

```bash
yarn test:unit
```

In order to run unit tests and run way more fuzzing than usual (5x), run:

```bash
yarn test:unit:deep
```

In order to just run integration tests, run:

```bash
yarn test:integration
```

In order to start the Medusa fuzzing campaign (requires [Medusa](https://github.com/crytic/medusa/blob/master/docs/src/getting_started/installation.md) installed), run:

```bash
yarn test:fuzz
```

In order to just run the symbolic execution tests (requires [Halmos](https://github.com/a16z/halmos/blob/main/README.md#installation) installed), run:

```bash
yarn test:symbolic
```

In order to check your current code coverage, run:

```bash
yarn coverage
```

<br>

## Deploy & verify

### Setup

Configure the `.env` variables and source them:

```bash
source .env
```

Import your private keys into Foundry's encrypted keystore:

```bash
cast wallet import $MAINNET_DEPLOYER_NAME --interactive
```

```bash
cast wallet import $SEPOLIA_DEPLOYER_NAME --interactive
```

### Sepolia

```bash
yarn deploy:sepolia
```

### Mainnet

```bash
yarn deploy:mainnet
```

The deployments are stored in ./broadcast

See the [Foundry Book for available options](https://book.getfoundry.sh/reference/forge/forge-create.html).


## Upgrading Existing Deployments

The DonationHandler uses **TransparentUpgradeableProxy**, allowing you to upgrade the implementation without deploying a new proxy. Users continue using the same address.

### 🎯 Quick Upgrade (Ethereum Mainnet)

```bash
# 1. Set up environment variables
export PRIVATE_KEY="your_private_key"
export PROXY_ADDRESS="0x97b2cb568e0880B99Cd16EFc6edFF5272Aa02676"
export PROXY_ADMIN_ADDRESS="0xECE9bE2e4b0c9a2C9E305feA6Ead25d310477409"
export MAINNET_RPC="your_rpc_url"

# 2. Test on fork first (SAFE - no real transactions)
yarn upgrade:mainnet:fork

# 3. If tests pass, upgrade on mainnet
yarn upgrade:mainnet
```

### 📋 Deployed Addresses

#### Ethereum Mainnet (Chain ID: 1)
- **Proxy**: `0x97b2cb568e0880B99Cd16EFc6edFF5272Aa02676` (users interact with this)
- **ProxyAdmin**: `0xECE9bE2e4b0c9a2C9E305feA6Ead25d310477409` (controls upgrades)

For other networks (Optimism, Gnosis, Polygon, Base, Celo), check your `broadcast/` folder.

### 🔧 Available Upgrade Scripts

```bash
# Upgrade on mainnet (requires PROXY_ADDRESS env var)
yarn upgrade:mainnet

# Test upgrade on fork before mainnet (recommended!)
yarn upgrade:mainnet:fork
```

### 📝 Manual Upgrade Process

If you prefer manual control:

```bash
# Deploy new implementation and upgrade proxy
forge script script/UpgradeDonationHandler.s.sol:UpgradeDonationHandler \
    --rpc-url $MAINNET_RPC \
    --broadcast \
    --verify \
    -vvvv
```

### ✅ Verify Upgrade

After upgrading, verify the new implementation:

```bash
# Check current implementation address
cast call $PROXY_ADDRESS "implementation()(address)" --rpc-url $MAINNET_RPC
```

### ⚠️ Important Notes

- **Test on fork first** - Always run `yarn upgrade:mainnet:fork` before mainnet
- **ProxyAdmin owner** - Ensure your account owns the ProxyAdmin contract
- **Gas costs** - Expect ~1.45M gas (~0.05-0.1 ETH depending on gas prices)
- **State preserved** - All existing data remains intact after upgrade
- **Same address** - Users continue using the same proxy address

### 🔄 What the Upgrade Does

The upgrade script:
1. Deploys a new `DonationHandler` implementation with bug fixes
2. Updates the proxy to point to the new implementation
3. Preserves all existing state and data
4. Maintains the same proxy address for users

See `script/UpgradeDonationHandler.s.sol` and `script/TestUpgrade.s.sol` for implementation details.

## Export And Publish

Export TypeScript interfaces from Solidity contracts and interfaces providing compatibility with TypeChain. Publish the exported packages to NPM.

To enable this feature, make sure you've set the `NPM_TOKEN` on your org's secrets. Then set the job's conditional to `true`:

```yaml
jobs:
  export:
    name: Generate Interfaces And Contracts
    # Remove the following line if you wish to export your Solidity contracts and interfaces and publish them to NPM
    if: true
    ...
```

Also, remember to update the `package_name` param to your package name:

```yaml
- name: Export Solidity - ${{ matrix.export_type }}
  uses: defi-wonderland/solidity-exporter-action@1dbf5371c260add4a354e7a8d3467e5d3b9580b8
  with:
    # Update package_name with your package name
    package_name: "my-cool-project"
    ...


- name: Publish to NPM - ${{ matrix.export_type }}
  # Update `my-cool-project` with your package name
  run: cd export/my-cool-project-${{ matrix.export_type }} && npm publish --access public
  ...
```

You can take a look at our [solidity-exporter-action](https://github.com/defi-wonderland/solidity-exporter-action) repository for more information and usage examples.

## Licensing
The primary license for the boilerplate is MIT, see [`LICENSE`](https://github.com/defi-wonderland/solidity-foundry-boilerplate/blob/main/LICENSE)
