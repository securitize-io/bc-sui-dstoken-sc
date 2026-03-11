#[test_only]
module securitize::investor_limits_tests;

use pas::account::Account;
use securitize::{
    compliance_service::ComplianceConfig,
    ds_token::{Self, Treasury},
    investor_limits,
    registry_service::InvestorInfo,
    rule_wrapper::{unwrap_init, new_update, unwrap_update},
    test_helpers::{Self as test_helpers, TEST_VOLORO, setup_with_treasury},
    trust_service::Auth,
    version::Version
};
use sui::{clock, test_scenario::{Self as ts, Scenario}};

const ADMIN: address = @0x001;
const UNAUTHORIZED: address = @0x002;
const WALLET1: address = @0x1001;

fun setup_for_testing(ts: &mut Scenario) {
    ts.next_tx(ADMIN);
    setup_with_treasury(ts);
}
#[test]
fun test_new_investor_limits_rule() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let wrapper = investor_limits::new<TEST_VOLORO>(
        &auth,
        1000, // total_investors_limit
        10, // minimum_total_investors
        500, // us_investors_limit
        200, // us_accredited_limit
        100, // non_accredited_limit
        50, // jp_investors_limit
        75, // eu_retail_limit
        25, // max_us_percentage
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(wrapper);

    assert!(investor_limits::total_limit(&rule) == 1000, 0);
    assert!(investor_limits::minimum_total_investors(&rule) == 10, 1);
    assert!(investor_limits::us_limit(&rule) == 500, 2);
    assert!(investor_limits::us_accredited_limit(&rule) == 200, 3);
    assert!(investor_limits::non_accredited_limit(&rule) == 100, 4);
    assert!(investor_limits::jp_limit(&rule) == 50, 5);
    assert!(investor_limits::eu_retail_limit(&rule) == 75, 6);
    assert!(investor_limits::max_us_percentage(&rule) == 25, 7);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = investor_limits::ENotAuthorized)]
fun test_new_unauthorized() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(UNAUTHORIZED);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let wrapper = investor_limits::new<TEST_VOLORO>(
        &auth,
        1000,
        10,
        500,
        200,
        100,
        50,
        75,
        25,
        &version,
        ts.ctx(),
    );
    let _ = unwrap_init(wrapper);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = investor_limits::ENotAuthorized)]
fun test_set_new_total_limit_unauthorized() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let _rule = investor_limits::new<TEST_VOLORO>(
        &auth,
        1000,
        10,
        500,
        200,
        100,
        50,
        75,
        25,
        &version,
        ts.ctx(),
    );

    ts.next_tx(UNAUTHORIZED);

    let rule = _rule.unwrap_init();
    let mut wrapper = new_update(rule);

    investor_limits::set_total_limit<TEST_VOLORO>(
        &auth,
        &mut wrapper,
        2000,
        &version,
        ts.ctx(),
    );

    unwrap_update(wrapper);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = investor_limits::ENotAuthorized)]
fun test_set_minimum_total_investors_unauthorized() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let _rule = investor_limits::new<TEST_VOLORO>(
        &auth,
        1000,
        10,
        500,
        200,
        100,
        50,
        75,
        25,
        &version,
        ts.ctx(),
    );

    ts.next_tx(UNAUTHORIZED);

    let rule = _rule.unwrap_init();
    let mut wrapper = new_update(rule);

    investor_limits::set_minimum_total_investors<TEST_VOLORO>(
        &auth,
        &mut wrapper,
        20,
        &version,
        ts.ctx(),
    );

    unwrap_update(wrapper);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = investor_limits::ENotAuthorized)]
fun test_set_us_limit_unauthorized() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let _rule = investor_limits::new<TEST_VOLORO>(
        &auth,
        1000,
        10,
        500,
        200,
        100,
        50,
        75,
        25,
        &version,
        ts.ctx(),
    );

    ts.next_tx(UNAUTHORIZED);

    let rule = _rule.unwrap_init();
    let mut wrapper = new_update(rule);

    investor_limits::set_us_limit<TEST_VOLORO>(
        &auth,
        &mut wrapper,
        1000,
        &version,
        ts.ctx(),
    );

    unwrap_update(wrapper);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = investor_limits::ENotAuthorized)]
