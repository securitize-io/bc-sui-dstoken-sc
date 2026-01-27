#[test_only]
module securitize::lockup_restriction_tests;

use securitize::{
    lockup_restriction,
    registry_service::{Self, Issuance},
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

// Time constants (in milliseconds)
const ONE_YEAR_MS: u64 = 31_536_000_000;
const SIX_MONTHS_MS: u64 = 15_768_000_000;

fun setup_for_testing(ts: &mut Scenario) {
    ts.next_tx(ADMIN);
    setup_with_treasury(ts);
}

#[test]
fun test_new_lockup_restriction_rule() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let wrapper = lockup_restriction::new<TEST_VOLORO>(
        &auth,
        ONE_YEAR_MS, // us_lock_period_ms
        SIX_MONTHS_MS, // non_us_lock_period_ms
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(wrapper);

    assert!(lockup_restriction::us_lock_period(&rule) == ONE_YEAR_MS, 0);
    assert!(lockup_restriction::non_us_lock_period(&rule) == SIX_MONTHS_MS, 1);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = lockup_restriction::ENotAuthorized)]
fun test_new_unauthorized() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(UNAUTHORIZED);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let wrapper = lockup_restriction::new<TEST_VOLORO>(
        &auth,
        ONE_YEAR_MS,
        SIX_MONTHS_MS,
        &version,
        ts.ctx(),
    );
    let _ = unwrap_init(wrapper);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = lockup_restriction::ELockPeriodTooLong)]
