#!/usr/bin/env bash
set -e

# Deploy DonationHandler implementation via CreateX CREATE2 (same address on each chain when init code matches).
# Usage: ./scripts/deploy-implementation.sh <chain>
# Requires .env: PRIVATE_KEY, <CHAIN>_RPC (e.g. BASE_RPC), ETHERSCAN_API_KEY for --verify
#
# Optional env for CreateX prefetch retries (RPC flake): CREATEX_MAX_ATTEMPTS (default 5), CREATEX_RETRY_DELAY_SEC (default 4).
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
CREATEX_MAX_ATTEMPTS="${CREATEX_MAX_ATTEMPTS:-5}"
CREATEX_RETRY_DELAY_SEC="${CREATEX_RETRY_DELAY_SEC:-4}"

createx_ok() {
  local code="$1"
  [[ -n "$code" && "$code" != "0x" && ${#code} -gt 10 ]]
}

attempt=1
CREATEX_CODE=""
while [[ $attempt -le $CREATEX_MAX_ATTEMPTS ]]; do
  err_file=$(mktemp)
  if CREATEX_CODE=$(cast code "$CREATEX_ADDRESS" --rpc-url "${!RPC_VAR}" 2>"$err_file"); then
    :
  fi
  if createx_ok "$CREATEX_CODE"; then
    rm -f "$err_file"
    break
  fi
  echo "Warning: CreateX prefetch attempt $attempt/$CREATEX_MAX_ATTEMPTS failed or returned empty."
  if [[ -s "$err_file" ]]; then
    echo "cast stderr:"
    cat "$err_file"
  fi
  rm -f "$err_file"
  if [[ $attempt -eq $CREATEX_MAX_ATTEMPTS ]]; then
    echo "Error: CreateX not available at $CREATEX_ADDRESS after $CREATEX_MAX_ATTEMPTS attempts (wrong chain, RPC down, or TLS/network flake)."
    exit 1
  fi
  sleep "$CREATEX_RETRY_DELAY_SEC"
  attempt=$((attempt + 1))
done

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