fun test_set_us_accredited_limit_unauthorized() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let _rule = investor_limits::new<TEST_VOLORO>(
        &auth,
        1000,
        10,
        500,
        200,
        100,
        50,
        75,
        25,
        &version,
        ts.ctx(),
    );

    ts.next_tx(UNAUTHORIZED);

    let rule = _rule.unwrap_init();
    let mut wrapper = new_update(rule);

    investor_limits::set_us_accredited_limit<TEST_VOLORO>(
        &auth,
        &mut wrapper,
        300,
        &version,
        ts.ctx(),
    );

    unwrap_update(wrapper);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = investor_limits::ENotAuthorized)]
fun test_set_non_accredited_limit_unauthorized() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let _rule = investor_limits::new<TEST_VOLORO>(
        &auth,
        1000,
        10,
        500,
        200,
        100,
        50,
        75,
        25,
        &version,
        ts.ctx(),
    );

    ts.next_tx(UNAUTHORIZED);

    let rule = _rule.unwrap_init();
    let mut wrapper = new_update(rule);

    investor_limits::set_non_accredited_limit<TEST_VOLORO>(
        &auth,
        &mut wrapper,
        150,
        &version,
        ts.ctx(),
    );

    unwrap_update(wrapper);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = investor_limits::ENotAuthorized)]
fun test_set_jp_limit_unauthorized() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let _rule = investor_limits::new<TEST_VOLORO>(
        &auth,
        1000,
        10,
        500,
        200,
        100,
        50,
        75,
        25,
        &version,
        ts.ctx(),
    );

    ts.next_tx(UNAUTHORIZED);

    let rule = _rule.unwrap_init();
    let mut wrapper = new_update(rule);

    investor_limits::set_jp_limit<TEST_VOLORO>(
        &auth,
        &mut wrapper,
        100,
        &version,
        ts.ctx(),
    );

    unwrap_update(wrapper);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = investor_limits::ENotAuthorized)]
fun test_set_eu_retail_limit_unauthorized() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let _rule = investor_limits::new<TEST_VOLORO>(
        &auth,
        1000,
        10,
        500,
        200,
        100,
        50,
        75,
        25,
        &version,
        ts.ctx(),
    );

    ts.next_tx(UNAUTHORIZED);

    let rule = _rule.unwrap_init();
    let mut wrapper = new_update(rule);

    investor_limits::set_eu_retail_limit<TEST_VOLORO>(
        &auth,
        &mut wrapper,
        150,
        &version,
        ts.ctx(),
    );

    unwrap_update(wrapper);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = investor_limits::ENotAuthorized)]
