#[test_only]
module securitize::ds_token_tests;

use sui::{coin_registry, test_scenario::{Self as ts, Scenario}};
use securitize::{ds_token::{Self, Treasury}, setup::{Self, SetupAuth}, version::{Self, Version}};
use std::unit_test::destroy;

const ADMIN: address = @0xCAFE;

public struct TestToken has key {
    id: UID,
}

#[test]
fun test_ds_token_pause() {
    let mut ts = ts::begin(ADMIN);
    setup::init_for_testing(ts.ctx());
    ts.next_tx(ADMIN);

    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut treasury = ts.take_shared<Treasury<TestToken>>();
    let version = ts.take_shared<Version>();
    assert!(!treasury.is_paused());
    treasury.pause(&version, ts.ctx());
    assert!(treasury.is_paused());
    treasury.unpause(&version, ts.ctx());
    assert!(!treasury.is_paused());

    ts::return_shared(treasury);
    ts::return_shared(version);
    ts.end();
}

fun setup_for_testing(ts: &mut Scenario) {
    ts.next_tx(@0x0);
    let mut registry = coin_registry::create_coin_data_registry_for_testing(ts.ctx());
    ts.next_tx(ADMIN);
    version::init_for_testing(ts.ctx());
    ts.next_tx(ADMIN);
    let setup_auth = ts.take_shared<SetupAuth>();
    let version = ts.take_shared<Version>();
    let (currency, treasury_cap) = coin_registry::new_currency<TestToken>(
        &mut registry,
        9,
        b"RWA".to_string(),
        b"Real World Asset".to_string(),
        b"RWA token for testing".to_string(),
        b"https://example.io/rwa.png".to_string(),
        ts.ctx(),
    );

    setup::setup(&setup_auth, &version, currency, treasury_cap, ts.ctx());
    ts::return_shared(setup_auth);
    ts::return_shared(version);
    destroy(registry);
}