fun test_new_lock_period_too_long() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    // 201 years exceeds the 200 year maximum
    let wrapper = lockup_restriction::new<TEST_VOLORO>(
        &auth,
        6_339_936_000_000, // > 200 years
        SIX_MONTHS_MS,
        &version,
        ts.ctx(),
    );
    let _ = unwrap_init(wrapper);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_set_us_lock_period() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let init_wrapper = lockup_restriction::new<TEST_VOLORO>(
        &auth,
        ONE_YEAR_MS,
        SIX_MONTHS_MS,
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(init_wrapper);

    // Wrap the rule for modification
    let mut wrapper = new_update(rule);

    lockup_restriction::set_us_lock_period<TEST_VOLORO>(
        &auth,
        &mut wrapper,
        SIX_MONTHS_MS,
        &version,
        ts.ctx(),
    );

    // Unwrap to verify changes
    let rule = unwrap_update(wrapper);
    assert!(lockup_restriction::us_lock_period(&rule) == SIX_MONTHS_MS, 0);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_set_non_us_lock_period() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let init_wrapper = lockup_restriction::new<TEST_VOLORO>(
        &auth,
        ONE_YEAR_MS,
        SIX_MONTHS_MS,
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(init_wrapper);

    // Wrap the rule for modification
    let mut wrapper = new_update(rule);

    lockup_restriction::set_non_us_lock_period<TEST_VOLORO>(
        &auth,
        &mut wrapper,
        ONE_YEAR_MS,
        &version,
        ts.ctx(),
    );

    // Unwrap to verify changes
    let rule = unwrap_update(wrapper);
    assert!(lockup_restriction::non_us_lock_period(&rule) == ONE_YEAR_MS, 0);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_get_lock_period_for_region() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let wrapper = lockup_restriction::new<TEST_VOLORO>(
        &auth,
        ONE_YEAR_MS,
        SIX_MONTHS_MS,
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(wrapper);

    assert!(lockup_restriction::lock_period_for_region(&rule, US) == ONE_YEAR_MS, 0);
    assert!(lockup_restriction::lock_period_for_region(&rule, EU) == SIX_MONTHS_MS, 1);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_compute_transferable_no_issuances() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let wrapper = lockup_restriction::new<TEST_VOLORO>(
        &auth,
        ONE_YEAR_MS,
        SIX_MONTHS_MS,
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(wrapper);

    let empty_issuances: vector<Issuance> = vector[];
    let transferable = lockup_restriction::compute_transferable_tokens(
        &rule,
        &empty_issuances,
        US,
        1000, // balance
        ONE_YEAR_MS + 1, // current time
    );

    // No issuances means all tokens are transferable
    assert!(transferable == 1000, 0);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_compute_transferable_zero_lock_period() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let wrapper = lockup_restriction::new<TEST_VOLORO>(
        &auth,
        0, // zero lock period for US
        SIX_MONTHS_MS,
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(wrapper);

    let empty_issuances: vector<Issuance> = vector[];
    let transferable = lockup_restriction::compute_transferable_tokens(
        &rule,
        &empty_issuances,
        US,
        1000,
        100, // any time
    );

    // Zero lock period means all tokens transferable
    assert!(transferable == 1000, 0);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_is_issuance_locked_zero_period() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let wrapper = lockup_restriction::new<TEST_VOLORO>(
        &auth,
        0, // zero lock period for US
        SIX_MONTHS_MS,
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(wrapper);

    let issuance = registry_service::new_issuance(500, 1000);

    // Zero lock period means never locked
    let is_locked = lockup_restriction::is_issuance_locked(
        &rule,
        &issuance,
        US,
        1001, // immediately after issuance
    );

    assert!(is_locked == false, 0);

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

    let wrapper = lockup_restriction::new<TEST_VOLORO>(
        &auth,
        ONE_YEAR_MS,
        SIX_MONTHS_MS,
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(wrapper);

    let empty_issuances: vector<Issuance> = vector[];

    // Special wallet is exempt from lockup restrictions
    lockup_restriction::validate_rule(
        &rule,
        &empty_issuances,
        1000, // amount
        US, // from_region
        true, // from_is_special_wallet
        1000, // current_transferable_balance (less than amount, but should pass)
        100, // timestamp_ms
    );

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_validate_rule_passes_with_sufficient_transferable() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let wrapper = lockup_restriction::new<TEST_VOLORO>(
        &auth,
        ONE_YEAR_MS,
        SIX_MONTHS_MS,
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(wrapper);

    let empty_issuances: vector<Issuance> = vector[];

    // No issuances = all balance is transferable
    lockup_restriction::validate_rule(
        &rule,
        &empty_issuances,
        500, // amount
        US,
        false, // not special wallet
        1000, // current_transferable_balance
        ONE_YEAR_MS + 1,
    );

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = lockup_restriction::EUnderLockup)]
fun test_validate_rule_fails_insufficient_transferable() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let wrapper = lockup_restriction::new<TEST_VOLORO>(
        &auth,
        ONE_YEAR_MS,
        SIX_MONTHS_MS,
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(wrapper);

    // Create an issuance that is still under lockup (issued at time 0, lock period is ONE_YEAR_MS)
    let issuance = registry_service::new_issuance(1000, 0); // 1000 tokens issued at time 0
    let issuances: vector<Issuance> = vector[issuance];

    // Trying to transfer 1000 tokens when all are locked (timestamp 100ms < ONE_YEAR_MS lock)
    lockup_restriction::validate_rule(
        &rule,
        &issuances,
        1000, // amount - trying to transfer all tokens
        US,
        false,
        1000, // current_transferable_balance
        100, // timestamp_ms - well before lockup ends
    );

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

// ==================== Compute Transferable Tests ====================

#[test]
fun test_compute_transferable_single_issuance_still_locked() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let wrapper = lockup_restriction::new<TEST_VOLORO>(
        &auth,
        ONE_YEAR_MS,
        SIX_MONTHS_MS,
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(wrapper);

    // Issuance of 500 tokens at time 0, still locked at time 100
    let issuance = registry_service::new_issuance(500, 0);
    let issuances: vector<Issuance> = vector[issuance];

    let transferable = lockup_restriction::compute_transferable_tokens(
        &rule,
        &issuances,
        US,
        1000, // total balance
        100, // current time - before lock period ends
    );

    // 500 locked from issuance, so only 500 transferable
    assert!(transferable == 500, 0);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_compute_transferable_single_issuance_unlocked() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let wrapper = lockup_restriction::new<TEST_VOLORO>(
        &auth,
        ONE_YEAR_MS,
        SIX_MONTHS_MS,
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(wrapper);

    // Issuance of 500 tokens at time 0, unlocked after ONE_YEAR_MS
    let issuance = registry_service::new_issuance(500, 0);
    let issuances: vector<Issuance> = vector[issuance];

    let transferable = lockup_restriction::compute_transferable_tokens(
        &rule,
        &issuances,
        US,
        1000, // total balance
        ONE_YEAR_MS + 1, // current time - after lock period ends
    );

    // All 1000 tokens are transferable
    assert!(transferable == 1000, 0);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_compute_transferable_multiple_issuances_partial_locked() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let wrapper = lockup_restriction::new<TEST_VOLORO>(
        &auth,
        ONE_YEAR_MS,
        SIX_MONTHS_MS,
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(wrapper);

    // First issuance: 300 tokens at time 0 (will be unlocked at ONE_YEAR_MS)
    // Second issuance: 400 tokens at time ONE_YEAR_MS (will be unlocked at 2*ONE_YEAR_MS)
    let issuance1 = registry_service::new_issuance(300, 0);
    let issuance2 = registry_service::new_issuance(400, ONE_YEAR_MS);
    let issuances: vector<Issuance> = vector[issuance1, issuance2];

    // At time ONE_YEAR_MS + 1: first issuance unlocked, second still locked
    let transferable = lockup_restriction::compute_transferable_tokens(
        &rule,
        &issuances,
        US,
        1000, // total balance (includes other sources)
        ONE_YEAR_MS + 1,
    );

    // 400 locked (second issuance), so 600 transferable
    assert!(transferable == 600, 0);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_compute_transferable_multiple_issuances_all_locked() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let wrapper = lockup_restriction::new<TEST_VOLORO>(
        &auth,
        ONE_YEAR_MS,
        SIX_MONTHS_MS,
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(wrapper);

    // Both issuances at time 0, both still locked at time 100
    let issuance1 = registry_service::new_issuance(300, 0);
    let issuance2 = registry_service::new_issuance(400, 0);
    let issuances: vector<Issuance> = vector[issuance1, issuance2];

    let transferable = lockup_restriction::compute_transferable_tokens(
        &rule,
        &issuances,
        US,
        1000, // total balance
        100, // current time - before any lock period ends
    );

    // 700 locked (300 + 400), so 300 transferable
    assert!(transferable == 300, 0);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_compute_transferable_multiple_issuances_all_unlocked() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let wrapper = lockup_restriction::new<TEST_VOLORO>(
        &auth,
        ONE_YEAR_MS,
        SIX_MONTHS_MS,
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(wrapper);

    // Both issuances at time 0, both unlocked after ONE_YEAR_MS
    let issuance1 = registry_service::new_issuance(300, 0);
    let issuance2 = registry_service::new_issuance(400, 0);
    let issuances: vector<Issuance> = vector[issuance1, issuance2];

    let transferable = lockup_restriction::compute_transferable_tokens(
        &rule,
        &issuances,
        US,
        1000,
        ONE_YEAR_MS + 1, // after lock period
    );

    // All 1000 transferable
    assert!(transferable == 1000, 0);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_compute_transferable_locked_exceeds_balance() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let wrapper = lockup_restriction::new<TEST_VOLORO>(
        &auth,
        ONE_YEAR_MS,
        SIX_MONTHS_MS,
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(wrapper);

    // Issuance of 1500 tokens, but balance is only 1000 (some were transferred out)
    let issuance = registry_service::new_issuance(1500, 0);
    let issuances: vector<Issuance> = vector[issuance];

    let transferable = lockup_restriction::compute_transferable_tokens(
        &rule,
        &issuances,
        US,
        1000, // balance is less than issuance
        100, // still locked
    );

    // Locked amount (1500) > balance (1000), so transferable = 0
    assert!(transferable == 0, 0);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_compute_transferable_non_us_region() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let wrapper = lockup_restriction::new<TEST_VOLORO>(
        &auth,
        ONE_YEAR_MS, // US lock
        SIX_MONTHS_MS, // non-US lock (shorter)
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(wrapper);

    let issuance = registry_service::new_issuance(500, 0);
    let issuances: vector<Issuance> = vector[issuance];

    // At SIX_MONTHS_MS + 1: non-US issuance is unlocked
    let transferable = lockup_restriction::compute_transferable_tokens(
        &rule,
        &issuances,
        EU, // non-US region
        1000,
        SIX_MONTHS_MS + 1,
    );

    // All 1000 transferable (non-US lock period has passed)
    assert!(transferable == 1000, 0);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_compute_transferable_non_us_still_locked() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let wrapper = lockup_restriction::new<TEST_VOLORO>(
        &auth,
        ONE_YEAR_MS,
        SIX_MONTHS_MS,
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(wrapper);

    let issuance = registry_service::new_issuance(500, 0);
    let issuances: vector<Issuance> = vector[issuance];

    // At time 100: non-US issuance is still locked
    let transferable = lockup_restriction::compute_transferable_tokens(
        &rule,
        &issuances,
        EU,
        1000,
        100, // before SIX_MONTHS_MS
    );

    // 500 locked, so 500 transferable
    assert!(transferable == 500, 0);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_compute_transferable_at_exact_unlock_time() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let wrapper = lockup_restriction::new<TEST_VOLORO>(
        &auth,
        ONE_YEAR_MS,
        SIX_MONTHS_MS,
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(wrapper);

    // Issuance at time 1000
    let issuance = registry_service::new_issuance(500, 1000);
    let issuances: vector<Issuance> = vector[issuance];

    // One millisecond BEFORE the unlock boundary - still locked
    // issuance_time + lock_period > timestamp → 1000 + ONE_YEAR_MS > 1000 + ONE_YEAR_MS - 1 → true (locked)
    let transferable_before = lockup_restriction::compute_transferable_tokens(
        &rule,
        &issuances,
        US,
        1000,
        1000 + ONE_YEAR_MS - 1,
    );

    // Still locked (1ms before boundary)
    assert!(transferable_before == 500, 0);

    // At EXACTLY the unlock boundary - UNLOCKED
    // issuance_time + lock_period > timestamp → 1000 + ONE_YEAR_MS > 1000 + ONE_YEAR_MS → false (unlocked)
    // The condition uses > not >=, so at exactly the boundary it's unlocked
    let transferable_at_boundary = lockup_restriction::compute_transferable_tokens(
        &rule,
        &issuances,
        US,
        1000,
        1000 + ONE_YEAR_MS,
    );

    assert!(transferable_at_boundary == 1000, 1);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

// ==================== Is Issuance Locked Tests ====================

#[test]
fun test_is_issuance_locked_true() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let wrapper = lockup_restriction::new<TEST_VOLORO>(
        &auth,
        ONE_YEAR_MS,
        SIX_MONTHS_MS,
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(wrapper);

    let issuance = registry_service::new_issuance(500, 1000);

    // Still locked before lock period ends
    let is_locked = lockup_restriction::is_issuance_locked(
        &rule,
        &issuance,
        US,
        1000 + 100, // 100ms after issuance, well before ONE_YEAR_MS
    );

    assert!(is_locked == true, 0);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_is_issuance_locked_false() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let wrapper = lockup_restriction::new<TEST_VOLORO>(
        &auth,
        ONE_YEAR_MS,
        SIX_MONTHS_MS,
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(wrapper);

    let issuance = registry_service::new_issuance(500, 1000);

    // Unlocked after lock period ends
    let is_locked = lockup_restriction::is_issuance_locked(
        &rule,
        &issuance,
        US,
        1000 + ONE_YEAR_MS + 1,
    );

    assert!(is_locked == false, 0);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

// ==================== Validate Rule Edge Cases ====================

#[test]
fun test_validate_rule_transfer_exact_transferable_amount() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let wrapper = lockup_restriction::new<TEST_VOLORO>(
        &auth,
        ONE_YEAR_MS,
        SIX_MONTHS_MS,
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(wrapper);

    // 500 locked from issuance, balance is 1000, so 500 transferable
    let issuance = registry_service::new_issuance(500, 0);
    let issuances: vector<Issuance> = vector[issuance];

    // Transfer exactly the transferable amount (500)
    lockup_restriction::validate_rule(
        &rule,
        &issuances,
        500, // amount equals transferable
        US,
        false,
        1000, // current_transferable_balance
        100, // before lock period ends
    );

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = lockup_restriction::EUnderLockup)]
fun test_validate_rule_transfer_one_over_transferable() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let wrapper = lockup_restriction::new<TEST_VOLORO>(
        &auth,
        ONE_YEAR_MS,
        SIX_MONTHS_MS,
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(wrapper);

    // 500 locked from issuance, balance is 1000, so 500 transferable
    let issuance = registry_service::new_issuance(500, 0);
    let issuances: vector<Issuance> = vector[issuance];

    // Try to transfer one more than transferable (501 > 500)
    lockup_restriction::validate_rule(
        &rule,
        &issuances,
        501, // one more than transferable
        US,
        false,
        1000,
        100,
    );

    abort
}

#[test]
fun test_validate_rule_non_us_shorter_lockup() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let wrapper = lockup_restriction::new<TEST_VOLORO>(
        &auth,
        ONE_YEAR_MS, // US: 1 year
        SIX_MONTHS_MS, // EU: 6 months
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(wrapper);

    let issuance = registry_service::new_issuance(500, 0);
    let issuances: vector<Issuance> = vector[issuance];

    // EU investor at 6 months + 1: fully unlocked
    lockup_restriction::validate_rule(
        &rule,
        &issuances,
        1000, // transfer all
        EU,
        false,
        1000,
        SIX_MONTHS_MS + 1,
    );

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = lockup_restriction::EUnderLockup)]
fun test_validate_rule_us_still_locked_when_eu_unlocked() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let wrapper = lockup_restriction::new<TEST_VOLORO>(
        &auth,
        ONE_YEAR_MS, // US: 1 year
        SIX_MONTHS_MS, // EU: 6 months
        &version,
        ts.ctx(),
    );
    let rule = unwrap_init(wrapper);

    let issuance = registry_service::new_issuance(1000, 0);
    let issuances: vector<Issuance> = vector[issuance];

    // US investor at 6 months + 1: EU would be unlocked, but US still locked
    lockup_restriction::validate_rule(
        &rule,
        &issuances,
        1000, // try to transfer all
        US, // US region with longer lock
        false,
        1000,
        SIX_MONTHS_MS + 1, // after EU lock but before US lock
    );

    abort
}
