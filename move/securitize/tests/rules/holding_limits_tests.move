#[test_only]
module securitize::holding_limits_tests;

use securitize::{
    holding_limits,
    rule_wrapper,
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
fun test_new_holding_limits_rule() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let rule = holding_limits::new<TEST_VOLORO>(
        &auth,
        100, // min_holdings_per_investor
        10000, // max_holdings_per_investor
        vector[US], // regions
        vector[200], // region_mins (US requires 200 minimum)
        &version,
        ts.ctx(),
    );

    assert!(holding_limits::min_holdings(&rule) == 100, 0);
    assert!(holding_limits::max_holdings(&rule) == 10000, 1);
    assert!(holding_limits::region_min_holdings(&rule, US) == 200, 2);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = holding_limits::ENotAuthorized)]
fun test_new_unauthorized() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(UNAUTHORIZED);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let _rule = holding_limits::new<TEST_VOLORO>(
        &auth,
        100,
        10000,
        vector[],
        vector[],
        &version,
        ts.ctx(),
    );

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_set_min_holdings() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let rule = holding_limits::new<TEST_VOLORO>(
        &auth,
        100,
        10000,
        vector[],
        vector[],
        &version,
        ts.ctx(),
    );

    // Wrap the rule for modification
    let mut wrapper = rule_wrapper::new(rule);

    holding_limits::set_min_holdings<TEST_VOLORO>(
        &auth,
        &mut wrapper,
        500,
        &version,
        ts.ctx(),
    );

    // Unwrap to verify changes
    let rule = rule_wrapper::unwrap(wrapper);
    assert!(holding_limits::min_holdings(&rule) == 500, 0);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_set_max_holdings() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let rule = holding_limits::new<TEST_VOLORO>(
        &auth,
        100,
        10000,
        vector[],
        vector[],
        &version,
        ts.ctx(),
    );

    // Wrap the rule for modification
    let mut wrapper = rule_wrapper::new(rule);

    holding_limits::set_max_holdings<TEST_VOLORO>(
        &auth,
        &mut wrapper,
        50000,
        &version,
        ts.ctx(),
    );

    // Unwrap to verify changes
    let rule = rule_wrapper::unwrap(wrapper);
    assert!(holding_limits::max_holdings(&rule) == 50000, 0);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_set_region_min_holdings() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let rule = holding_limits::new<TEST_VOLORO>(
        &auth,
        100,
        10000,
        vector[],
        vector[],
        &version,
        ts.ctx(),
    );

    // Wrap the rule for modification
    let mut wrapper = rule_wrapper::new(rule);

    holding_limits::set_region_min_holdings<TEST_VOLORO>(
        &auth,
        &mut wrapper,
        US,
        500,
        &version,
        ts.ctx(),
    );

    // Unwrap to verify changes
    let rule = rule_wrapper::unwrap(wrapper);
    assert!(holding_limits::region_min_holdings(&rule, US) == 500, 0);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_remove_region_min_holdings() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let rule = holding_limits::new<TEST_VOLORO>(
        &auth,
        100,
        10000,
        vector[US],
        vector[500],
        &version,
        ts.ctx(),
    );

    // Wrap the rule for modification
    let mut wrapper = rule_wrapper::new(rule);

    holding_limits::remove_region_min_holdings<TEST_VOLORO>(
        &auth,
        &mut wrapper,
        US,
        &version,
        ts.ctx(),
    );

    // Unwrap - Should not have US region anymore
    let _rule = rule_wrapper::unwrap(wrapper);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_validate_min_holdings_passes() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let rule = holding_limits::new<TEST_VOLORO>(
        &auth,
        100, // global minimum
        10000,
        vector[US],
        vector[200], // US minimum
        &version,
        ts.ctx(),
    );

    // Balance after meets both global and US minimum
    holding_limits::validate_min_holdings(&rule, 300, US);
    // Balance after meets global minimum for non-US region
    holding_limits::validate_min_holdings(&rule, 150, EU);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = holding_limits::EBelowMinHolding)]
fun test_validate_min_holdings_fails_global() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let rule = holding_limits::new<TEST_VOLORO>(
        &auth,
        100,
        10000,
        vector[],
        vector[],
        &version,
        ts.ctx(),
    );

    // Balance after is below global minimum
    holding_limits::validate_min_holdings(&rule, 50, EU);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = holding_limits::EBelowMinHolding)]
