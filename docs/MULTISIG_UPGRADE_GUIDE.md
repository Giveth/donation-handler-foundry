# DonationHandler upgrade — guide for multisig signers

This guide is for signers of the **ProxyAdmin** multisig. It explains how to run a single transaction to upgrade the DonationHandler to a new implementation.

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
- You will call **ProxyAdmin.upgrade(proxy, newImplementation)** so the proxy starts using the new implementation.
- Only the ProxyAdmin owner (your multisig) can do this. One transaction, no code — just the new implementation address.

---

## What you need (you’ll receive these)

| Item | Description |
|------|-------------|
| **ProxyAdmin address** | The contract your multisig owns (e.g. `0x...`) |
| **Proxy address** | The DonationHandler proxy to upgrade (e.g. `0x...`) |
| **New implementation address** | The newly deployed implementation (e.g. `0x...`) |
| **Network** | The chain where the proxy lives (e.g. Ethereum, Base, Celo) |

---

## Steps (Gnosis Safe / Safe{Wallet})

1. Open your Safe for the correct network:  
   [https://app.safe.global](https://app.safe.global) (or your Safe URL).

2. Go to **Apps** → **Transaction Builder** (or **New transaction** → **Contract interaction**).

3. **To (contract):**  
   Paste the **ProxyAdmin** address.

4. **Contract interaction:**  
   - Choose **Write contract** (or “Contract interaction”).
   - Find the function **`upgrade`** (or add it as a custom call; see below).

5. **Function: `upgrade`**
   - **Parameter 1 – `proxy` (address):** the **DonationHandler proxy** address.
   - **Parameter 2 – `implementation` (address):** the **new implementation** address.

6. **Value:** leave as **0**.

7. Review the transaction, then **Create transaction** (or equivalent). Other signers **Sign** and execute when the threshold is met.

---

## If the Safe UI doesn’t show `upgrade`

Use **Contract interaction** with **Custom data**:

- **To:** ProxyAdmin address  
- **Data (hex):** use the ABI-encoded call:

  ```text
  upgrade(address,address)
  ```

  Encoded with:
  - **Selector:** `0x99...` (first 4 bytes of `keccak256("upgrade(address,address)")`).  
  You can get the exact calldata from a block explorer (e.g. Etherscan) by going to the ProxyAdmin contract → **Write** → **upgrade** and encoding the two addresses, or by using a small script/tool that encodes the call.

  Or use an online ABI encoder:
  - Function: `upgrade(address proxy, address implementation)`
  - Arguments: `[ <proxy address>, <new implementation address> ]`
  - Prepend the 4-byte selector: `0x99...` (look up `upgrade(address,address)` selector).

---

## After the upgrade

- The proxy address **does not change**; only the implementation it points to changes.
- You can confirm on a block explorer: open the **proxy** contract and check “Implementation” or “Read as Proxy” — it should show the new implementation address.
- If you have a changelog or release note for this upgrade, keep it for your records.

---

## Checklist for proposer / first signer

- [ ] Confirm **proxy**, **ProxyAdmin**, and **new implementation** addresses and **network** with the team.
- [ ] Confirm the new implementation is **verified** on the block explorer for that network.
- [ ] Create the Safe transaction as above and share the link or batch ID for other signers to sign.

---

## Quick reference

| Role | Address type | Example use |
|------|--------------|-------------|
| **ProxyAdmin** | Contract you call | “To” in Safe = ProxyAdmin |
| **Proxy** | First argument of `upgrade` | DonationHandler proxy |
| **New implementation** | Second argument of `upgrade` | New implementation address |

**Function:** `upgrade(address proxy, address implementation)`  
**Value:** 0  
**Only the ProxyAdmin owner (your multisig) can call this.**
