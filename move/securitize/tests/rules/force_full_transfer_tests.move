#[test_only]
module securitize::force_full_transfer_tests;

use securitize::{
    abilities::ManageRules,
    force_full_transfer,
    rule_wrapper,
    setup::{Self, SetupRegistry},
    trust_service::{Self, Auth, Master},
    version::{Self, Version}
};
use sui::test_scenario::{Self as ts, Scenario};
use securitize::test_helpers::TEST_VOLORO;
use securitize::test_helpers::setup_with_treasury;

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
fun test_new_force_full_transfer_rule() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let rule = force_full_transfer::new<TEST_VOLORO>(
        &auth,
        true, // force_full_transfer_us
        false, // force_full_transfer_worldwide
        &version,
        ts.ctx(),
    );

    assert!(force_full_transfer::is_force_us(&rule), 0);
    assert!(!force_full_transfer::is_force_worldwide(&rule), 1);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = force_full_transfer::ENotAuthorized)]
fun test_new_unauthorized() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(UNAUTHORIZED);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let _rule = force_full_transfer::new<TEST_VOLORO>(
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
fun test_set_force_us() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let rule = force_full_transfer::new<TEST_VOLORO>(
        &auth,
        false,
        false,
        &version,
        ts.ctx(),
    );

    assert!(!force_full_transfer::is_force_us(&rule), 0);

    // Wrap the rule for modification
    let mut wrapper = rule_wrapper::new(rule);

    force_full_transfer::set_force_us<TEST_VOLORO>(
        &auth,
        &mut wrapper,
        true,
        &version,
        ts.ctx(),
    );

    // Unwrap to verify changes
    let rule = rule_wrapper::unwrap(wrapper);
    assert!(force_full_transfer::is_force_us(&rule), 1);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_set_force_worldwide() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let rule = force_full_transfer::new<TEST_VOLORO>(
        &auth,
        false,
        false,
        &version,
        ts.ctx(),
    );

    assert!(!force_full_transfer::is_force_worldwide(&rule), 0);

    // Wrap the rule for modification
    let mut wrapper = rule_wrapper::new(rule);

    force_full_transfer::set_force_worldwide<TEST_VOLORO>(
        &auth,
        &mut wrapper,
        true,
        &version,
        ts.ctx(),
    );

    // Unwrap to verify changes
    let rule = rule_wrapper::unwrap(wrapper);
    assert!(force_full_transfer::is_force_worldwide(&rule), 1);

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

    let rule = force_full_transfer::new<TEST_VOLORO>(
        &auth,
        false, // force_full_transfer_us = false
        false, // force_full_transfer_worldwide = false
        &version,
        ts.ctx(),
    );

    // Partial transfers allowed when no restrictions
    force_full_transfer::validate_rule(&rule, US, false, false);
    force_full_transfer::validate_rule(&rule, EU, false, false);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_validate_rule_full_transfer_passes() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let rule = force_full_transfer::new<TEST_VOLORO>(
        &auth,
        true, // force_full_transfer_us
        true, // force_full_transfer_worldwide
        &version,
        ts.ctx(),
    );

    // Exit investor passes (full transfer scenario)
    force_full_transfer::validate_rule(&rule, US, false, true);
    force_full_transfer::validate_rule(&rule, EU, false, true);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = force_full_transfer::EPartialTransferNotAllowed)]
fun test_validate_rule_us_partial_fails() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let rule = force_full_transfer::new<TEST_VOLORO>(
        &auth,
        true, // force_full_transfer_us
        false, // force_full_transfer_worldwide
        &version,
        ts.ctx(),
    );

    // Non-exit US investor should fail when force_us is enabled
    force_full_transfer::validate_rule(&rule, US, false, false);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_validate_rule_us_only_non_us_partial_allowed() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let rule = force_full_transfer::new<TEST_VOLORO>(
        &auth,
        true, // force_full_transfer_us
        false, // force_full_transfer_worldwide
        &version,
        ts.ctx(),
    );

    // Non-exit non-US investor should pass (only US restricted)
    force_full_transfer::validate_rule(&rule, EU, false, false);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = force_full_transfer::EPartialTransferNotAllowed)]
fun test_validate_rule_worldwide_partial_fails() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let rule = force_full_transfer::new<TEST_VOLORO>(
        &auth,
        false, // force_full_transfer_us
        true, // force_full_transfer_worldwide
        &version,
        ts.ctx(),
    );

    // Non-exit investor from any region should fail with worldwide restriction
    force_full_transfer::validate_rule(&rule, EU, false, false);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_validate_rule_special_wallet_exempt() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let rule = force_full_transfer::new<TEST_VOLORO>(
        &auth,
        true,
        true,
        &version,
        ts.ctx(),
    );

    // Special wallet is exempt from force full transfer
    force_full_transfer::validate_rule(&rule, US, true, false);
    force_full_transfer::validate_rule(&rule, EU, true, false);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_validate_rule_worldwide_exit_investor_allowed() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let rule = force_full_transfer::new<TEST_VOLORO>(
        &auth,
        false, // force_full_transfer_us
        true,  // force_full_transfer_worldwide
        &version,
        ts.ctx(),
    );

    // Exit investor should always be allowed, regardless of region
    force_full_transfer::validate_rule(&rule, US, false, true);
    force_full_transfer::validate_rule(&rule, EU, false, true);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_validate_rule_special_wallet_overrides_worldwide() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let rule = force_full_transfer::new<TEST_VOLORO>(
        &auth,
        true,  // force_full_transfer_us
        true,  // force_full_transfer_worldwide
        &version,
        ts.ctx(),
    );

    // Special wallet should bypass even worldwide restriction
    force_full_transfer::validate_rule(&rule, US, true, false);
    force_full_transfer::validate_rule(&rule, EU, true, false);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

