#[test_only]
module securitize::authorized_securities_tests;

use securitize::{
    authorized_securities,
    rule_wrapper,
    test_helpers::{TEST_VOLORO, setup_with_treasury},
    trust_service::Auth,
    version::Version
};
use sui::test_scenario::{Self as ts, Scenario};

const ADMIN: address = @0x001;
const UNAUTHORIZED: address = @0x002;

fun setup_for_testing(ts: &mut Scenario) {
    ts.next_tx(ADMIN);
    setup_with_treasury(ts);
}

#[test]
fun test_new_authorized_securities_rule() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let rule = authorized_securities::new<TEST_VOLORO>(
        &auth,
        1000000, // max_supply
        &version,
        ts.ctx(),
    );

    assert!(authorized_securities::max_supply(&rule) == 1000000, 0);
    assert!(authorized_securities::is_enforced(&rule), 1);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_new_unlimited_supply() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let rule = authorized_securities::new<TEST_VOLORO>(
        &auth,
        0, // 0 = unlimited
        &version,
        ts.ctx(),
    );

    assert!(authorized_securities::max_supply(&rule) == 0, 0);
    assert!(!authorized_securities::is_enforced(&rule), 1);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = authorized_securities::ENotAuthorized)]
fun test_new_unauthorized() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(UNAUTHORIZED);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let _rule = authorized_securities::new<TEST_VOLORO>(
        &auth,
        1000000,
        &version,
        ts.ctx(),
    );

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_set_max_supply() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let rule = authorized_securities::new<TEST_VOLORO>(
        &auth,
        1000000,
        &version,
        ts.ctx(),
    );

    // Wrap the rule for modification
    let mut wrapper = rule_wrapper::new(rule);

    authorized_securities::set_max_supply<TEST_VOLORO>(
        &auth,
        &mut wrapper,
        2000000,
        &version,
        ts.ctx(),
    );

    // Unwrap to verify changes
    let rule = rule_wrapper::unwrap(wrapper);
    assert!(authorized_securities::max_supply(&rule) == 2000000, 0);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_validate_rule_passes() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let rule = authorized_securities::new<TEST_VOLORO>(
        &auth,
        1000000, // max_supply
        &version,
        ts.ctx(),
    );

    // Current supply + issuance amount within limit
    authorized_securities::validate_rule(&rule, 100000, 500000);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_validate_rule_unlimited() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let rule = authorized_securities::new<TEST_VOLORO>(
        &auth,
        0, // unlimited
        &version,
        ts.ctx(),
    );

    // Any amount allowed when unlimited
    authorized_securities::validate_rule(&rule, 999999999, 999999999);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = authorized_securities::EMaxAuthorizedSecuritiesExceeded)]
fun test_validate_rule_exceeds_max() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let rule = authorized_securities::new<TEST_VOLORO>(
        &auth,
        1000000, // max_supply
        &version,
        ts.ctx(),
    );

    // Current supply + issuance amount exceeds limit
    authorized_securities::validate_rule(&rule, 500000, 600000);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_validate_rule_exact_max() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let rule = authorized_securities::new<TEST_VOLORO>(
        &auth,
        1000000, // max_supply
        &version,
        ts.ctx(),
    );

    // Issuing exactly to the limit should pass
    authorized_securities::validate_rule(&rule, 500000, 500000);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}
