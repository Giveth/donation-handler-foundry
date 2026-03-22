#!/usr/bin/env bash
set -e

# Generate the DonationHandler upgrade transaction payload for the multisig.
# Outputs calldata and a Safe Transaction Builder JSON so you can create the proposal in Safe.
#
# Usage:
#   ./scripts/generate-upgrade-payload.sh <proxy_admin> <proxy> <new_implementation> [safe_address] [chain]
# Or set env vars: PROXY_ADMIN_ADDRESS, PROXY_ADDRESS, NEW_IMPLEMENTATION_ADDRESS
# Optional: SAFE_ADDRESS, CHAIN (for Safe app link)
#
# Example:
#   NEW_IMPLEMENTATION_ADDRESS=0x... ./scripts/generate-upgrade-payload.sh 0xProxyAdmin 0xProxy
#   ./scripts/generate-upgrade-payload.sh 0xAdmin 0xProxy 0xImpl 0xSafeAddress mainnet

cd "$(dirname "$0")/.."

PROXY_ADMIN="${1:-${PROXY_ADMIN_ADDRESS:?}}"
PROXY="${2:-${PROXY_ADDRESS:?}}"
NEW_IMPL="${3:-${NEW_IMPLEMENTATION_ADDRESS:?}}"
SAFE_ADDRESS="${4:-${SAFE_ADDRESS}}"
CHAIN="${5:-${CHAIN:-mainnet}}"

# Normalize chain to Safe app slug (eth, base, arbitrum, etc.)
SAFE_CHAIN_SLUG="$CHAIN"
case "$CHAIN" in
  mainnet) SAFE_CHAIN_SLUG="eth" ;;
  polygon) SAFE_CHAIN_SLUG="matic" ;;
  arbitrum) SAFE_CHAIN_SLUG="arbitrum" ;;
  optimism) SAFE_CHAIN_SLUG="oeth" ;;
  base) SAFE_CHAIN_SLUG="base" ;;
  gnosis) SAFE_CHAIN_SLUG="gno" ;;
  celo) SAFE_CHAIN_SLUG="celo" ;;
esac

# Build calldata: upgradeAndCall(address proxy, address implementation, bytes data)
# Use empty bytes so the upgrade only switches implementation and does not run initialize().
CALLDATA=$(cast calldata "upgradeAndCall(address,address,bytes)" "$PROXY" "$NEW_IMPL" "0x")

echo ""
echo "=============================================="
echo "  DonationHandler upgrade — multisig payload"
echo "=============================================="
echo ""
echo "  To (Contract):  $PROXY_ADMIN"
echo "  Value:          0"
echo "  Data (calldata): $CALLDATA"
echo ""
echo "  Function: upgradeAndCall(address proxy, address implementation, bytes data)"
echo "    proxy:         $PROXY"
echo "    implementation: $NEW_IMPL"
echo "    data:          0x"
echo ""
echo "=============================================="
echo "  How to propose in Safe"
echo "=============================================="
echo ""
if [[ -n "$SAFE_ADDRESS" ]]; then
  echo "  1. Open your Safe: https://app.safe.global/home?safe=${SAFE_CHAIN_SLUG}:${SAFE_ADDRESS}"
else
  echo "  1. Open your Safe (replace <SAFE_ADDRESS> with your multisig address):"
  echo "     https://app.safe.global/home?safe=${SAFE_CHAIN_SLUG}:<SAFE_ADDRESS>"
fi
echo "  2. New transaction → Contract interaction"
echo "  3. Contract address: $PROXY_ADMIN"
echo "  4. Use ABI: upgradeAndCall(address,address,bytes) with:"
echo "       proxy         = $PROXY"
echo "       implementation = $NEW_IMPL"
echo "       data          = 0x"
echo "  5. Or paste Raw data (hex): $CALLDATA"
echo "  6. Value: 0 → Create transaction"
echo ""

# Write JSON for Safe Transaction Builder (Apps → Transaction Builder → Import)
OUTPUT_JSON="${MULTISIG_PROPOSAL_JSON:-./upgrade-payload.json}"
cat > "$OUTPUT_JSON" << EOF
{
  "version": "1.0",
  "chainId": "$CHAIN",
  "meta": {
    "name": "DonationHandler upgrade",
    "description": "ProxyAdmin.upgradeAndCall(proxy, implementation, 0x)"
  },
  "transactions": [
    {
      "to": "$PROXY_ADMIN",
      "value": "0",
      "data": "$CALLDATA",
      "contractMethod": {
        "inputs": [
          { "name": "proxy", "type": "address" },
          { "name": "implementation", "type": "address" },
          { "name": "data", "type": "bytes" }
        ],
        "name": "upgradeAndCall",
        "payable": false
      },
      "contractInputsValues": {
        "proxy": "$PROXY",
        "implementation": "$NEW_IMPL",
        "data": "0x"
      }
    }
  ]
}
EOF
echo "  Transaction Builder JSON: $OUTPUT_JSON"
echo "     (Safe → Apps → Transaction Builder → Import from file)"
echo ""
