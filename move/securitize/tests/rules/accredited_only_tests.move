#[test_only]
module securitize::accredited_only_tests;

use securitize::{
    accredited_only::{
        Self,
        new as new_accredited_only,
        is_force_accredited,
        is_force_us_accredited,
        set_force_accredited,
        set_force_us_accredited,
        validate_rule
    },
    rule_wrapper,
    test_helpers::{setup_with_treasury, TEST_VOLORO},
    trust_service::Auth,
    version::Version
};
use sui::test_scenario::{Self as ts, Scenario};

const ADMIN: address = @0x001;
const UNAUTHORIZED: address = @0x002;

// Region constants
const US: u64 = 1;
const EU: u64 = 2;

fun setup_for_testing(ts: &mut Scenario) {
    ts.next_tx(ADMIN);
    setup_with_treasury(ts);
}

#[test]
fun test_new_accredited_only_rule() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let rule = new_accredited_only<TEST_VOLORO>(
        &auth,
        true, // force_accredited
        false, // force_us_accredited
        &version,
        ts.ctx(),
    );

    assert!(is_force_accredited(&rule), 0);
    assert!(!is_force_us_accredited(&rule), 1);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = accredited_only::ENotAuthorized)]
fun test_new_unauthorized() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(UNAUTHORIZED);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    // Should fail - UNAUTHORIZED has no ManageRules ability
    let _rule = new_accredited_only<TEST_VOLORO>(
        &auth,
        true,
        false,
        &version,
        ts.ctx(),
    );

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_set_force_accredited() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let rule = new_accredited_only<TEST_VOLORO>(
        &auth,
        false,
        false,
        &version,
        ts.ctx(),
    );

    assert!(!is_force_accredited(&rule), 0);

    // Wrap the rule for modification
    let mut wrapper = rule_wrapper::new(rule);

    set_force_accredited<TEST_VOLORO>(
        &auth,
        &mut wrapper,
        true,
        &version,
        ts.ctx(),
    );

    // Unwrap to verify changes
    let rule = rule_wrapper::unwrap(wrapper);
    assert!(is_force_accredited(&rule), 1);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_set_force_us_accredited() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let rule = new_accredited_only<TEST_VOLORO>(
        &auth,
        false,
        false,
        &version,
        ts.ctx(),
    );

    assert!(!is_force_us_accredited(&rule), 0);

    // Wrap the rule for modification
    let mut wrapper = rule_wrapper::new(rule);

    set_force_us_accredited<TEST_VOLORO>(
        &auth,
        &mut wrapper,
        true,
        &version,
        ts.ctx(),
    );

    // Unwrap to verify changes
    let rule = rule_wrapper::unwrap(wrapper);
    assert!(is_force_us_accredited(&rule), 1);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_validate_rule_no_restrictions() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let rule = new_accredited_only<TEST_VOLORO>(
        &auth,
        false, // force_accredited = false
        false, // force_us_accredited = false
        &version,
        ts.ctx(),
    );

    // Should pass for non-accredited investor in any region
    validate_rule(&rule, US, false);
    validate_rule(&rule, EU, false);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_validate_rule_global_accredited_passes() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let rule = new_accredited_only<TEST_VOLORO>(
        &auth,
        true, // force_accredited = true
        false,
        &version,
        ts.ctx(),
    );

    // Should pass for accredited investor
    validate_rule(&rule, US, true);
    validate_rule(&rule, EU, true);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = accredited_only::ENotAccredited)]
fun test_validate_rule_global_accredited_fails() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let rule = new_accredited_only<TEST_VOLORO>(
        &auth,
        true, // force_accredited = true
        false,
        &version,
        ts.ctx(),
    );

    // Should fail for non-accredited investor
    validate_rule(&rule, EU, false);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_validate_rule_us_accredited_passes() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let rule = new_accredited_only<TEST_VOLORO>(
        &auth,
        false,
        true, // force_us_accredited = true
        &version,
        ts.ctx(),
    );

    // Should pass for accredited US investor
    validate_rule(&rule, US, true);
    // Should pass for non-accredited non-US investor
    validate_rule(&rule, EU, false);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = accredited_only::ENotUSAccredited)]
fun test_validate_rule_us_accredited_fails() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let rule = new_accredited_only<TEST_VOLORO>(
        &auth,
        false,
        true, // force_us_accredited = true
        &version,
        ts.ctx(),
    );

    // Should fail for non-accredited US investor
    validate_rule(&rule, US, false);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}