fun test_validate_min_holdings_fails_region() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let rule = holding_limits::new<TEST_VOLORO>(
        &auth,
        100,
        10000,
        vector[US],
        vector[200],
        &version,
        ts.ctx(),
    );

    // Balance after meets global but not US region minimum
    holding_limits::validate_min_holdings(&rule, 150, US);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_validate_max_holdings_passes() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let rule = holding_limits::new<TEST_VOLORO>(
        &auth,
        100,
        10000,
        vector[],
        vector[],
        &version,
        ts.ctx(),
    );

    // Balance after is within max
    holding_limits::validate_max_holdings(&rule, 5000);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = holding_limits::EAboveMaxHolding)]
fun test_validate_max_holdings_fails() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let rule = holding_limits::new<TEST_VOLORO>(
        &auth,
        100,
        10000,
        vector[],
        vector[],
        &version,
        ts.ctx(),
    );

    // Balance after exceeds max
    holding_limits::validate_max_holdings(&rule, 15000);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_validate_holding_limits_for_transfer() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let rule = holding_limits::new<TEST_VOLORO>(
        &auth,
        100,
        10000,
        vector[],
        vector[],
        &version,
        ts.ctx(),
    );

    // Valid transfer: sender has 1000, sends 400, receiver has 200
    // After: sender has 600 (>100), receiver has 600 (<10000)
    holding_limits::validate_holding_limits_for_transfer(
        &rule,
        400, // amount
        false, // from_is_special_wallet
        1000, // from_balance
        EU, // from_region
        200, // to_balance
        EU, // to_region
    );

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_validate_holding_limits_special_wallet_sender() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let rule = holding_limits::new<TEST_VOLORO>(
        &auth,
        100,
        10000,
        vector[],
        vector[],
        &version,
        ts.ctx(),
    );

    // Special wallet can go below minimum
    holding_limits::validate_holding_limits_for_transfer(
        &rule,
        900, // amount - would leave sender with 100 which is AT minimum
        true, // from_is_special_wallet - exempt from min check
        1000, // from_balance
        EU,
        200,
        EU,
    );

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_validate_holding_limits_for_issuance() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let rule = holding_limits::new<TEST_VOLORO>(
        &auth,
        100,
        10000,
        vector[],
        vector[],
        &version,
        ts.ctx(),
    );

    // Valid issuance: receiver will have 500 (within min/max)
    holding_limits::validate_holding_limits_for_issuance(
        &rule,
        500, // amount
        0, // to_balance (new investor)
        EU, // to_region
    );

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

// ==================== Unauthorized Setter Tests ====================

#[test]
#[expected_failure(abort_code = holding_limits::ENotAuthorized)]
fun test_set_min_holdings_unauthorized() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let rule = holding_limits::new<TEST_VOLORO>(
        &auth,
        100,
        10000,
        vector[],
        vector[],
        &version,
        ts.ctx(),
    );

    ts::return_shared(auth);
    ts::return_shared(version);

    // Try to set min holdings as unauthorized user
    ts.next_tx(UNAUTHORIZED);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let mut wrapper = rule_wrapper::new(rule);

    holding_limits::set_min_holdings<TEST_VOLORO>(
        &auth,
        &mut wrapper,
        500,
        &version,
        ts.ctx(),
    );

    abort
}

#[test]
#[expected_failure(abort_code = holding_limits::ENotAuthorized)]
fun test_set_max_holdings_unauthorized() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let rule = holding_limits::new<TEST_VOLORO>(
        &auth,
        100,
        10000,
        vector[],
        vector[],
        &version,
        ts.ctx(),
    );

    ts::return_shared(auth);
    ts::return_shared(version);

    // Try to set max holdings as unauthorized user
    ts.next_tx(UNAUTHORIZED);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let mut wrapper = rule_wrapper::new(rule);

    holding_limits::set_max_holdings<TEST_VOLORO>(
        &auth,
        &mut wrapper,
        50000,
        &version,
        ts.ctx(),
    );

    abort
}

