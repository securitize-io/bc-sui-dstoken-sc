#[test_only]
module securitize::investor_limits_tests;

use securitize::{
    investor_limits,
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
fun test_new_investor_limits_rule() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let rule = investor_limits::new<TEST_VOLORO>(
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

    let rule = investor_limits::new<TEST_VOLORO>(
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

    let mut wrapper = rule_wrapper::new(rule);

    investor_limits::set_total_limit<TEST_VOLORO>(
        &auth,
        &mut wrapper,
        2000,
        &version,
        ts.ctx(),
    );

    let rule = rule_wrapper::unwrap(wrapper);
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

    let rule = investor_limits::new<TEST_VOLORO>(
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

    let mut wrapper = rule_wrapper::new(rule);

    investor_limits::set_us_limit<TEST_VOLORO>(
        &auth,
        &mut wrapper,
        1000,
        &version,
        ts.ctx(),
    );

    let rule = rule_wrapper::unwrap(wrapper);
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

    let rule = investor_limits::new<TEST_VOLORO>(
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

    let rule = investor_limits::new<TEST_VOLORO>(
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

    let rule = investor_limits::new<TEST_VOLORO>(
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

    let rule = investor_limits::new<TEST_VOLORO>(
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

    let rule = investor_limits::new<TEST_VOLORO>(
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

    let rule = investor_limits::new<TEST_VOLORO>(
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

    let rule = investor_limits::new<TEST_VOLORO>(
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

    let rule = investor_limits::new<TEST_VOLORO>(
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

    let mut wrapper = rule_wrapper::new(rule);

    investor_limits::set_minimum_total_investors<TEST_VOLORO>(
        &auth,
        &mut wrapper,
        20,
        &version,
        ts.ctx(),
    );

    let rule = rule_wrapper::unwrap(wrapper);
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

    let rule = investor_limits::new<TEST_VOLORO>(
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

    let mut wrapper = rule_wrapper::new(rule);

    investor_limits::set_us_accredited_limit<TEST_VOLORO>(
        &auth,
        &mut wrapper,
        200,
        &version,
        ts.ctx(),
    );

    let rule = rule_wrapper::unwrap(wrapper);
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

    let rule = investor_limits::new<TEST_VOLORO>(
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

    let mut wrapper = rule_wrapper::new(rule);

    investor_limits::set_non_accredited_limit<TEST_VOLORO>(
        &auth,
        &mut wrapper,
        100,
        &version,
        ts.ctx(),
    );

    let rule = rule_wrapper::unwrap(wrapper);
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

    let rule = investor_limits::new<TEST_VOLORO>(
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

    let mut wrapper = rule_wrapper::new(rule);

    investor_limits::set_jp_limit<TEST_VOLORO>(
        &auth,
        &mut wrapper,
        100,
        &version,
        ts.ctx(),
    );

    let rule = rule_wrapper::unwrap(wrapper);
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

    let rule = investor_limits::new<TEST_VOLORO>(
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

    let mut wrapper = rule_wrapper::new(rule);

    investor_limits::set_eu_retail_limit<TEST_VOLORO>(
        &auth,
        &mut wrapper,
        100,
        &version,
        ts.ctx(),
    );

    let rule = rule_wrapper::unwrap(wrapper);
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

    let rule = investor_limits::new<TEST_VOLORO>(
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

    let mut wrapper = rule_wrapper::new(rule);

    investor_limits::set_max_us_percentage<TEST_VOLORO>(
        &auth,
        &mut wrapper,
        50,
        &version,
        ts.ctx(),
    );

    let rule = rule_wrapper::unwrap(wrapper);
    assert!(investor_limits::max_us_percentage(&rule) == 50, 0);

    ts::return_shared(auth);
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

    let rule = investor_limits::new<TEST_VOLORO>(
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

    let rule = investor_limits::new<TEST_VOLORO>(
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

    let rule = investor_limits::new<TEST_VOLORO>(
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

    let rule = investor_limits::new<TEST_VOLORO>(
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

    let rule = investor_limits::new<TEST_VOLORO>(
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

    let rule = investor_limits::new<TEST_VOLORO>(
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

    let rule = investor_limits::new<TEST_VOLORO>(
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

    let rule = investor_limits::new<TEST_VOLORO>(
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

    let rule = investor_limits::new<TEST_VOLORO>(
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

    let rule = investor_limits::new<TEST_VOLORO>(
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

    let rule = investor_limits::new<TEST_VOLORO>(
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

    let rule = investor_limits::new<TEST_VOLORO>(
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

    let rule = investor_limits::new<TEST_VOLORO>(
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

    let rule = investor_limits::new<TEST_VOLORO>(
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

    let rule = investor_limits::new<TEST_VOLORO>(
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

    let rule = investor_limits::new<TEST_VOLORO>(
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

    let rule = investor_limits::new<TEST_VOLORO>(
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

    let rule = investor_limits::new<TEST_VOLORO>(
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

    let rule = investor_limits::new<TEST_VOLORO>(
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

    let rule = investor_limits::new<TEST_VOLORO>(
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
    let rule = investor_limits::new<TEST_VOLORO>(
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
