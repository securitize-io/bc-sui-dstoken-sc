#[test_only]
module securitize::flowback_restriction_tests;

use securitize::{
    flowback_restriction,
    rule_wrapper::{unwrap_init, new_update, unwrap_update},
    test_helpers::{TEST_VOLORO, setup_with_treasury},
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
fun test_new_flowback_restriction_rule() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let wrapper = flowback_restriction::new<TEST_VOLORO>(
        &auth,
        1000000, // block_flowback_end_time_ms
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(wrapper);

    assert!(flowback_restriction::flowback_end_time(&rule) == 1000000, 0);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = flowback_restriction::ENotAuthorized)]
fun test_new_unauthorized() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(UNAUTHORIZED);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    // Should fail - UNAUTHORIZED has no ManageRules ability
    let wrapper = flowback_restriction::new<TEST_VOLORO>(
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
fun test_set_flowback_end_time() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let init_wrapper = flowback_restriction::new<TEST_VOLORO>(
        &auth,
        1000000,
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(init_wrapper);

    assert!(flowback_restriction::flowback_end_time(&rule) == 1000000, 0);

    // Wrap the rule for modification
    let mut wrapper = new_update(rule);

    flowback_restriction::set_flowback_end_time<TEST_VOLORO>(
        &auth,
        &mut wrapper,
        2000000,
        &version,
        ts.ctx(),
    );

    // Unwrap to verify changes
    let rule = unwrap_update(wrapper);
    assert!(flowback_restriction::flowback_end_time(&rule) == 2000000, 1);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_validate_rule_us_to_us_allowed() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let wrapper = flowback_restriction::new<TEST_VOLORO>(
        &auth,
        1000000, // restriction ends at 1000000
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(wrapper);

    // US to US is always allowed (not a flowback)
    flowback_restriction::validate_rule(&rule, US, US, false, 500000);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_validate_rule_non_us_to_non_us_allowed() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let wrapper = flowback_restriction::new<TEST_VOLORO>(
        &auth,
        1000000,
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(wrapper);

    // Non-US to Non-US is always allowed
    flowback_restriction::validate_rule(&rule, EU, EU, false, 500000);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_validate_rule_non_us_to_us_after_restriction() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let wrapper = flowback_restriction::new<TEST_VOLORO>(
        &auth,
        1000000, // restriction ends at 1000000
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(wrapper);

    // Non-US to US after restriction period is allowed
    flowback_restriction::validate_rule(&rule, EU, US, false, 1500000);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = flowback_restriction::EFlowbackRestricted)]
fun test_validate_rule_non_us_to_us_during_restriction() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let wrapper = flowback_restriction::new<TEST_VOLORO>(
        &auth,
        1000000, // restriction ends at 1000000
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(wrapper);

    // Non-US to US during restriction period should fail
    flowback_restriction::validate_rule(&rule, EU, US, false, 500000);

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

    let wrapper = flowback_restriction::new<TEST_VOLORO>(
        &auth,
        1000000,
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(wrapper);

    // Special wallet is exempt from flowback restriction
    flowback_restriction::validate_rule(&rule, EU, US, true, 500000);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = flowback_restriction::EFlowbackRestricted)]
fun test_validate_rule_permanent_restriction() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let wrapper = flowback_restriction::new<TEST_VOLORO>(
        &auth,
        0, // end_time = 0 means permanent restriction
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(wrapper);

    // Non-US to US with permanent restriction should fail
    flowback_restriction::validate_rule(&rule, EU, US, false, 999999999);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}
