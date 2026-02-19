# Production Upgrade Guide

This guide covers upgrading DonationHandler on all production networks.

## 🎯 Networks to Upgrade

Based on your deployments:
- ✅ Ethereum Mainnet (Chain ID: 1)
- ✅ Optimism (Chain ID: 10)
- ✅ Gnosis (Chain ID: 100)
- ✅ Base (Chain ID: 8453)
- ✅ Celo (Chain ID: 42220)

## 📋 Pre-Upgrade Checklist

- [ ] Successfully tested on Sepolia testnet
- [ ] All tests pass: `forge test -vvv`
- [ ] Code reviewed by team
- [ ] Changes documented in BUG_FIX_SUMMARY.md
- [ ] Fork test passed on mainnet
- [ ] Gas costs acceptable (~1.5M gas per network)
- [ ] Have sufficient ETH/native tokens on all networks

## 🔍 Step 1: Find Your Proxy Addresses

Your proxy addresses are in the broadcast folder. Let's extract them:

```bash
# Ethereum Mainnet (Chain ID: 1)
ETHEREUM_PROXY=0x97b2cb568e0880B99Cd16EFc6edFF5272Aa02676
ETHEREUM_PROXY_ADMIN=0xECE9bE2e4b0c9a2C9E305feA6Ead25d310477409

# Check other networks in your broadcast folder:
cat broadcast/DeployDonationHandler.s.sol/10/run-latest.json | grep "contractAddress"  # Optimism
cat broadcast/DeployDonationHandler.s.sol/100/run-latest.json | grep "contractAddress"  # Gnosis
cat broadcast/DeployDonationHandler.s.sol/8453/run-latest.json | grep "contractAddress"  # Base
cat broadcast/DeployDonationHandler.s.sol/42220/run-latest.json | grep "contractAddress"  # Celo
```

## 🚀 Step 2: Upgrade Ethereum Mainnet (Most Critical)

### 2.1 Test on Fork First

```bash
# Set environment
export PROXY_ADDRESS=0x97b2cb568e0880B99Cd16EFc6edFF5272Aa02676
export PROXY_ADMIN_ADDRESS=0xECE9bE2e4b0c9a2C9E305feA6Ead25d310477409
export MAINNET_RPC=your_mainnet_rpc_url

# Test on fork (SAFE - no real transactions)
yarn upgrade:mainnet:fork
```

**Expected Output:**
```
=== Upgrading DonationHandler ===
Proxy Address: 0x97b2cb568e0880B99Cd16EFc6edFF5272Aa02676
...
Proxy upgraded successfully!
```

### 2.2 Deploy to Mainnet

If fork test passes:

```bash
# REAL DEPLOYMENT - Double check everything!
source .env
yarn upgrade:mainnet
```

### 2.3 Verify Mainnet Upgrade

```bash
# Check implementation changed
cast call $PROXY_ADDRESS "0x5c60da1b" --rpc-url $MAINNET_RPC

# Check on Etherscan
# Go to: https://etherscan.io/address/0x97b2cb568e0880B99Cd16EFc6edFF5272Aa02676

# Test with small transaction first
cast send $PROXY_ADDRESS \
  "donateETH(address,uint256,bytes)" \
  0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb \
  100000000000000 \
  0x \
  --value 0.0001ether \
  --private-key $PRIVATE_KEY \
  --rpc-url $MAINNET_RPC
```

## 🌐 Step 3: Upgrade Other Networks

Once Ethereum mainnet is successful, upgrade other networks.

### Optimism (Chain ID: 10)

```bash
# Setup
export PROXY_ADDRESS=YOUR_OPTIMISM_PROXY
export PROXY_ADMIN_ADDRESS=YOUR_OPTIMISM_PROXY_ADMIN
export OPTIMISM_RPC=your_optimism_rpc

# Upgrade
forge script script/UpgradeDonationHandler.s.sol:UpgradeDonationHandler \
  --rpc-url $OPTIMISM_RPC \
  --broadcast \
  --verify \
  -vvvv

# Verify on Optimistic Etherscan
# https://optimistic.etherscan.io/address/YOUR_PROXY
```

### Gnosis (Chain ID: 100)

```bash
# Setup
export PROXY_ADDRESS=YOUR_GNOSIS_PROXY
export PROXY_ADMIN_ADDRESS=0x076C250700D210e6cf8A27D1EB1Fd754FB487986
export GNOSIS_RPC=https://rpc.gnosischain.com

# Upgrade
forge script script/UpgradeDonationHandler.s.sol:UpgradeDonationHandler \
  --rpc-url $GNOSIS_RPC \
  --broadcast \
  --verify \
  -vvvv

# Verify on Gnosis Explorer
# https://gnosisscan.io/address/YOUR_PROXY
```

### Base (Chain ID: 8453)

