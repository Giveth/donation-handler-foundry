#![no_std]
//! # DonationHandler (Soroban)
//!
//! Soroban port of the EVM `DonationHandler.sol` contract. It facilitates
//! single and batched donations and emits a `DonationMade` event carrying an
//! arbitrary `data` payload (used by the Giveth indexer to attach a
//! `projectId`).
//!
//! ## Differences vs. the EVM contract
//!
//! * The EVM contract has four entrypoints (`donateETH`, `donateManyETH`,
//!   `donateERC20`, `donateManyERC20`). On Soroban the native-vs-token split
//!   disappears: the [Stellar Asset Contract (SAC)] exposes native XLM and
//!   every issued asset (USDC, etc.) behind the same SEP-41 token interface, so
//!   a single `token: Address` argument covers both. The four functions
//!   collapse into [`donate`] and [`donate_many`].
//! * Funds move directly from the donor to the recipient via
//!   `token.transfer(from, recipient, amount)` (mirroring the EVM
//!   `safeTransferFrom`). The contract never custodies funds.
//! * No `ReentrancyGuard`. Soroban's authorization framework requires a signed,
//!   deterministic auth tree for every `require_auth`/SAC transfer, and this
//!   contract only ever calls the host-provided SAC (which cannot re-enter
//!   user code) and holds no mutable balance state. See the project README for
//!   the full rationale.
//! * Upgradeability uses `update_current_contract_wasm` gated by the admin
//!   (the Soroban equivalent of the OpenZeppelin upgradeable proxy pattern).
//!
//! [Stellar Asset Contract (SAC)]: https://developers.stellar.org/docs/tokens/stellar-asset-contract

use soroban_sdk::{
    contract, contractevent, contracterror, contractimpl, symbol_short, token, Address, Bytes,
    BytesN, Env, Symbol, Vec,
};

/// Instance-storage key holding the admin address (mirrors `Ownable`).
const ADMIN: Symbol = symbol_short!("ADMIN");

/// Emitted for every donation. Mirrors the EVM
/// `DonationMade(address indexed recipientAddress, uint256 amount, address indexed tokenAddress, bytes data)`.
///
/// Indexed fields become topics; the topic prefix `"donation"` (topic[0]) lets
/// the indexer subscribe with a single server-side filter on
/// `(contract_id, topic[0] == "donation")`. The `data` map carries the opaque
/// `data` payload (the Giveth `projectId`) and the `amount`.
#[contractevent(topics = ["donation"], data_format = "map")]
pub struct DonationMade {
    #[topic]
    pub recipient: Address,
    #[topic]
    pub token: Address,
    pub amount: i128,
    pub data: Bytes,
}

#[contracterror]
#[derive(Copy, Clone, Debug, Eq, PartialEq, PartialOrd, Ord)]
#[repr(u32)]
pub enum Error {
    /// Contract has not been initialized with an admin yet.
    NotInitialized = 1,
    /// `initialize` was called more than once.
    AlreadyInitialized = 2,
    /// Array lengths mismatch, an empty batch, or a non-positive amount.
    /// (Equivalent to the EVM `InvalidInput` error.)
    InvalidInput = 3,
    /// `sum(amounts) != total_amount` (EVM: "Amounts do not match total").
    AmountsMismatch = 4,
    /// Arithmetic overflow while summing batch amounts.
    Overflow = 5,
}

#[contract]
pub struct DonationHandler;

#[contractimpl]
impl DonationHandler {
    /// Initialize the contract with an `admin`. Mirrors the EVM
    /// `initialize()` + `__Ownable_init`. Can only be called once.
    pub fn initialize(env: Env, admin: Address) -> Result<(), Error> {
        if env.storage().instance().has(&ADMIN) {
            return Err(Error::AlreadyInitialized);
        }
        env.storage().instance().set(&ADMIN, &admin);
        Ok(())
    }

