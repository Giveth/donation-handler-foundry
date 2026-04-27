# DonationHandler upgrade guide

This guide covers upgrading the DonationHandler proxy to a new implementation. **Both flows use the same addresses:** deploy the new implementation once with `yarn deploy:implementation <chain>`, then either propose a Safe transaction (multisig owner) or run the direct upgrade (EOA owner).

---

## Which flow to use

| ProxyAdmin owner on chain | Flow | Command |
|---------------------------|------|--------|
| **Safe (multisig)** | Submit upgrade to Safe; signers confirm and execute | `yarn upgrade:submit-to-safe -- <chain>` |
| **Your EOA** | Direct upgrade: you sign and broadcast the upgrade tx | `yarn upgrade:direct -- <chain>` |

Same env for both: `PROXY_ADDRESS`, `PROXY_ADMIN_ADDRESS`, `NEW_IMPLEMENTATION_ADDRESS` (from `yarn deploy:implementation <chain>`), and `<CHAIN>_RPC`. For Safe you also need `SAFE_ADDRESS`, `PROPOSER_PRIVATE_KEY`, `SAFE_API_KEY`. For direct you need `PRIVATE_KEY` (the EOA that owns ProxyAdmin).

---

## Upgrade safety: do not call `initialize()` on upgrade

The scripts in this repo **only** switch the proxy to the new implementation; they **do not** pass any calldata to run `initialize()` (or any other function) on the new implementation.

- **Safe flow:** uses `ProxyAdmin.upgradeAndCall(proxy, implementation, '0x')` (empty data).
- **Direct flow:** uses `ProxyAdmin.upgradeAndCall(proxy, implementation, '')` (empty data).

**Why this matters (TransparentUpgradeableProxy + ProxyAdmin):**

If you upgraded with `upgradeAndCall(proxy, implementation, initialize())`, the call path would be Safe → ProxyAdmin → proxy → `implementation.initialize()`. Inside `initialize()`, **`msg.sender` is the ProxyAdmin**, not the Safe. So `__Ownable_init(msg.sender)` would set **owner = ProxyAdmin**. That would leave the proxy in a bad state: the ProxyAdmin cannot call `onlyOwner` functions through the proxy (the transparent proxy blocks admin from implementation calls), and the Safe would no longer be the owner. In addition, if the proxy was already initialized, calling `initialize()` again would revert with `InvalidInitialization()`.

**If the new implementation needs one-time setup or migration**, add a **new** function that uses `reinitializer(2)` (or the right version), pass the **intended owner explicitly** (e.g. your Safe address), and call it in a **separate** transaction after the upgrade — not as the upgrade payload. Do not rely on `msg.sender` for ownership in any upgrade-time call.

---

## Direct upgrade (EOA owner)

When the ProxyAdmin owner is your EOA (not a Safe) on that chain:

1. **Deploy the new implementation** (once per chain):
   ```bash
   yarn deploy:implementation <chain>
   ```
   Example: `yarn deploy:implementation polygon`. Note the deployed implementation address.

2. **Set in `.env`:**
   - `PROXY_ADDRESS` = DonationHandler proxy
   - `PROXY_ADMIN_ADDRESS` = ProxyAdmin contract
   - `NEW_IMPLEMENTATION_ADDRESS` = address from step 1
   - `PRIVATE_KEY` = private key of the EOA that **owns** the ProxyAdmin
   - `<CHAIN>_RPC` = RPC URL (e.g. `POLYGON_RPC`, `BASE_RPC`)

3. **Simulate (optional):**
   ```bash
   yarn upgrade:direct -- polygon --simulate
   ```

4. **Run the upgrade:**
   ```bash
   yarn upgrade:direct -- polygon
   ```
   Use the correct chain instead of `polygon` if needed (e.g. `base`, `mainnet`, `sepolia`).

The script calls `ProxyAdmin.upgradeAndCall(proxy, NEW_IMPLEMENTATION_ADDRESS, '')`; it does **not** deploy a new implementation.

---

## Multisig (Safe) — steps to propose the transaction

Choose one of two ways: **A) Submit from your machine** (script posts to Safe) or **B) Generate payload** then create the tx in the Safe UI.

### Parameters and inputs you need

