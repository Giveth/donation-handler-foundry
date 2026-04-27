#!/usr/bin/env bash
set -e

# Deploy DonationHandler implementation only (no proxy, no upgrade).
# Usage: ./scripts/deploy-implementation.sh <chain>
# Example: yarn deploy:implementation base   (run from repo root with: yarn deploy:implementation -- base)
#
# Chain is passed as first argument. RPC URL is read from env: <CHAIN>_RPC (e.g. BASE_RPC, MAINNET_RPC).
# Ensure the chain is in foundry.toml [rpc_endpoints] and [etherscan] for verification.

CHAIN="${1:?Usage: deploy-implementation.sh <chain> (e.g. base, mainnet, sepolia)}"

cd "$(dirname "$0")/.."
source .env

# Derive RPC env var from chain name: base -> BASE_RPC, mainnet -> MAINNET_RPC
RPC_SUFFIX=$(echo "$CHAIN" | tr '[:lower:]' '[:upper:]' | tr '-' '_')
RPC_VAR="${RPC_SUFFIX}_RPC"

if [[ -z "${!RPC_VAR}" ]]; then
  echo "Error: $RPC_VAR is not set in .env"
  exit 1
fi

# Chains that don't support EIP-1559 / eth_feeHistory need legacy transactions
LEGACY_CHAINS="celo gnosis"
LEGACY_FLAG=""
if [[ " $LEGACY_CHAINS " == *" $CHAIN "* ]]; then
  LEGACY_FLAG="--legacy"
fi

forge script script/DeployDonationHandlerImplementation.s.sol:DeployDonationHandlerImplementation \
  --rpc-url "${!RPC_VAR}" \
  --broadcast \
  --verify \
  --chain "$CHAIN" \
  $LEGACY_FLAG \
  -vvvv
