# DonationHandler — Soroban (Stellar)

A Soroban (Rust) port of the EVM [`DonationHandler.sol`](../src/contracts/DonationHandler.sol).
It facilitates single and batched donations of **native XLM and any Stellar-issued
asset** (USDC, etc.) through one unified entrypoint, and emits a `DonationMade`
event carrying an arbitrary `data` payload (used by the Giveth indexer to attach a
`projectId`).

See [`../stellar-feasibility-report.md`](../stellar-feasibility-report.md) (in the
`giveth-v6-core` repo) for the full architecture rationale.

## Why this differs from the EVM contract

| EVM (`DonationHandler.sol`)                              | Soroban (`donation-handler`)                          |
| ------------------------------------------------------- | ----------------------------------------------------- |
| `donateETH` / `donateManyETH`                           | `donate` / `donate_many` with `token` = native XLM SAC |
| `donateERC20` / `donateManyERC20`                       | `donate` / `donate_many` with `token` = issued-asset SAC |
| Native vs. ERC20 split (`msg.value` vs. `transferFrom`) | Unified via the **Stellar Asset Contract (SAC)** — native XLM and issued assets share the SEP-41 token interface |
| `ReentrancyGuard`                                       | **Not needed** — see below                             |
| OZ upgradeable proxy (`initialize` + proxy)             | `update_current_contract_wasm`, admin-gated `upgrade`  |
| `DonationMade(recipient, amount, token, data)` event    | `DonationMade` event, same fields (see schema below)   |

### No ReentrancyGuard — rationale

Soroban's authorization framework requires a signed, deterministic auth tree for
every `require_auth` and SAC transfer, verified by the host before execution.
This contract additionally:

1. **Never calls user-controlled contracts** — only the host-provided SAC, which
   cannot re-enter our code.
2. **Holds no mutable balance state** — funds move directly donor → recipient;
   the only persistent value is the `admin` (for upgrade auth).

If the contract is ever extended to call arbitrary recipient hooks, revisit this
and add a manual guard.

## Public interface

```rust
fn initialize(admin: Address);                       // once; sets the admin (Ownable)
fn donate(from, token, recipient, amount, data);     // single donation
fn donate_many(from, token, total_amount,            // batch; sum(amounts) must == total_amount
               recipients, amounts, data);
fn admin() -> Address;
fn set_admin(new_admin: Address);                    // admin-gated
fn upgrade(new_wasm_hash: BytesN<32>);               // admin-gated WASM upgrade
```

Validation mirrors the EVM contract: array lengths must match, batches must be
non-empty, every amount must be `> 0`, and `sum(amounts)` must equal the declared
`total_amount` (else `AmountsMismatch`).

## `DonationMade` event schema (for the indexer)

* **topics**: `[ Symbol("donation"), recipient: Address, token: Address ]`
* **data** (map): `{ amount: i128, data: Bytes }`

The indexer subscribes via Soroban RPC `getEvents` filtered on
`(contractId, topic[0] == "donation")`, then reads the `projectId` out of
`data.data`. This maps 1:1 to the EVM `DonationMade(recipient indexed, amount,
token indexed, data)` (indexed fields → topics, non-indexed → data).

## Build & test

```bash
# Prerequisites: rustup, the wasm target, and the stellar CLI
rustup target add wasm32v1-none
brew install stellar-cli            # or: cargo install --locked stellar-cli

cargo test                          # 10 unit tests (testutils)
stellar contract build              # -> target/wasm32v1-none/release/donation_handler.wasm
```

## Deploy (testnet)

```bash
stellar keys generate deployer --network testnet --fund
DEPLOYER=$(stellar keys address deployer)

stellar contract deploy \
  --wasm target/wasm32v1-none/release/donation_handler.wasm \
  --source deployer --network testnet --alias donation_handler

stellar contract invoke --id donation_handler --source deployer --network testnet \
  -- initialize --admin "$DEPLOYER"
```

Single donation of 1 XLM (native SAC), with a `projectId` payload:

```bash
NATIVE=$(stellar contract id asset --asset native --network testnet)
stellar contract invoke --id donation_handler --source deployer --network testnet --send=yes \
  -- donate --from "$DEPLOYER" --token "$NATIVE" \
     --recipient <G...> --amount 10000000 --data 0000002a
```

Batch donation (`Vec` args as JSON):

```bash
stellar contract invoke --id donation_handler --source deployer --network testnet --send=yes \
  -- donate_many --from "$DEPLOYER" --token "$NATIVE" --total-amount 30000000 \
     --recipients '["G...","G..."]' --amounts '["10000000","20000000"]' \
     --data '["0000002a","0000002b"]'
```

## Current testnet deployment

| Field            | Value                                                        |
| ---------------- | ------------------------------------------------------------ |
| Network          | Test SDF Network ; September 2015                            |
| Contract ID      | `CDBJL3AEFCA2ECOBUJ4G622Y63XGKX3UXBVVODM4PORVE3DT3PJ4VE4S`   |
| WASM hash        | `f4652257bec0efb6f09f3ff5470c0b792dd29611f51b9b33c592fa044c87ea9a` |
| Admin            | `GDKJHXJGKQXPRUWZCMSZM2QJAERFCMQJGLBREYLTVP4MYYBTQKM2DE7X`   |
| Explorer         | https://stellar.expert/explorer/testnet/contract/CDBJL3AEFCA2ECOBUJ4G622Y63XGKX3UXBVVODM4PORVE3DT3PJ4VE4S |

Verified on-chain: a single donation and a 2-recipient batch both transferred
funds and emitted `DonationMade` with the `data` (projectId) payload intact.

> **Note:** This contract has not been audited. Do not deploy to mainnet without a
> security review.