    /// Single donation.
    ///
    /// * `from`      – the donor; must authorize the call.
    /// * `token`     – SAC address of the asset (native XLM SAC or an issued
    ///                 asset such as USDC).
    /// * `recipient` – the project/recipient address.
    /// * `amount`    – amount in the token's smallest unit (must be > 0).
    /// * `data`      – opaque payload (the Giveth `projectId`, etc.).
    ///
    /// Equivalent to `donateETH` / `donateERC20`.
    pub fn donate(
        env: Env,
        from: Address,
        token: Address,
        recipient: Address,
        amount: i128,
        data: Bytes,
    ) -> Result<(), Error> {
        from.require_auth();
        Self::handle_one(&env, &from, &token, &recipient, amount, &data)
    }

    /// Batch donation to multiple recipients in a single transaction.
    ///
    /// `recipients`, `amounts` and `data` must all have the same (non-zero)
    /// length, and `sum(amounts)` must equal `total_amount`. Equivalent to
    /// `donateManyETH` / `donateManyERC20`.
    pub fn donate_many(
        env: Env,
        from: Address,
        token: Address,
        total_amount: i128,
        recipients: Vec<Address>,
        amounts: Vec<i128>,
        data: Vec<Bytes>,
    ) -> Result<(), Error> {
        from.require_auth();

        let len = recipients.len();
        if len == 0 || len != amounts.len() || len != data.len() {
            return Err(Error::InvalidInput);
        }

        // Validate amounts and confirm the declared total (EVM: sum == total).
        let mut sum: i128 = 0;
        for amount in amounts.iter() {
            if amount <= 0 {
                return Err(Error::InvalidInput);
            }
            sum = sum.checked_add(amount).ok_or(Error::Overflow)?;
        }
        if sum != total_amount {
            return Err(Error::AmountsMismatch);
        }

        for i in 0..len {
            // Safe: index < len, and the three vecs share the same length.
            let recipient = recipients.get_unchecked(i);
            let amount = amounts.get_unchecked(i);
            let datum = data.get_unchecked(i);
            Self::handle_one(&env, &from, &token, &recipient, amount, &datum)?;
        }
        Ok(())
    }

    /// Return the current admin. Errors if the contract is uninitialized.
    pub fn admin(env: Env) -> Result<Address, Error> {
        env.storage()
            .instance()
            .get(&ADMIN)
            .ok_or(Error::NotInitialized)
    }

    /// Transfer ownership to a new admin. Admin-gated.
    pub fn set_admin(env: Env, new_admin: Address) -> Result<(), Error> {
        let admin = Self::admin(env.clone())?;
        admin.require_auth();
        env.storage().instance().set(&ADMIN, &new_admin);
        Ok(())
    }

    /// Upgrade the contract's WASM bytecode. Admin-gated. This is the Soroban
    /// equivalent of the OpenZeppelin upgradeable proxy `upgradeTo`.
    pub fn upgrade(env: Env, new_wasm_hash: BytesN<32>) -> Result<(), Error> {
        let admin = Self::admin(env.clone())?;
        admin.require_auth();
        env.deployer().update_current_contract_wasm(new_wasm_hash);
        Ok(())
    }
}

impl DonationHandler {
    /// Execute one donation: validate, transfer donor -> recipient, emit event.
    fn handle_one(
        env: &Env,
        from: &Address,
        token: &Address,
        recipient: &Address,
        amount: i128,
        data: &Bytes,
    ) -> Result<(), Error> {
        if amount <= 0 {
            return Err(Error::InvalidInput);
        }

        // The SAC unifies native XLM and issued assets behind SEP-41. The
        // transfer itself requires `from`'s authorization (verified by the
        // host), so funds can never move without the donor's signed consent.
        token::TokenClient::new(env, token).transfer(from, recipient, &amount);

        env.events().publish_event(&DonationMade {
            recipient: recipient.clone(),
            token: token.clone(),
            amount,
            data: data.clone(),
        });
        Ok(())
    }
}

#[cfg(test)]
mod test;