fun test_set_max_us_percentage_unauthorized() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let _rule = investor_limits::new<TEST_VOLORO>(
        &auth,
        1000,
        10,
        500,
        200,
        100,
        50,
        75,
        25,
        &version,
        ts.ctx(),
    );

    ts.next_tx(UNAUTHORIZED);

    let rule = _rule.unwrap_init();
    let mut wrapper = new_update(rule);

    investor_limits::set_max_us_percentage<TEST_VOLORO>(
        &auth,
        &mut wrapper,
        50,
        &version,
        ts.ctx(),
    );

    unwrap_update(wrapper);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_set_total_limit() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let init_wrapper = investor_limits::new<TEST_VOLORO>(
        &auth,
        1000,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(init_wrapper);

    let mut wrapper = new_update(rule);

    investor_limits::set_total_limit<TEST_VOLORO>(
        &auth,
        &mut wrapper,
        2000,
        &version,
        ts.ctx(),
    );

    let rule = unwrap_update(wrapper);
    assert!(investor_limits::total_limit(&rule) == 2000, 0);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_set_us_limit() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let init_wrapper = investor_limits::new<TEST_VOLORO>(
        &auth,
        0,
        0,
        500,
        0,
        0,
        0,
        0,
        0,
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(init_wrapper);

    let mut wrapper = new_update(rule);

    investor_limits::set_us_limit<TEST_VOLORO>(
        &auth,
        &mut wrapper,
        1000,
        &version,
        ts.ctx(),
    );

    let rule = unwrap_update(wrapper);
    assert!(investor_limits::us_limit(&rule) == 1000, 0);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_validate_transfer_total_investors_passes() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let init_wrapper = investor_limits::new<TEST_VOLORO>(
        &auth,
        100, // total_investors_limit
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(init_wrapper);

    // Current count 50, adding new investor (not exit), should pass
    investor_limits::validate_transfer_total_investors(
        &rule,
        50, // current_count
        false, // from_is_exit_investor
        true, // to_is_new_investor
    );

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = investor_limits::EMaxInvestorsExceeded)]
fun test_validate_transfer_total_investors_fails() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let init_wrapper = investor_limits::new<TEST_VOLORO>(
        &auth,
        100, // total_investors_limit
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(init_wrapper);

    // Current count 100 (at limit), adding new investor should fail
    investor_limits::validate_transfer_total_investors(
        &rule,
        100, // current_count - at limit
        false, // from_is_exit_investor
        true, // to_is_new_investor
    );

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_validate_transfer_total_investors_exit_and_new() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let init_wrapper = investor_limits::new<TEST_VOLORO>(
        &auth,
        100, // total_investors_limit
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(init_wrapper);

    // At limit but one exits and one enters - net zero change
    investor_limits::validate_transfer_total_investors(
        &rule,
        100, // current_count - at limit
        true, // from_is_exit_investor - one leaving
        true, // to_is_new_investor - one entering
    );

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_validate_issuance_total_investors_passes() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let init_wrapper = investor_limits::new<TEST_VOLORO>(
        &auth,
        100,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(init_wrapper);

    investor_limits::validate_issuance_total_investors(
        &rule,
        50, // current_count
        true, // to_is_new_investor
    );

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = investor_limits::EMaxInvestorsExceeded)]
fun test_validate_issuance_total_investors_fails() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let init_wrapper = investor_limits::new<TEST_VOLORO>(
        &auth,
        100,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(init_wrapper);

    investor_limits::validate_issuance_total_investors(
        &rule,
        100, // current_count - at limit
        true, // to_is_new_investor
    );

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_validate_transfer_minimum_total_investors() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let init_wrapper = investor_limits::new<TEST_VOLORO>(
        &auth,
        0, // total_investors_limit (no max)
        10, // minimum_total_investors
        0,
        0,
        0,
        0,
        0,
        0,
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(init_wrapper);

    // 20 investors, one exits but new one enters - stays above minimum
    investor_limits::validate_transfer_minimum_total_investors(
        &rule,
        20, // current_count
        true, // from_is_exit_investor
        false, // to_is_new_investor
    );

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = investor_limits::EBelowMinimumInvestors)]
fun test_validate_transfer_minimum_total_investors_fails() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let init_wrapper = investor_limits::new<TEST_VOLORO>(
        &auth,
        0,
        10,
        0,
        0,
        0,
        0,
        0,
        0,
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(init_wrapper);

    // 10 investors (at minimum), one exits, no new investor - would go below
    investor_limits::validate_transfer_minimum_total_investors(
        &rule,
        10, // current_count - at minimum
        true, // from_is_exit_investor
        false, // to_is_new_investor
    );

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_effective_us_limit_absolute_only() {
    // When only absolute limit is set
    let result = investor_limits::effective_us_limit(100, 0, 500);
    assert!(result == 100, 0);
}

#[test]
fun test_effective_us_limit_percentage_only() {
    // When only percentage limit is set (25% of 400 = 100)
    let result = investor_limits::effective_us_limit(0, 25, 400);
    assert!(result == 100, 0);
}

#[test]
fun test_effective_us_limit_both_absolute_lower() {
    // Both set, absolute is lower
    let result = investor_limits::effective_us_limit(50, 25, 400); // 50 vs 100
    assert!(result == 50, 0);
}

#[test]
fun test_effective_us_limit_both_percentage_lower() {
    // Both set, percentage is lower
    let result = investor_limits::effective_us_limit(200, 25, 400); // 200 vs 100
    assert!(result == 100, 0);
}

#[test]
fun test_effective_us_limit_unlimited() {
    // Both zero means unlimited
    let result = investor_limits::effective_us_limit(0, 0, 500);
    assert!(result == 0, 0);
}

#[test]
fun test_set_minimum_total_investors() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let init_wrapper = investor_limits::new<TEST_VOLORO>(
        &auth,
        0,
        10,
        0,
        0,
        0,
        0,
        0,
        0,
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(init_wrapper);

    let mut wrapper = new_update(rule);

    investor_limits::set_minimum_total_investors<TEST_VOLORO>(
        &auth,
        &mut wrapper,
        20,
        &version,
        ts.ctx(),
    );

    let rule = unwrap_update(wrapper);
    assert!(investor_limits::minimum_total_investors(&rule) == 20, 0);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_set_us_accredited_limit() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let init_wrapper = investor_limits::new<TEST_VOLORO>(
        &auth,
        0,
        0,
        0,
        100,
        0,
        0,
        0,
        0,
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(init_wrapper);

    let mut wrapper = new_update(rule);

    investor_limits::set_us_accredited_limit<TEST_VOLORO>(
        &auth,
        &mut wrapper,
        200,
        &version,
        ts.ctx(),
    );

    let rule = unwrap_update(wrapper);
    assert!(investor_limits::us_accredited_limit(&rule) == 200, 0);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_set_non_accredited_limit() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let init_wrapper = investor_limits::new<TEST_VOLORO>(
        &auth,
        0,
        0,
        0,
        0,
        50,
        0,
        0,
        0,
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(init_wrapper);

    let mut wrapper = new_update(rule);

    investor_limits::set_non_accredited_limit<TEST_VOLORO>(
        &auth,
        &mut wrapper,
        100,
        &version,
        ts.ctx(),
    );

    let rule = unwrap_update(wrapper);
    assert!(investor_limits::non_accredited_limit(&rule) == 100, 0);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_set_jp_limit() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let init_wrapper = investor_limits::new<TEST_VOLORO>(
        &auth,
        0,
        0,
        0,
        0,
        0,
        50,
        0,
        0,
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(init_wrapper);

    let mut wrapper = new_update(rule);

    investor_limits::set_jp_limit<TEST_VOLORO>(
        &auth,
        &mut wrapper,
        100,
        &version,
        ts.ctx(),
    );

    let rule = unwrap_update(wrapper);
    assert!(investor_limits::jp_limit(&rule) == 100, 0);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_set_eu_retail_limit() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let init_wrapper = investor_limits::new<TEST_VOLORO>(
        &auth,
        0,
        0,
        0,
        0,
        0,
        0,
        50,
        0,
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(init_wrapper);

    let mut wrapper = new_update(rule);

    investor_limits::set_eu_retail_limit<TEST_VOLORO>(
        &auth,
        &mut wrapper,
        100,
        &version,
        ts.ctx(),
    );

    let rule = unwrap_update(wrapper);
    assert!(investor_limits::eu_retail_limit(&rule) == 100, 0);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_set_max_us_percentage() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let init_wrapper = investor_limits::new<TEST_VOLORO>(
        &auth,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        25,
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(init_wrapper);

    let mut wrapper = new_update(rule);

    investor_limits::set_max_us_percentage<TEST_VOLORO>(
        &auth,
        &mut wrapper,
        50,
        &version,
        ts.ctx(),
    );

    let rule = unwrap_update(wrapper);
    assert!(investor_limits::max_us_percentage(&rule) == 50, 0);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

// tests for validations

#[test]
fun test_validate_investor_limits_for_transfer_to_us_passes() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);
    // init_coin_registry(&mut ts);

    ts.next_tx(ADMIN);
    let investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();

    // let mut registry = ts.take_shared<CoinRegistry>();
    let version = ts.take_shared<Version>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();

    let rule = investor_limits::new<TEST_VOLORO>(
        &auth,
        1000, // total_investors_limit
        0,
        500, // us_investors_limit
        200, // us_accredited_limit
        100, // non_accredited_limit
        0,
        0,
        50, // max_us_percentage
        &version,
        ts.ctx(),
    );

    investor_limits::validate_investor_limits_for_transfer<TEST_VOLORO>(
        &(rule.unwrap_init()),
        &investor_info,
        true,
        true,
        true,
        1, // US country
        b"California".to_string(),
        true,
        true,
        true,
        true,
        true,
    );

    ts::return_shared(auth);
    ts::return_shared(investor_info);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_validate_investor_limits_for_transfer_to_eu_passes() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    let country = b"Greece".to_string();
    let investor_id = b"investor_123".to_string();

    // Register investor with wallet (creates PAS account)
    test_helpers::register_investor_with_wallet(&mut ts, b"investor_123", WALLET1);

    // Set attributes and country
    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();

    investor_info.set_attribute(&auth, investor_id, 2, 2, 500, &version, ts.ctx());
    investor_info.set_country_compliance<TEST_VOLORO>(country, 2); // EU country
    assert!(investor_info.get_country_compliance(country) == 2, 0);
    investor_info.set_country<TEST_VOLORO>(&auth, investor_id, country, &version, ts.ctx());

    ts::return_shared(auth);
    ts::return_shared(investor_info);
    ts::return_shared(version);

    // Issue tokens — record_issuance handles balance + investor count adjustment
    ts.next_tx(ADMIN);
    let mut treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let account = ts.take_shared<Account>();
    let clock = clock::create_for_testing(ts.ctx());

    ds_token::issue_tokens(
        &mut treasury,
        &auth,
        &mut investor_info,
        &mut compliance,
        &account,
        WALLET1,
        1000,
        0,
        b"".to_string(),
        &version,
        vector[],
        vector[],
        clock.timestamp_ms(),
        &clock,
        ts.ctx(),
    );

    clock.destroy_for_testing();
    ts::return_shared(treasury);
    ts::return_shared(auth);
    ts::return_shared(investor_info);
    ts::return_shared(compliance);
    ts::return_shared(version);
    ts::return_shared(account);

    // Validate investor limits for transfer
    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();

    assert!(investor_info.get_eu_retail_investor_count(country).is_some() == true, 1);

    let rule = investor_limits::new<TEST_VOLORO>(
        &auth,
        1000, // total_investors_limit
        0,
        500, // us_investors_limit
        200, // us_accredited_limit
        100, // non_accredited_limit
        0,
        100, // also tests validate_issuance_eu_retail flow
        50, // max_us_percentage
        &version,
        ts.ctx(),
    );

    investor_limits::validate_investor_limits_for_transfer<TEST_VOLORO>(
        &(rule.unwrap_init()),
        &investor_info,
        true,
        true,
        true,
        2, // EU country
        country,
        true,
        false,
        true,
        true,
        true,
    );

    ts::return_shared(auth);
    ts::return_shared(investor_info);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_validate_investor_limits_for_transfer_to_jp_passes() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();

    let version = ts.take_shared<Version>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();

    let rule = investor_limits::new<TEST_VOLORO>(
        &auth,
        1000, // total_investors_limit
        0,
        500, // us_investors_limit
        200, // us_accredited_limit
        100, // non_accredited_limit
        0,
        0,
        50, // max_us_percentage
        &version,
        ts.ctx(),
    );

    investor_limits::validate_investor_limits_for_transfer<TEST_VOLORO>(
        &(rule.unwrap_init()),
        &investor_info,
        true,
        true,
        true,
        8, // JP country
        b"Tokyo".to_string(),
        true,
        true,
        true,
        true,
        true,
    );

    ts::return_shared(auth);
    ts::return_shared(investor_info);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_validate_investor_limits_for_transfer_to_eu__not_accredited_passes() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    let country = b"Greece".to_string();

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();

    let rule = investor_limits::new<TEST_VOLORO>(
        &auth,
        1000, // total_investors_limit
        0,
        500, // us_investors_limit
        200, // us_accredited_limit
        100, // non_accredited_limit
        0,
        0,
        50, // max_us_percentage
        &version,
        ts.ctx(),
    );

    investor_limits::validate_investor_limits_for_transfer<TEST_VOLORO>(
        &(rule.unwrap_init()),
        &investor_info,
        true,
        true,
        true,
        2, // EU country
        country,
        false,
        true,
        true,
        true,
        true,
    );

    ts::return_shared(auth);
    ts::return_shared(investor_info);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_validate_investor_limits_for_issuance_returns_when_non_new_investor() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();

    let rule = investor_limits::new<TEST_VOLORO>(
        &auth,
        1000, // total_investors_limit
        0,
        500, // us_investors_limit
        200, // us_accredited_limit
        100, // non_accredited_limit
        0,
        0,
        50, // max_us_percentage
        &version,
        ts.ctx(),
    );

    investor_limits::validate_investor_limits_for_issuance<TEST_VOLORO>(
        &(rule.unwrap_init()),
        &investor_info,
        1, // US region
        b"California".to_string(),
        true,
        true,
        false,
    );

    ts::return_shared(auth);
    ts::return_shared(investor_info);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_validate_investor_limits_for_issuance_passes_when_total_investors_under_limit() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();

    let rule = investor_limits::new<TEST_VOLORO>(
        &auth,
        1000, // total_investors_limit
        0,
        500, // us_investors_limit
        200, // us_accredited_limit
        100, // non_accredited_limit
        0,
        0,
        50, // max_us_percentage
        &version,
        ts.ctx(),
    );

    investor_limits::validate_investor_limits_for_issuance<TEST_VOLORO>(
        &(rule.unwrap_init()),
        &investor_info,
        1, // US region
        b"California".to_string(),
        false,
        true,
        true,
    );

    ts::return_shared(auth);
    ts::return_shared(investor_info);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_validate_investor_limits_for_issuance_returns_when_is_accredited() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();

    let rule = investor_limits::new<TEST_VOLORO>(
        &auth,
        1000, // total_investors_limit
        0,
        500, // us_investors_limit
        200, // us_accredited_limit
        100, // non_accredited_limit
        0,
        0,
        50, // max_us_percentage
        &version,
        ts.ctx(),
    );

    investor_limits::validate_investor_limits_for_issuance<TEST_VOLORO>(
        &(rule.unwrap_init()),
        &investor_info,
        1, // US region
        b"California".to_string(),
        true,
        true,
        true,
    );

    ts::return_shared(auth);
    ts::return_shared(investor_info);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_validate_investor_limits_for_issuance_returns_when_is_not_accredited() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();

    let rule = investor_limits::new<TEST_VOLORO>(
        &auth,
        1000, // total_investors_limit
        0,
        500, // us_investors_limit
        200, // us_accredited_limit
        100, // non_accredited_limit
        0,
        0,
        50, // max_us_percentage
        &version,
        ts.ctx(),
    );

    investor_limits::validate_investor_limits_for_issuance<TEST_VOLORO>(
        &(rule.unwrap_init()),
        &investor_info,
        1, // US region
        b"California".to_string(),
        false,
        true,
        true,
    );

    ts::return_shared(auth);
    ts::return_shared(investor_info);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_validate_investor_limits_for_issuance_passes_to_eu_region() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();

    let rule = investor_limits::new<TEST_VOLORO>(
        &auth,
        1000, // total_investors_limit
        0,
        500, // us_investors_limit
        200, // us_accredited_limit
        100, // non_accredited_limit
        0,
        0,
        50, // max_us_percentage
        &version,
        ts.ctx(),
    );

    let region = 2; // EU region
    let country = b"Germany".to_string();

    investor_info.set_eu_retail_investors_country_if_not_exists<TEST_VOLORO>(country); // EU country

    assert!(investor_info.get_eu_retail_investor_count(country).is_some() == true, 1);

    investor_limits::validate_investor_limits_for_issuance<TEST_VOLORO>(
        &(rule.unwrap_init()),
        &investor_info,
        region, // EU region
        country,
        true,
        false,
        true,
    );

    ts::return_shared(auth);
    ts::return_shared(investor_info);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_validate_investor_limits_for_issuance_passes_to_jp_region() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();

    let rule = investor_limits::new<TEST_VOLORO>(
        &auth,
        1000, // total_investors_limit
        0,
        500, // us_investors_limit
        200, // us_accredited_limit
        100, // non_accredited_limit
        10,
        0,
        50, // max_us_percentage
        &version,
        ts.ctx(),
    );

    investor_limits::validate_investor_limits_for_issuance<TEST_VOLORO>(
        &(rule.unwrap_init()),
        &investor_info,
        8, // JP region
        b"Kyoto".to_string(),
        false,
        true,
        true,
    );

    ts::return_shared(auth);
    ts::return_shared(investor_info);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_validate_us_investor_limits_passes_when_to_is_accredited() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();

    let rule = investor_limits::new<TEST_VOLORO>(
        &auth,
        1000, // total_investors_limit
        0,
        500, // us_investors_limit
        200, // us_accredited_limit
        100, // non_accredited_limit
        10,
        0,
        50, // max_us_percentage
        &version,
        ts.ctx(),
    );

    investor_limits::validate_us_investor_limits(
        &(rule.unwrap_init()),
        &investor_info,
        true,
        true,
        false,
        true,
        true,
    );

    ts::return_shared(auth);
    ts::return_shared(investor_info);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_validate_transfer_us_investors_passes() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let init_wrapper = investor_limits::new<TEST_VOLORO>(
        &auth,
        0,
        0,
        100,
        0,
        0,
        0,
        0,
        0, // us_investors_limit = 100
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(init_wrapper);

    // Current 50 US, adding new US investor should pass
    investor_limits::validate_transfer_us_investors(
        &rule,
        50, // current_us_count
        500, // total_count
        false, // from_is_exit_investor
        true, // to_is_new_us_investor
        false, // equal_region
    );

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = investor_limits::EMaxUSInvestorsExceeded)]
fun test_validate_transfer_us_investors_fails() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let init_wrapper = investor_limits::new<TEST_VOLORO>(
        &auth,
        0,
        0,
        100,
        0,
        0,
        0,
        0,
        0,
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(init_wrapper);

    // At limit, adding new US investor should fail
    investor_limits::validate_transfer_us_investors(
        &rule,
        100, // current_us_count - at limit
        500, // total_count
        false, // from_is_exit_investor
        true, // to_is_new_us_investor
        false, // equal_region
    );

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_validate_transfer_us_accredited_passes() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let init_wrapper = investor_limits::new<TEST_VOLORO>(
        &auth,
        0,
        0,
        0,
        100,
        0,
        0,
        0,
        0, // us_accredited_limit = 100
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(init_wrapper);

    investor_limits::validate_transfer_us_accredited(
        &rule,
        50, // current_count
        true, // to_is_new_investor
        false, // from_is_exit_investor
        false, // from_is_accredited
        false, // equal_region
    );

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = investor_limits::EMaxUSAccreditedExceeded)]
fun test_validate_transfer_us_accredited_fails() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let init_wrapper = investor_limits::new<TEST_VOLORO>(
        &auth,
        0,
        0,
        0,
        100,
        0,
        0,
        0,
        0,
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(init_wrapper);

    investor_limits::validate_transfer_us_accredited(
        &rule,
        100, // current_count - at limit
        true, // to_is_new_investor
        false, // from_is_exit_investor
        false, // from_is_accredited
        false, // equal_region
    );

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_validate_transfer_non_accredited_passes() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let init_wrapper = investor_limits::new<TEST_VOLORO>(
        &auth,
        0,
        0,
        0,
        0,
        100,
        0,
        0,
        0, // non_accredited_limit = 100
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(init_wrapper);

    investor_limits::validate_transfer_non_accredited(
        &rule,
        50, // current_non_accredited
        true, // to_is_new_investor
        false, // from_is_exit_investor
        true, // from_is_accredited
    );

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = investor_limits::EMaxNonAccreditedExceeded)]
fun test_validate_transfer_non_accredited_fails() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let init_wrapper = investor_limits::new<TEST_VOLORO>(
        &auth,
        0,
        0,
        0,
        0,
        100,
        0,
        0,
        0,
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(init_wrapper);

    investor_limits::validate_transfer_non_accredited(
        &rule,
        100, // current_non_accredited - at limit
        true, // to_is_new_investor
        false, // from_is_exit_investor
        true, // from_is_accredited
    );

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_validate_transfer_jp_investors_passes() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let init_wrapper = investor_limits::new<TEST_VOLORO>(
        &auth,
        0,
        0,
        0,
        0,
        0,
        100,
        0,
        0, // jp_investors_limit = 100
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(init_wrapper);

    investor_limits::validate_transfer_jp_investors(
        &rule,
        50, // current_count
        false, // from_is_exit_investor
        true, // to_is_new_jp_investor
        false, // equal_region
    );

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = investor_limits::EMaxJPInvestorsExceeded)]
fun test_validate_transfer_jp_investors_fails() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let init_wrapper = investor_limits::new<TEST_VOLORO>(
        &auth,
        0,
        0,
        0,
        0,
        0,
        100,
        0,
        0,
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(init_wrapper);

    investor_limits::validate_transfer_jp_investors(
        &rule,
        100, // current_count - at limit
        false, // from_is_exit_investor
        true, // to_is_new_jp_investor
        false, // equal_region
    );

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_validate_transfer_eu_retail_passes() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let init_wrapper = investor_limits::new<TEST_VOLORO>(
        &auth,
        0,
        0,
        0,
        0,
        0,
        0,
        100,
        0, // eu_retail_limit = 100
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(init_wrapper);

    investor_limits::validate_transfer_eu_retail(
        &rule,
        50, // current_count
        false, // from_is_exit_investor
        false, // from_is_qualified
        true, // to_is_new_eu_retail_investor
        false, // equal_country
    );

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = investor_limits::EMaxEURetailExceeded)]
fun test_validate_transfer_eu_retail_fails() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let init_wrapper = investor_limits::new<TEST_VOLORO>(
        &auth,
        0,
        0,
        0,
        0,
        0,
        0,
        100,
        0,
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(init_wrapper);

    investor_limits::validate_transfer_eu_retail(
        &rule,
        100, // current_count - at limit
        false, // from_is_exit_investor
        false, // from_is_qualified
        true, // to_is_new_eu_retail_investor
        false, // equal_country
    );

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_validate_issuance_us_investors_passes() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let init_wrapper = investor_limits::new<TEST_VOLORO>(
        &auth,
        0,
        0,
        100,
        0,
        0,
        0,
        0,
        0,
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(init_wrapper);

    investor_limits::validate_issuance_us_investors(
        &rule,
        50, // current_us_count
        500, // total_count
        true, // is_new_us_investor
    );

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = investor_limits::EMaxUSInvestorsExceeded)]
fun test_validate_issuance_us_investors_fails() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let init_wrapper = investor_limits::new<TEST_VOLORO>(
        &auth,
        0,
        0,
        100,
        0,
        0,
        0,
        0,
        0,
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(init_wrapper);

    investor_limits::validate_issuance_us_investors(
        &rule,
        100, // current_us_count - at limit
        500, // total_count
        true, // is_new_us_investor
    );

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_validate_issuance_us_accredited_passes() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let init_wrapper = investor_limits::new<TEST_VOLORO>(
        &auth,
        0,
        0,
        0,
        100,
        0,
        0,
        0,
        0,
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(init_wrapper);

    investor_limits::validate_issuance_us_accredited(
        &rule,
        50, // current_count
        true, // to_is_new_investor
    );

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = investor_limits::EMaxUSAccreditedExceeded)]
fun test_validate_issuance_us_accredited_fails() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let init_wrapper = investor_limits::new<TEST_VOLORO>(
        &auth,
        0,
        0,
        0,
        100,
        0,
        0,
        0,
        0,
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(init_wrapper);

    investor_limits::validate_issuance_us_accredited(
        &rule,
        100, // current_count - at limit
        true, // to_is_new_investor
    );

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_validate_issuance_non_accredited_passes() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let init_wrapper = investor_limits::new<TEST_VOLORO>(
        &auth,
        0,
        0,
        0,
        0,
        100,
        0,
        0,
        0,
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(init_wrapper);

    investor_limits::validate_issuance_non_accredited(
        &rule,
        50, // current_count
        true, // to_is_new_investor
    );

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = investor_limits::EMaxNonAccreditedExceeded)]
fun test_validate_issuance_non_accredited_fails() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let init_wrapper = investor_limits::new<TEST_VOLORO>(
        &auth,
        0,
        0,
        0,
        0,
        100,
        0,
        0,
        0,
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(init_wrapper);

    investor_limits::validate_issuance_non_accredited(
        &rule,
        100, // current_count - at limit
        true, // to_is_new_investor
    );

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_validate_issuance_eu_retail_passes() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let init_wrapper = investor_limits::new<TEST_VOLORO>(
        &auth,
        0,
        0,
        0,
        0,
        0,
        0,
        100,
        0,
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(init_wrapper);

    investor_limits::validate_issuance_eu_retail(
        &rule,
        50, // current_count
        true, // to_is_new_eu_retail_investor
    );

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = investor_limits::EMaxEURetailExceeded)]
fun test_validate_issuance_eu_retail_fails() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let init_wrapper = investor_limits::new<TEST_VOLORO>(
        &auth,
        0,
        0,
        0,
        0,
        0,
        0,
        100,
        0,
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(init_wrapper);

    investor_limits::validate_issuance_eu_retail(
        &rule,
        100, // current_count - at limit
        true, // to_is_new_eu_retail_investor
    );

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_validate_issuance_jp_investors_passes() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let init_wrapper = investor_limits::new<TEST_VOLORO>(
        &auth,
        0,
        0,
        0,
        0,
        0,
        100,
        0,
        0,
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(init_wrapper);

    investor_limits::validate_issuance_jp_investors(
        &rule,
        50, // current_count
        true, // to_is_new_jp_investor
    );

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = investor_limits::EMaxJPInvestorsExceeded)]
fun test_validate_issuance_jp_investors_fails() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let init_wrapper = investor_limits::new<TEST_VOLORO>(
        &auth,
        0,
        0,
        0,
        0,
        0,
        100,
        0,
        0,
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(init_wrapper);

    investor_limits::validate_issuance_jp_investors(
        &rule,
        100, // current_count - at limit
        true, // to_is_new_jp_investor
    );

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_zero_limits_bypass_validation() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    // All limits set to 0 (unlimited)
    let init_wrapper = investor_limits::new<TEST_VOLORO>(
        &auth,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(init_wrapper);

    // All these should pass even with high counts
    investor_limits::validate_transfer_total_investors(&rule, 10000, false, true);
    investor_limits::validate_issuance_total_investors(&rule, 10000, true);
    investor_limits::validate_transfer_us_investors(&rule, 10000, 50000, false, true, false);
    investor_limits::validate_issuance_us_investors(&rule, 10000, 50000, true);
    investor_limits::validate_transfer_us_accredited(&rule, 10000, true, false, false, false);
    investor_limits::validate_issuance_us_accredited(&rule, 10000, true);
    investor_limits::validate_transfer_non_accredited(&rule, 10000, true, false, true);
    investor_limits::validate_issuance_non_accredited(&rule, 10000, true);
    investor_limits::validate_transfer_jp_investors(&rule, 10000, false, true, false);
    investor_limits::validate_issuance_jp_investors(&rule, 10000, true);
    investor_limits::validate_transfer_eu_retail(&rule, 10000, false, false, true, false);
    investor_limits::validate_issuance_eu_retail(&rule, 10000, true);
    investor_limits::validate_transfer_minimum_total_investors(&rule, 1, true, false);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}
