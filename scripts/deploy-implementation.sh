#!/usr/bin/env bash
set -e

# Deploy DonationHandler implementation via CreateX CREATE2 (same address on each chain when init code matches).
# Usage: ./scripts/deploy-implementation.sh <chain>
# Requires .env: PRIVATE_KEY, <CHAIN>_RPC (e.g. BASE_RPC), ETHERSCAN_API_KEY for --verify
#
# Build uses FOUNDRY_PROFILE=deterministic — see foundry.toml (must match manual forge script runs).
# Chain names match foundry.toml [rpc_endpoints] keys (mainnet, base, sepolia, ...).
#
# Before deploying, ensure CreateX exists on the chain, e.g.:
#   cast code 0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed --rpc-url "$BASE_RPC"
# (non-empty code). The Solidity script also reverts if CreateX is missing.

CHAIN="${1:?Usage: deploy-implementation.sh <chain> (e.g. base, mainnet, sepolia)}"

cd "$(dirname "$0")/.."
source .env

RPC_SUFFIX=$(echo "$CHAIN" | tr '[:lower:]' '[:upper:]' | tr '-' '_')
RPC_VAR="${RPC_SUFFIX}_RPC"

if [[ -z "${!RPC_VAR}" ]]; then
  echo "Error: $RPC_VAR is not set in .env"
  exit 1
fi

CREATEX_ADDRESS="0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed"
CREATEX_CODE=$(cast code "$CREATEX_ADDRESS" --rpc-url "${!RPC_VAR}" 2>/dev/null || true)
if [[ -z "$CREATEX_CODE" || "$CREATEX_CODE" == "0x" ]]; then
  echo "Error: CreateX not deployed at $CREATEX_ADDRESS on this RPC (cast code returned empty)."
  exit 1
fi

LEGACY_CHAINS="celo gnosis"
LEGACY_FLAG=""
if [[ " $LEGACY_CHAINS " == *" $CHAIN "* ]]; then
  LEGACY_FLAG="--legacy"
fi

export FOUNDRY_PROFILE=deterministic

forge script script/DeployDonationHandlerImplementation.s.sol:DeployDonationHandlerImplementation \
  --rpc-url "${!RPC_VAR}" \
  --broadcast \
  --verify \
  --chain "$CHAIN" \
  $LEGACY_FLAG \
  -vvvv
