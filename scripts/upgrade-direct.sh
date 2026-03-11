#!/usr/bin/env bash
set -e

# Direct upgrade: call ProxyAdmin.upgradeAndCall with an already-deployed implementation.
# Use when the ProxyAdmin owner is an EOA (your PRIVATE_KEY), not a Safe.
#
# Usage: ./scripts/upgrade-direct.sh <chain> [--simulate]
# Example: yarn upgrade:direct polygon
#          yarn upgrade:direct polygon --simulate
#
# Chain is first argument. RPC from env: <CHAIN>_RPC (e.g. POLYGON_RPC, BASE_RPC).
# Required env: PRIVATE_KEY (EOA that owns ProxyAdmin), PROXY_ADDRESS, PROXY_ADMIN_ADDRESS,
#               NEW_IMPLEMENTATION_ADDRESS (from yarn deploy:implementation <chain>).

CHAIN="${1:?Usage: upgrade-direct.sh <chain> [--simulate] (e.g. polygon, base, mainnet, sepolia)}"
SIMULATE=""
if [[ "${2:-}" == "--simulate" ]]; then
  SIMULATE="1"
fi

cd "$(dirname "$0")/.."
source .env

# Derive RPC env var from chain name: base -> BASE_RPC, mainnet -> MAINNET_RPC
RPC_SUFFIX=$(echo "$CHAIN" | tr '[:lower:]' '[:upper:]' | tr '-' '_')
RPC_VAR="${RPC_SUFFIX}_RPC"

if [[ -z "${!RPC_VAR}" ]]; then
  echo "Error: $RPC_VAR is not set in .env"
  exit 1
fi

if [[ -z "${PRIVATE_KEY:-}" ]]; then
  echo "Error: PRIVATE_KEY is not set in .env (must be the EOA that owns ProxyAdmin)"
  exit 1
fi

if [[ -z "${PROXY_ADDRESS:-}" ]]; then
  echo "Error: PROXY_ADDRESS is not set in .env"
  exit 1
fi

if [[ -z "${PROXY_ADMIN_ADDRESS:-}" ]]; then
  echo "Error: PROXY_ADMIN_ADDRESS is not set in .env"
  exit 1
fi

if [[ -z "${NEW_IMPLEMENTATION_ADDRESS:-}" ]]; then
  echo "Error: NEW_IMPLEMENTATION_ADDRESS is not set in .env (deploy with: yarn deploy:implementation <chain>)"
  exit 1
fi

# Chains that don't support EIP-1559 need legacy transactions
LEGACY_CHAINS="celo gnosis"
LEGACY_FLAG=""
if [[ " $LEGACY_CHAINS " == *" $CHAIN "* ]]; then
  LEGACY_FLAG="--legacy"
fi

if [[ -n "$SIMULATE" ]]; then
  echo "Simulating upgrade on $CHAIN (no broadcast)..."
  forge script script/UpgradeDonationHandler.s.sol:UpgradeDonationHandler \
    --fork-url "${!RPC_VAR}" \
    --chain "$CHAIN" \
    $LEGACY_FLAG \
    -vvvv
else
  echo "Running direct upgrade on $CHAIN..."
  forge script script/UpgradeDonationHandler.s.sol:UpgradeDonationHandler \
    --rpc-url "${!RPC_VAR}" \
    --broadcast \
    --chain "$CHAIN" \
    $LEGACY_FLAG \
    -vvvv
fi
