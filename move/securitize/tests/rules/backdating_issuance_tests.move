#[test_only]
module securitize::backdating_issuance_tests;

use securitize::{
    backdating_issuance,
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
fun test_new_backdating_issuance_allowed() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let wrapper = backdating_issuance::new<TEST_VOLORO>(
        &auth,
        false, // disallow_backdating = false means backdating IS allowed
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(wrapper);

    assert!(backdating_issuance::is_backdating_allowed(&rule), 0);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_new_backdating_issuance_disallowed() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let wrapper = backdating_issuance::new<TEST_VOLORO>(
        &auth,
        true, // disallow_backdating = true means backdating is NOT allowed
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(wrapper);

    assert!(!backdating_issuance::is_backdating_allowed(&rule), 0);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = backdating_issuance::ENotAuthorized)]
fun test_new_unauthorized() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(UNAUTHORIZED);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let wrapper = backdating_issuance::new<TEST_VOLORO>(
        &auth,
        true,
        &version,
        ts.ctx(),
    );
    let _ = unwrap_init(wrapper);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_set_disallow_backdating_enable() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    // Start with backdating allowed (disallow_backdating=false)
    let init_wrapper = backdating_issuance::new<TEST_VOLORO>(
        &auth,
        false,
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(init_wrapper);

    assert!(backdating_issuance::is_backdating_allowed(&rule), 0);

    // Wrap the rule for modification
    let mut wrapper = new_update(rule);

    // Enable disallow_backdating (disallow=true means backdating NOT allowed)
    backdating_issuance::set_disallow_backdating<TEST_VOLORO>(
        &auth,
        &mut wrapper,
        true,
        &version,
        ts.ctx(),
    );

    // Unwrap to verify changes
    let rule = unwrap_update(wrapper);
    assert!(!backdating_issuance::is_backdating_allowed(&rule), 1);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_set_disallow_backdating_disable() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    // Start with backdating disallowed (disallow_backdating=true)
    let init_wrapper = backdating_issuance::new<TEST_VOLORO>(
        &auth,
        true,
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(init_wrapper);

    assert!(!backdating_issuance::is_backdating_allowed(&rule), 0);

    // Wrap the rule for modification
    let mut wrapper = new_update(rule);

    // Disable disallow_backdating (disallow=false means backdating IS allowed)
    backdating_issuance::set_disallow_backdating<TEST_VOLORO>(
        &auth,
        &mut wrapper,
        false,
        &version,
        ts.ctx(),
    );

    // Unwrap to verify changes
    let rule = unwrap_update(wrapper);
    assert!(backdating_issuance::is_backdating_allowed(&rule), 1);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = backdating_issuance::ENotAuthorized)]
fun test_set_disallow_backdating_unauthorized() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let init_wrapper = backdating_issuance::new<TEST_VOLORO>(
        &auth,
        false,
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(init_wrapper);

    // Wrap the rule for modification
    let mut wrapper = new_update(rule);

    ts::return_shared(auth);
    ts::return_shared(version);

    ts.next_tx(UNAUTHORIZED);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    // Should fail - UNAUTHORIZED has no ManageRules ability
    backdating_issuance::set_disallow_backdating<TEST_VOLORO>(
        &auth,
        &mut wrapper,
        true,
        &version,
        ts.ctx(),
    );

    // Unwrap (won't reach here due to expected failure)
    let _rule = unwrap_update(wrapper);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}