| Parameter | Where to set | Description |
|-----------|----------------|--------------|
| **SAFE_ADDRESS** | `.env` or CLI | The multisig Safe address (owner of ProxyAdmin). |
| **PROXY_ADMIN_ADDRESS** | `.env` or CLI | The ProxyAdmin contract address. |
| **PROXY_ADDRESS** | `.env` or CLI | The DonationHandler proxy to upgrade. |
| **NEW_IMPLEMENTATION_ADDRESS** | `.env` or CLI | The new implementation contract address (from `yarn deploy:implementation <chain>`). |
| **PROPOSER_PRIVATE_KEY** (or **PROPOSER_PK**) | `.env` only | Private key of a Safe **owner** (used only for **Option A**). |
| **&lt;CHAIN&gt;_RPC** | `.env` | RPC URL for the chain, e.g. `BASE_RPC`, `MAINNET_RPC`. |
| **CHAIN** | CLI argument or `.env` | Chain name: `mainnet`, `base`, `arbitrum`, `optimism`, `polygon`, `gnosis`, `celo`, `sepolia`. |
| **SAFE_API_KEY** | `.env` (optional) | Safe API key if you hit rate limits. |

---

### Option A — Submit proposal from your machine (recommended if you have proposer key)

1. **Set in `.env`:**
   - `SAFE_ADDRESS` = your multisig address  
   - `PROXY_ADMIN_ADDRESS` = ProxyAdmin contract  
   - `PROXY_ADDRESS` = DonationHandler proxy  
   - `NEW_IMPLEMENTATION_ADDRESS` = new implementation (from deploy)  
   - `PROPOSER_PRIVATE_KEY` or `PROPOSER_PK` = private key of **one Safe owner**  
   - `<CHAIN>_RPC` = RPC URL (e.g. `BASE_RPC`, `MAINNET_RPC`)

2. **Run (from repo root):**
   ```bash
   yarn upgrade:submit-to-safe base
   ```
   Use the correct chain instead of `base` if needed (e.g. `mainnet`, `arbitrum`).

3. The script will create the upgrade tx, sign it with the proposer key, and submit it to the Safe Transaction Service. Other signers see it in the Safe UI and can confirm/execute.

---

### Option B — Generate payload, then create the tx in Safe UI

1. **Set in `.env` (or pass as CLI args):**
   - `PROXY_ADMIN_ADDRESS`  
   - `PROXY_ADDRESS`  
   - `NEW_IMPLEMENTATION_ADDRESS`  
   Optional: `SAFE_ADDRESS`, `CHAIN` (for the printed Safe link).

2. **Generate the payload:**
   ```bash
   yarn upgrade:generate-payload 0x<ProxyAdmin> 0x<Proxy> 0x<NewImplementation>
   # Or with env set: yarn upgrade:generate-payload
   ```