```bash
# Setup
export PROXY_ADDRESS=YOUR_BASE_PROXY
export PROXY_ADMIN_ADDRESS=YOUR_BASE_PROXY_ADMIN
export BASE_RPC=https://mainnet.base.org

# Upgrade
forge script script/UpgradeDonationHandler.s.sol:UpgradeDonationHandler \
  --rpc-url $BASE_RPC \
  --broadcast \
  --verify \
  -vvvv

# Verify on Base Explorer
# https://basescan.org/address/YOUR_PROXY
```

### Celo (Chain ID: 42220)

```bash
# Setup
export PROXY_ADDRESS=YOUR_CELO_PROXY
export PROXY_ADMIN_ADDRESS=YOUR_CELO_PROXY_ADMIN
export CELO_RPC=https://forno.celo.org

# Upgrade
forge script script/UpgradeDonationHandler.s.sol:UpgradeDonationHandler \
  --rpc-url $CELO_RPC \
  --broadcast \
  --verify \
  -vvvv

# Verify on Celo Explorer
# https://celoscan.io/address/YOUR_PROXY
```

## ✅ Step 4: Post-Upgrade Verification (All Networks)

For each network, verify:

### 1. Implementation Changed
```bash
# Get new implementation
cast call $PROXY_ADDRESS "0x5c60da1b" --rpc-url $RPC_URL
# Should be different from before
```

### 2. Contract Works
```bash
# Test with small transaction
cast send $PROXY_ADDRESS \
  "donateETH(address,uint256,bytes)" \
  TEST_ADDRESS \
  SMALL_AMOUNT \
  0x \
  --value SMALL_AMOUNT \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL
```

### 3. New Validation Works (Bug Fix Specific)
```bash
# This should REVERT with "Amounts do not match total"
cast send $PROXY_ADDRESS \
  "donateManyETH(uint256,address[],uint256[],bytes[])" \
  1000000000000000000 \
  "[0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb]" \
  "[800000000000000000]" \
  "[]" \
  --value 1ether \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL
```

## 📊 Step 5: Monitor & Document

### Monitor Each Network
- Check block explorers for upgrade transactions
- Monitor for any unusual activity
- Watch for user-reported issues

### Document Deployment
Create a deployment record:

```markdown
## Upgrade: Bug Fix - Amount Validation
Date: [DATE]
Deployed by: [YOUR_ADDRESS]

### Networks Upgraded:
- [x] Ethereum: 0x... (Block: ..., Tx: ...)
- [x] Optimism: 0x... (Block: ..., Tx: ...)
- [x] Gnosis: 0x... (Block: ..., Tx: ...)
- [x] Base: 0x... (Block: ..., Tx: ...)
- [x] Celo: 0x... (Block: ..., Tx: ...)

### Implementation Addresses:
- Ethereum: 0x...
- Optimism: 0x...
- Gnosis: 0x...
- Base: 0x...
- Celo: 0x...

### Changes:
- Added amount sum validation in donateManyETH
- Added amount sum validation in donateManyERC20
- Prevents fund lockup and theft vulnerability

### Testing:
- ✅ All 42 tests pass
- ✅ Tested on Sepolia
- ✅ Fork tested on mainnet
- ✅ Verified on all networks

### Gas Costs:
- Deploy implementation: ~1.4M gas
- Upgrade: ~50k gas
```

## ⚠️ Emergency Procedures

### If Something Goes Wrong

**Option 1: Rollback (if needed)**
```bash
# Can rollback to previous implementation if needed
# You saved the old implementation address, right?

cast send $PROXY_ADMIN_ADDRESS \
  "upgradeAndCall(address,address,bytes)" \
  $PROXY_ADDRESS \
  $OLD_IMPLEMENTATION_ADDRESS \
  0x \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL
```

**Option 2: Pause & Investigate**
- Document the issue immediately
- Check transaction history on block explorer
- Compare behavior on working vs. failing network
- Test on fork to reproduce issue

## 🎉 Success Checklist

After all networks are upgraded:

- [ ] All implementations verified on block explorers
- [ ] Tested on all networks with real transactions
- [ ] Bug fix works as expected (rejects invalid amounts)
- [ ] Normal operations work correctly
- [ ] No funds stuck in contracts
- [ ] Documentation updated
- [ ] Team notified
- [ ] Users informed (if necessary)

## 💡 Tips

1. **Start with Ethereum** - It's your most critical network
2. **Upgrade one network at a time** - Easier to troubleshoot
3. **Monitor between upgrades** - Wait 10-15 minutes, check for issues
4. **Save all transaction hashes** - For documentation and troubleshooting
5. **Test after each upgrade** - Don't assume it works
6. **Keep old implementation addresses** - In case you need to rollback

## 📞 Support

If you encounter issues:
1. Check the Troubleshooting section in TESTNET_DEPLOYMENT.md
2. Review transaction on block explorer
3. Test on fork to reproduce
4. Check ProxyAdmin ownership
5. Verify gas prices aren't too high

Remember: Take your time, verify each step, and don't rush! 🚀
