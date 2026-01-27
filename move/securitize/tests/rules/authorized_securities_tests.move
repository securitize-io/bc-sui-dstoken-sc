#[test_only]
module securitize::authorized_securities_tests;

use securitize::{
    authorized_securities,
    rule_wrapper::{unwrap_init, new_update, unwrap_update},
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

    let wrapper = authorized_securities::new<TEST_VOLORO>(
        &auth,
        1000000, // max_supply
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(wrapper);

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

    let wrapper = authorized_securities::new<TEST_VOLORO>(
        &auth,
        0, // 0 = unlimited
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(wrapper);

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

    let wrapper = authorized_securities::new<TEST_VOLORO>(
        &auth,
        1000000,
        &version,
        ts.ctx(),
    );
    let _ = unwrap_init(wrapper);

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

    let init_wrapper = authorized_securities::new<TEST_VOLORO>(
        &auth,
        1000000,
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(init_wrapper);

    // Wrap the rule for modification
    let mut wrapper = new_update(rule);

    authorized_securities::set_max_supply<TEST_VOLORO>(
        &auth,
        &mut wrapper,
        2000000,
        &version,
        ts.ctx(),
    );

    // Unwrap to verify changes
    let rule = unwrap_update(wrapper);
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

    let wrapper = authorized_securities::new<TEST_VOLORO>(
        &auth,
        1000000, // max_supply
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(wrapper);

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

    let wrapper = authorized_securities::new<TEST_VOLORO>(
        &auth,
        0, // unlimited
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(wrapper);

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

    let wrapper = authorized_securities::new<TEST_VOLORO>(
        &auth,
        1000000, // max_supply
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(wrapper);

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

    let wrapper = authorized_securities::new<TEST_VOLORO>(
        &auth,
        1000000, // max_supply
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(wrapper);

    // Issuing exactly to the limit should pass
    authorized_securities::validate_rule(&rule, 500000, 500000);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}
