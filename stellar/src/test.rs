extern crate std;

use super::{DonationHandler, DonationHandlerClient, Error};
use soroban_sdk::{
    testutils::{Address as _, Events},
    token, vec, Address, Bytes, Env,
};

struct Setup<'a> {
    env: Env,
    contract_id: Address,
    client: DonationHandlerClient<'a>,
    admin: Address,
    donor: Address,
    token: Address,
    token_client: token::TokenClient<'a>,
}

fn setup() -> Setup<'static> {
    let env = Env::default();
    env.mock_all_auths();

    let admin = Address::generate(&env);
    let donor = Address::generate(&env);

    // Register the SAC for a test asset and mint a balance to the donor.
    let issuer = Address::generate(&env);
    let sac = env.register_stellar_asset_contract_v2(issuer);
    let token = sac.address();
    let token_sac = token::StellarAssetClient::new(&env, &token);
    let token_client = token::TokenClient::new(&env, &token);
    token_sac.mint(&donor, &1_000_000);

    // Admin is set atomically by the constructor at registration/deploy time.
    let contract_id = env.register(DonationHandler, (admin.clone(),));
    let client = DonationHandlerClient::new(&env, &contract_id);

    Setup {
        env,
        contract_id,
        client,
        admin,
        donor,
        token,
        token_client,
    }
}

/// Count of events emitted by our contract in the last invocation. Our
/// contract only ever emits `DonationMade`, so this is the donation count
/// (SAC `transfer` events are attributed to the token contract and excluded).
fn donation_events(s: &Setup) -> usize {
    s.env
        .events()
        .all()
        .filter_by_contract(&s.contract_id)
        .events()
        .len()
}

#[test]
fn constructor_sets_admin() {
    let s = setup();
    assert_eq!(s.client.admin(), s.admin);
}

#[test]
fn donate_single_transfers_and_emits() {
    let s = setup();
    let recipient = Address::generate(&s.env);
    let data = Bytes::from_array(&s.env, &[1, 2, 3, 4]); // pretend projectId

    s.client.donate(&s.donor, &s.token, &recipient, &500, &data);

    // `events().all()` reflects only the most recent contract invocation, so
    // assert the event count before issuing any `balance` queries (which are
    // themselves contract invocations).
    assert_eq!(donation_events(&s), 1);
    assert_eq!(s.token_client.balance(&recipient), 500);
    assert_eq!(s.token_client.balance(&s.donor), 1_000_000 - 500);
}

#[test]
fn donate_zero_amount_fails() {
    let s = setup();
    let recipient = Address::generate(&s.env);
    let data = Bytes::new(&s.env);
    assert_eq!(
        s.client.try_donate(&s.donor, &s.token, &recipient, &0, &data),
        Err(Ok(Error::InvalidInput))
    );
}

#[test]
fn donate_many_distributes_to_all() {
    let s = setup();
    let r1 = Address::generate(&s.env);
    let r2 = Address::generate(&s.env);
    let r3 = Address::generate(&s.env);

    let recipients = vec![&s.env, r1.clone(), r2.clone(), r3.clone()];
    let amounts = vec![&s.env, 100i128, 250i128, 150i128];
    let data = vec![
        &s.env,
        Bytes::from_array(&s.env, &[1]),
        Bytes::from_array(&s.env, &[2]),
        Bytes::from_array(&s.env, &[3]),
    ];

    s.client
        .donate_many(&s.donor, &s.token, &500, &recipients, &amounts, &data);

    // Assert event count before balance queries (see note above).
    assert_eq!(donation_events(&s), 3);
    assert_eq!(s.token_client.balance(&r1), 100);
    assert_eq!(s.token_client.balance(&r2), 250);
    assert_eq!(s.token_client.balance(&r3), 150);
    assert_eq!(s.token_client.balance(&s.donor), 1_000_000 - 500);
}

#[test]
fn donate_many_length_mismatch_fails() {
    let s = setup();
    let r1 = Address::generate(&s.env);
    let recipients = vec![&s.env, r1.clone()];
    let amounts = vec![&s.env, 100i128, 200i128]; // mismatched length
    let data = vec![&s.env, Bytes::from_array(&s.env, &[1])];

    assert_eq!(
        s.client
            .try_donate_many(&s.donor, &s.token, &300, &recipients, &amounts, &data),
        Err(Ok(Error::InvalidInput))
    );
    // No funds moved.
    assert_eq!(s.token_client.balance(&s.donor), 1_000_000);
}

#[test]
fn donate_many_sum_mismatch_fails() {
    let s = setup();
    let r1 = Address::generate(&s.env);
    let r2 = Address::generate(&s.env);
    let recipients = vec![&s.env, r1.clone(), r2.clone()];
    let amounts = vec![&s.env, 100i128, 200i128]; // sums to 300
    let data = vec![
        &s.env,
        Bytes::from_array(&s.env, &[1]),
        Bytes::from_array(&s.env, &[2]),
    ];

    // Declared total (999) != sum (300).
    assert_eq!(
        s.client
            .try_donate_many(&s.donor, &s.token, &999, &recipients, &amounts, &data),
        Err(Ok(Error::AmountsMismatch))
    );
    assert_eq!(s.token_client.balance(&s.donor), 1_000_000);
}

#[test]
fn donate_many_empty_fails() {
    let s = setup();
    let recipients = soroban_sdk::Vec::<Address>::new(&s.env);
    let amounts = soroban_sdk::Vec::<i128>::new(&s.env);
    let data = soroban_sdk::Vec::<Bytes>::new(&s.env);
    assert_eq!(
        s.client
            .try_donate_many(&s.donor, &s.token, &0, &recipients, &amounts, &data),
        Err(Ok(Error::InvalidInput))
    );
}

#[test]
fn donate_many_reverts_atomically_on_insufficient_funds() {
    // Donor holds 1_000_000. A batch totalling 1_200_000 must move *nothing*:
    // the second transfer fails and the whole transaction rolls back.
    let s = setup();
    let r1 = Address::generate(&s.env);
    let r2 = Address::generate(&s.env);
    let recipients = vec![&s.env, r1.clone(), r2.clone()];
    let amounts = vec![&s.env, 600_000i128, 600_000i128];
    let data = vec![
        &s.env,
        Bytes::from_array(&s.env, &[1]),
        Bytes::from_array(&s.env, &[2]),
    ];

    let res = s
        .client
        .try_donate_many(&s.donor, &s.token, &1_200_000, &recipients, &amounts, &data);
    assert!(res.is_err());

    // No partial donation: the first recipient must not have been paid.
    assert_eq!(s.token_client.balance(&r1), 0);
    assert_eq!(s.token_client.balance(&r2), 0);
    assert_eq!(s.token_client.balance(&s.donor), 1_000_000);
}

#[test]
fn set_admin_changes_owner() {
    let s = setup();
    let new_admin = Address::generate(&s.env);
    s.client.set_admin(&new_admin);
    assert_eq!(s.client.admin(), new_admin);
}

#[test]
fn donor_balance_insufficient_panics() {
    // The SAC transfer itself enforces balance; donating more than the donor
    // holds must fail (the whole tx reverts).
    let s = setup();
    let recipient = Address::generate(&s.env);
    let data = Bytes::new(&s.env);
    let res = s
        .client
        .try_donate(&s.donor, &s.token, &recipient, &2_000_000, &data);
    assert!(res.is_err());
    assert_eq!(s.token_client.balance(&recipient), 0);
}