3. **Use the output:**
   - Open the printed Safe link (or [app.safe.global](https://app.safe.global)).
   - **New transaction** → **Contract interaction** (or **Apps** → **Transaction Builder**).
   - **To:** paste `PROXY_ADMIN_ADDRESS`.
   - **Data:** paste the hex **Data (calldata)** from the script output, or use the function `upgradeAndCall(address,address,bytes)` with `proxy` = `PROXY_ADDRESS`, `implementation` = `NEW_IMPLEMENTATION_ADDRESS`, and `data` = `0x`.
   - **Value:** 0.
   - **Create transaction** so other signers can sign and execute.

   Alternatively, in Safe go to **Apps** → **Transaction Builder** → **Import** and select the generated `upgrade-payload.json`.

---

## Proposing the transaction (for the proposer)

If you have the three addresses (ProxyAdmin, proxy, new implementation), you can **generate** the exact transaction payload and a Safe Transaction Builder–ready JSON:

```bash
# From the repo root (requires Foundry cast)
yarn upgrade:generate-payload <proxy_admin_address> <proxy_address> <new_implementation_address>

# Optional: add your Safe address and chain to get a direct link
yarn upgrade:generate-payload <proxy_admin> <proxy> <new_impl> <safe_address> <chain>
# e.g. yarn upgrade:generate-payload 0xAdmin 0xProxy 0xImpl 0xYourSafe base
```

The script prints **To**, **Value**, **Data** and step-by-step Safe instructions. It also writes `upgrade-payload.json`, which you can **Import** in Safe → Apps → Transaction Builder to create the proposal in one click.

### Submit proposal to Safe (proposer key in env)

If the proposer’s private key is in `.env` as **`PROPOSER_PRIVATE_KEY`** (or **`PROPOSER_PK`**), and the proposer is one of the Safe owners, you can **submit** the proposal directly to the Safe Transaction Service:

```bash
# Set in .env: SAFE_ADDRESS, PROXY_ADMIN_ADDRESS, PROXY_ADDRESS, NEW_IMPLEMENTATION_ADDRESS, PROPOSER_PRIVATE_KEY, and <CHAIN>_RPC
yarn upgrade:submit-to-safe base
# or: mainnet, arbitrum, optimism, polygon, gnosis, celo, sepolia
```

The script will create the upgrade transaction, sign it with the proposer key, and POST it to the Safe API. Other signers can then confirm and execute in the Safe UI.

---

## What you’re doing

- The **DonationHandler** logic lives behind an upgradeable proxy.
- You call **ProxyAdmin.upgradeAndCall(proxy, newImplementation, '0x')** so the proxy points to the new implementation without running `initialize()`.
- Only the ProxyAdmin **owner** can do this (multisig or EOA). The new implementation is deployed once with `yarn deploy:implementation <chain>`; the upgrade step only updates the proxy to use that address.

---

## What you need (you’ll receive these)

| Item | Description |
|------|-------------|
| **ProxyAdmin address** | The contract whose owner will run the upgrade (multisig or your EOA) |
| **Proxy address** | The DonationHandler proxy to upgrade (e.g. `0x...`) |
| **New implementation address** | From `yarn deploy:implementation <chain>` — deploy once, then use in Safe or direct upgrade |
| **Network** | The chain where the proxy lives (e.g. Ethereum, Base, Polygon, Celo) |

---

## Steps (Gnosis Safe / Safe{Wallet})

1. Open your Safe for the correct network:  
   [https://app.safe.global](https://app.safe.global) (or your Safe URL).

2. Go to **Apps** → **Transaction Builder** (or **New transaction** → **Contract interaction**).

3. **To (contract):**  
   Paste the **ProxyAdmin** address.

4. **Contract interaction:**  
   - Choose **Write contract** (or “Contract interaction”).
   - Find the function **`upgradeAndCall`** (or add it as a custom call; see below).

5. **Function: `upgradeAndCall`**
   - **Parameter 1 – `proxy` (address):** the **DonationHandler proxy** address.
   - **Parameter 2 – `implementation` (address):** the **new implementation** address.
   - **Parameter 3 – `data` (bytes):** `0x`

6. **Value:** leave as **0**.

7. Review the transaction, then **Create transaction** (or equivalent). Other signers **Sign** and execute when the threshold is met.

---

## If the Safe UI doesn’t show `upgradeAndCall`

Use **Contract interaction** with **Custom data**:

- **To:** ProxyAdmin address  
- **Data (hex):** generate the exact calldata from the repo, then paste it into Safe:

  ```text
  upgradeAndCall(address,address,bytes)
  ```

  Preferred:
  ```bash
  yarn upgrade:generate-payload <proxy_admin> <proxy> <new_implementation> [safe_address] [chain]
  ```

  That script prints the full hex calldata to paste into the Safe UI.

  Or run `cast` directly:
  ```bash
  cast calldata "upgradeAndCall(address,address,bytes)" <proxy> <new_implementation> 0x
  ```

  This outputs the exact calldata for `upgradeAndCall(proxy, implementation, 0x)`.

---

## After the upgrade

- The proxy address **does not change**; only the implementation it points to changes.
- You can confirm on a block explorer: open the **proxy** contract and check “Implementation” or “Read as Proxy” — it should show the new implementation address.
- If you have a changelog or release note for this upgrade, keep it for your records.

---

## Checklist for multisig proposer / first signer

- [ ] Confirm **proxy**, **ProxyAdmin**, and **new implementation** addresses and **network** with the team.
- [ ] Confirm the new implementation is **verified** on the block explorer for that network.
- [ ] Create the Safe transaction as above and share the link or batch ID for other signers to sign.

For **direct upgrade** (EOA owner), after deploying the implementation and setting env, run `yarn upgrade:direct -- <chain> --simulate` then `yarn upgrade:direct -- <chain>`.

---

## Quick reference

| Role | Address type | Example use |
|------|--------------|-------------|
| **ProxyAdmin** | Contract you call | “To” in Safe; target of upgrade script |
| **Proxy** | First argument of `upgrade` | DonationHandler proxy |
| **New implementation** | Second argument of `upgrade` | From `yarn deploy:implementation <chain>` |

**Function:** `upgrade(address proxy, address implementation)` (or `upgradeAndCall(proxy, implementation, '')`)  
**Value:** 0  
**Only the ProxyAdmin owner (multisig or EOA) can call this.**
