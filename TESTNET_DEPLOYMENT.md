# Testnet Deployment & Upgrade Guide

This guide walks you through deploying DonationHandler to Sepolia testnet and testing the upgrade process before deploying to mainnet.

**Why Test on Testnet First?**
- Verify deployment scripts work correctly
- Test upgrade process without risk
- Validate contract behavior changes
- Estimate gas costs
- Catch issues before mainnet

**Scripts Used:**
- `script/DeployDonationHandler.s.sol` - Deploy to any network
- `script/UpgradeDonationHandler.s.sol` - Upgrade on any network

## Prerequisites

1. **Get Sepolia ETH** (for gas fees)
   - Visit [Sepolia Faucet](https://sepoliafaucet.com/)
   - Or [Alchemy Sepolia Faucet](https://sepoliafaucet.com/)
   - You'll need ~0.05 ETH for deployment + upgrade

2. **Get an Etherscan API Key** (for verification)
   - Sign up at [etherscan.io](https://etherscan.io/register)
   - Create API key at https://etherscan.io/myapikey

3. **Get a Sepolia RPC URL**
   - [Alchemy](https://www.alchemy.com/): Free tier available
   - [Infura](https://www.infura.io/): Free tier available
   - Or use public RPC: `https://rpc.sepolia.org`

## Step 1: Configure Environment

Edit your `.env` file:

```bash
# Add these to your .env file
PRIVATE_KEY=your_private_key_here
SEPOLIA_RPC=https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY
ETHERSCAN_API_KEY=your_etherscan_api_key

# These will be set after deployment
# PROXY_ADDRESS=
# PROXY_ADMIN_ADDRESS=
```

**⚠️ Security Note**: Never commit your `.env` file with real private keys!

## Step 2: Check Your Balance

```bash
# Source your environment
source .env

# Check your balance on Sepolia
cast balance $(cast wallet address --private-key $PRIVATE_KEY) --rpc-url $SEPOLIA_RPC
```

You should see at least `50000000000000000` (0.05 ETH).

## Step 3: Deploy to Sepolia

```bash
# Deploy the contract
yarn deploy:sepolia
```

**Expected Output:**
```
=== Deploying DonationHandler to Sepolia ===
Deployer: 0x...
Implementation deployed to: 0x...
Proxy deployed to: 0x...
ProxyAdmin deployed to: 0x...

=== Save these addresses for upgrading! ===
export PROXY_ADDRESS= 0x...
export PROXY_ADMIN_ADDRESS= 0x...
```

## Step 4: Save Deployment Addresses

Copy the addresses from the output and add them to your `.env` file:

```bash
# Add these to .env
PROXY_ADDRESS=0x...          # Copy from "Proxy deployed to"
PROXY_ADMIN_ADDRESS=0x...    # Copy from "ProxyAdmin deployed to"
```

Or use the export commands directly:

```bash
export PROXY_ADDRESS=0x...
export PROXY_ADMIN_ADDRESS=0x...
```

## Step 5: View on Etherscan

1. Go to https://sepolia.etherscan.io/address/YOUR_PROXY_ADDRESS
2. You should see:
   - Contract creation transaction
   - Contract code (if verification succeeded)
   - Ability to interact with the contract through the UI

## Step 6: Verify Deployment on Etherscan

1. Go to https://sepolia.etherscan.io/address/YOUR_PROXY_ADDRESS
2. Check that the contract is verified
3. View the contract's state and functions

## Step 7: Test the Deployed Contract (Optional but Recommended)

Test basic functionality to ensure the contract works:

```bash
# Example: Make a simple donation
cast send $PROXY_ADDRESS \
  "donateETH(address,uint256,bytes)" \
  0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb \
  1000000000000000 \
  0x \
  --value 0.001ether \
  --private-key $PRIVATE_KEY \
  --rpc-url $SEPOLIA_RPC
```

Check the transaction on Etherscan to verify it succeeded.

## Step 8: Record Current Implementation Address

Before upgrading, save the current implementation address:

```bash
# Get current implementation address
OLD_IMPL=$(cast call $PROXY_ADDRESS "0x5c60da1b" --rpc-url $SEPOLIA_RPC)
echo "Old Implementation: $OLD_IMPL"
```

This will change after the upgrade, proving the upgrade worked.

## Step 9: Upgrade the Contract

Now upgrade to the new implementation:

```bash
# Make sure PROXY_ADDRESS and PROXY_ADMIN_ADDRESS are set
source .env

# Perform the upgrade
yarn upgrade:sepolia
```

**Expected Output:**
```
=== Upgrading DonationHandler ===
Proxy Address: 0x...
ProxyAdmin Address: 0x...
New Implementation deployed to: 0x...
Proxy upgraded successfully!
```

## Step 10: Verify the Upgrade Succeeded

**Check 1: Implementation Address Changed**

```bash
# Get new implementation address
NEW_IMPL=$(cast call $PROXY_ADDRESS "0x5c60da1b" --rpc-url $SEPOLIA_RPC)
echo "New Implementation: $NEW_IMPL"

# Compare with old implementation from Step 8
# They should be DIFFERENT
```

**Check 2: Proxy Address Unchanged**

The proxy address should be the same - users don't need to update anything.

**Check 3: Contract State Preserved**

The contract owner and all state should remain unchanged:

```bash
# Check owner is still the same
cast call $PROXY_ADDRESS "owner()(address)" --rpc-url $SEPOLIA_RPC
```

**Check 4: Test Your Changes**

Test the specific changes you made in this upgrade. This depends on what you changed:

**Example A: Testing a bug fix**
```bash
# Try the scenario that was broken before
# It should now work correctly or revert with proper error
```

**Example B: Testing a new feature**
```bash
# Call the new function you added
cast send $PROXY_ADDRESS "newFunction(...)" ...
```

**Example C: Testing existing functionality still works**
```bash
# Make sure nothing broke
cast send $PROXY_ADDRESS \
  "donateETH(address,uint256,bytes)" \
  0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb \
  1000000000000000 \
  0x \
  --value 0.001ether \
  --private-key $PRIVATE_KEY \
  --rpc-url $SEPOLIA_RPC
```

If all checks pass, your upgrade is successful! ✅

## Step 11: Document Your Changes (Recommended)

Before deploying to mainnet, document:

1. **What changed** - List all modifications made to the implementation
2. **Why it changed** - Reason for the upgrade (bug fix, new feature, optimization)
3. **Testing results** - What you tested on testnet and the results
4. **Gas impact** - Compare gas costs before/after if relevant
5. **Breaking changes** - Any changes that affect how users interact with the contract

This documentation helps with:
- Team review before mainnet deployment
- Communicating changes to users
- Future reference when doing more upgrades

## Troubleshooting

### "Insufficient funds"
- Check your balance: `cast balance $(cast wallet address --private-key $PRIVATE_KEY) --rpc-url $SEPOLIA_RPC`
- Get more Sepolia ETH from a faucet

### "Invalid API Key"
- Verify your Etherscan API key is correct in `.env`
- Make sure you're using the API key, not the secret key

### "Proxy address not set"
- Make sure you added `PROXY_ADDRESS` to your `.env` file after deployment
- Run `source .env` to reload environment variables

### "Upgrade failed" or Permission Denied
- Verify you own the ProxyAdmin: `cast call $PROXY_ADMIN_ADDRESS "owner()(address)" --rpc-url $SEPOLIA_RPC`
- The returned address should match your deployer address
- If not, you're using the wrong private key or someone else owns the ProxyAdmin

### "Implementation didn't change"
- Check that the upgrade transaction succeeded on Etherscan
- Verify you're calling the correct proxy address
- Make sure the upgrade script completed without errors

### Contract behaves the same after upgrade
- Confirm you actually made changes to the implementation
- Check that you deployed a new implementation (not reusing old one)
- Verify the implementation address actually changed

## Summary

✅ **What You Accomplished:**
1. ✅ Deployed DonationHandler implementation to testnet
2. ✅ Deployed TransparentUpgradeableProxy (ProxyAdmin created automatically)
3. ✅ Upgraded proxy to new implementation
4. ✅ Verified implementation changed
5. ✅ Confirmed proxy address unchanged (important for users!)
6. ✅ Validated contract state preserved
7. ✅ Tested new functionality works

✅ **Understanding the Upgrade Pattern:**

**What Stays the Same:**
- ✅ Proxy address - Users keep using the same address
- ✅ ProxyAdmin address - Upgrade permissions unchanged
- ✅ Contract state - All data preserved (owner, balances, etc.)
- ✅ User experience - No action needed from users

**What Changes:**
- ✅ Implementation address - Points to new code
- ✅ Contract logic - New features/fixes active
- ✅ Gas costs - May differ slightly with new code

This is exactly how upgrades work on mainnet! The testnet deployment lets you verify everything before risking real funds. 🚀

## Next Steps: Deploying to Mainnet

Once you've successfully tested on Sepolia:

### 1. Review and Prepare
- ✅ All tests passed on testnet
- ✅ Changes documented
- ✅ Team reviewed the upgrade
- ✅ Gas costs are acceptable
- ✅ No breaking changes for users

### 2. Test on Mainnet Fork (Strongly Recommended)
```bash
# Test upgrade on a mainnet fork before real deployment
yarn upgrade:mainnet:simulate
```

This runs against mainnet state without sending real transactions - catches issues specific to mainnet.

### 3. Deploy to Mainnet
```bash
# When you're ready, follow the same process:
# 1. If first deployment:
#    yarn deploy:mainnet (or your existing deployment process)
#
# 2. For upgrades:
#    yarn upgrade:mainnet

# IMPORTANT: Double-check you have the correct PROXY_ADDRESS
```

### 4. Verify on Mainnet
- Check implementation address changed
- Verify on Etherscan
- Test with a small transaction first
- Monitor for any issues

### 5. Communicate (if needed)
- Notify users if there are changes they need to know about
- Update documentation
- Announce new features

## Best Practices

✅ **Always test on testnet first**
✅ **Use fork testing before mainnet**
✅ **Have a rollback plan** (know the old implementation address)
✅ **Monitor after deployment**
✅ **Start with small transactions** to verify everything works
✅ **Document every upgrade**