#[test]
#[expected_failure(abort_code = holding_limits::ENotAuthorized)]
fun test_set_region_min_holdings_unauthorized() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let rule = holding_limits::new<TEST_VOLORO>(
        &auth,
        100,
        10000,
        vector[],
        vector[],
        &version,
        ts.ctx(),
    );

    ts::return_shared(auth);
    ts::return_shared(version);

    // Try to set region min holdings as unauthorized user
    ts.next_tx(UNAUTHORIZED);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let mut wrapper = rule_wrapper::new(rule);

    holding_limits::set_region_min_holdings<TEST_VOLORO>(
        &auth,
        &mut wrapper,
        US,
        500,
        &version,
        ts.ctx(),
    );

    abort
}

#[test]
#[expected_failure(abort_code = holding_limits::ENotAuthorized)]
fun test_remove_region_min_holdings_unauthorized() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let rule = holding_limits::new<TEST_VOLORO>(
        &auth,
        100,
        10000,
        vector[US],
        vector[500],
        &version,
        ts.ctx(),
    );

    ts::return_shared(auth);
    ts::return_shared(version);

    // Try to remove region min holdings as unauthorized user
    ts.next_tx(UNAUTHORIZED);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let mut wrapper = rule_wrapper::new(rule);

    holding_limits::remove_region_min_holdings<TEST_VOLORO>(
        &auth,
        &mut wrapper,
        US,
        &version,
        ts.ctx(),
    );

    abort
}

// ==================== Region Not Found Tests ====================

#[test]
#[expected_failure(abort_code = holding_limits::ERegionNotFound)]
fun test_region_min_holdings_not_found() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let rule = holding_limits::new<TEST_VOLORO>(
        &auth,
        100,
        10000,
        vector[US], // Only US configured
        vector[200],
        &version,
        ts.ctx(),
    );

    // Try to get region min for EU which is not configured
    let _min = holding_limits::region_min_holdings(&rule, EU);

    abort
}

// ==================== Remove Region Assertion Test ====================

#[test]
fun test_remove_region_min_holdings_with_assertion() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let rule = holding_limits::new<TEST_VOLORO>(
        &auth,
        100,
        10000,
        vector[US, EU],
        vector[500, 300],
        &version,
        ts.ctx(),
    );

    // Verify US region exists before removal
    assert!(holding_limits::region_min_holdings(&rule, US) == 500, 0);
    assert!(holding_limits::region_min_holdings(&rule, EU) == 300, 1);

    // Wrap the rule for modification
    let mut wrapper = rule_wrapper::new(rule);

    holding_limits::remove_region_min_holdings<TEST_VOLORO>(
        &auth,
        &mut wrapper,
        US,
        &version,
        ts.ctx(),
    );

    // Unwrap to verify changes
    let rule = rule_wrapper::unwrap(wrapper);

    // EU should still exist
    assert!(holding_limits::region_min_holdings(&rule, EU) == 300, 2);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

// ==================== Sender Zero Balance Tests ====================

#[test]
fun test_validate_sender_to_zero_balance() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let rule = holding_limits::new<TEST_VOLORO>(
        &auth,
        100, // global minimum
        10000,
        vector[],
        vector[],
        &version,
        ts.ctx(),
    );

    // Sender transfers ALL tokens (goes to zero) - this should pass
    // because zero balance is allowed (investor exits completely)
    holding_limits::validate_holding_limits_for_transfer(
        &rule,
        1000, // amount - sender's entire balance
        false, // from_is_special_wallet
        1000, // from_balance - will go to 0
        EU, // from_region
        500, // to_balance
        EU, // to_region
    );

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = holding_limits::EBelowMinHolding)]
fun test_validate_sender_below_min_but_not_zero() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let rule = holding_limits::new<TEST_VOLORO>(
        &auth,
        100, // global minimum
        10000,
        vector[],
        vector[],
        &version,
        ts.ctx(),
    );

    // Sender transfers tokens leaving balance BELOW minimum but NOT zero
    // This should fail because partial balance must meet minimum
    holding_limits::validate_holding_limits_for_transfer(
        &rule,
        950, // amount - leaves sender with 50
        false, // from_is_special_wallet
        1000, // from_balance - will go to 50 (below 100 min)
        EU, // from_region
        500, // to_balance
        EU, // to_region
    );

    abort
}
