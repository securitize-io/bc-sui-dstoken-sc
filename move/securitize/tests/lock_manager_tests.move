#[test_only]
module securitize::lock_manager_tests;

use securitize::{
    abilities::{LockInvestor, UnlockInvestor, SetLiquidateOnly, AddLockRecord, RemoveLockRecord},
    lock_manager,
    registry_service::{Self, InvestorInfo},
    setup::{Self, SetupRegistry},
    trust_service::{Self, Auth, Master},
    version::{Self, Version}
};
use sui::{clock, test_scenario::{Self as ts, Scenario}};
use securitize::test_helpers::TEST_VOLORO;
use securitize::test_helpers::setup_with_treasury;

const ADMIN: address = @0x001;
const UNAUTHORIZED: address = @0x002;

fun setup_for_testing(ts: &mut Scenario) {
    ts.next_tx(ADMIN);
    setup_with_treasury(ts);
}

#[test]
fun test_is_investor_locked_initial() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    // Register an investor first
    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    // Initially, investor should not be locked
    assert!(!lock_manager::is_investor_locked(&registry, b"INV001".to_string()), 0);

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_lock_and_unlock_investor() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    // Register an investor
    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    // Lock the investor
    lock_manager::lock_investor<TEST_VOLORO>(
        &mut registry,
        b"INV001".to_string(),
        &auth,
        &version,
        ts.ctx(),
    );

    assert!(lock_manager::is_investor_locked(&registry, b"INV001".to_string()), 0);

    // Unlock the investor
    lock_manager::unlock_investor<TEST_VOLORO>(
        &mut registry,
        b"INV001".to_string(),
        &auth,
        &version,
        ts.ctx(),
    );

    assert!(!lock_manager::is_investor_locked(&registry, b"INV001".to_string()), 1);

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = lock_manager::ENotAuthorized)]
fun test_lock_investor_unauthorized() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    // Register an investor
    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );
    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);

    // Try to lock as unauthorized user
    ts.next_tx(UNAUTHORIZED);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    lock_manager::lock_investor<TEST_VOLORO>(
        &mut registry,
        b"INV001".to_string(),
        &auth,
        &version,
        ts.ctx(),
    );

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = lock_manager::EAlreadyLocked)]
fun test_lock_already_locked() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    // Register and lock an investor
    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    lock_manager::lock_investor<TEST_VOLORO>(
        &mut registry,
        b"INV001".to_string(),
        &auth,
        &version,
        ts.ctx(),
    );

    // Try to lock again - should fail
    lock_manager::lock_investor<TEST_VOLORO>(
        &mut registry,
        b"INV001".to_string(),
        &auth,
        &version,
        ts.ctx(),
    );

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = lock_manager::ENotLocked)]
fun test_unlock_not_locked() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    // Register an investor (not locked)
    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    // Try to unlock - should fail since not locked
    lock_manager::unlock_investor<TEST_VOLORO>(
        &mut registry,
        b"INV001".to_string(),
        &auth,
        &version,
        ts.ctx(),
    );

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_set_liquidate_only() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    // Register an investor
    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    // Initially not in liquidate-only mode
    assert!(!lock_manager::is_liquidate_only(&registry, b"INV001".to_string()), 0);

    // Enable liquidate-only
    lock_manager::set_liquidate_only<TEST_VOLORO>(
        &mut registry,
        b"INV001".to_string(),
        true,
        &auth,
        &version,
        ts.ctx(),
    );

    assert!(lock_manager::is_liquidate_only(&registry, b"INV001".to_string()), 1);

    // Disable liquidate-only
    lock_manager::set_liquidate_only<TEST_VOLORO>(
        &mut registry,
        b"INV001".to_string(),
        false,
        &auth,
        &version,
        ts.ctx(),
    );

    assert!(!lock_manager::is_liquidate_only(&registry, b"INV001".to_string()), 2);

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_add_and_remove_lock() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let clock = clock::create_for_testing(ts.ctx());

    // Register an investor
    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    // Initially no locks
    assert!(lock_manager::lock_count(&registry, b"INV001".to_string()) == 0, 0);

    // Add a lock (release_time_ms = 0 means permanent)
    lock_manager::add_lock<TEST_VOLORO>(
        &mut registry,
        b"INV001".to_string(),
        1000, // value
        1, // reason_code
        b"Test lock".to_string(),
        0, // release_time_ms (0 = permanent)
        &auth,
        &version,
        &clock,
        ts.ctx(),
    );

    assert!(lock_manager::lock_count(&registry, b"INV001".to_string()) == 1, 1);

    // Remove the lock
    lock_manager::remove_lock<TEST_VOLORO>(
        &mut registry,
        b"INV001".to_string(),
        0, // index
        &auth,
        &version,
        ts.ctx(),
    );

    assert!(lock_manager::lock_count(&registry, b"INV001".to_string()) == 0, 2);

    clock::destroy_for_testing(clock);
    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_compute_transferable_not_locked() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    // Register an investor
    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    // No locks, full balance should be transferable
    let transferable = lock_manager::compute_transferable(
        &registry,
        b"INV001".to_string(),
        1000, // balance
        0, // timestamp_ms
    );

    assert!(transferable == 1000, 0);

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_compute_transferable_fully_locked() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    // Register and fully lock an investor
    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    lock_manager::lock_investor<TEST_VOLORO>(
        &mut registry,
        b"INV001".to_string(),
        &auth,
        &version,
        ts.ctx(),
    );

    // Fully locked, nothing should be transferable
    let transferable = lock_manager::compute_transferable(
        &registry,
        b"INV001".to_string(),
        1000, // balance
        0, // timestamp_ms
    );

    assert!(transferable == 0, 0);

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = lock_manager::EInvalidValue)]
fun test_add_lock_zero_value() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let clock = clock::create_for_testing(ts.ctx());

    // Register an investor
    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    // Try to add a lock with zero value - should fail
    lock_manager::add_lock<TEST_VOLORO>(
        &mut registry,
        b"INV001".to_string(),
        0, // value = 0 (invalid)
        1,
        b"Test".to_string(),
        0,
        &auth,
        &version,
        &clock,
        ts.ctx(),
    );

    clock::destroy_for_testing(clock);
    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = lock_manager::EIndexOutOfRange)]
fun test_remove_lock_invalid_index() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    // Register an investor (no locks added)
    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    // Try to remove a lock at index 0 when there are no locks
    lock_manager::remove_lock<TEST_VOLORO>(
        &mut registry,
        b"INV001".to_string(),
        0, // index - out of range
        &auth,
        &version,
        ts.ctx(),
    );

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

// ==================== Unauthorized Access Tests ====================

#[test]
#[expected_failure(abort_code = lock_manager::ENotAuthorized)]
fun test_unlock_investor_unauthorized() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    // Register and lock an investor as admin
    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    lock_manager::lock_investor<TEST_VOLORO>(
        &mut registry,
        b"INV001".to_string(),
        &auth,
        &version,
        ts.ctx(),
    );

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);

    // Try to unlock as unauthorized user
    ts.next_tx(UNAUTHORIZED);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    lock_manager::unlock_investor<TEST_VOLORO>(
        &mut registry,
        b"INV001".to_string(),
        &auth,
        &version,
        ts.ctx(),
    );

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = lock_manager::ENotAuthorized)]
fun test_set_liquidate_only_unauthorized() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);

    // Try to set liquidate only as unauthorized user
    ts.next_tx(UNAUTHORIZED);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    lock_manager::set_liquidate_only<TEST_VOLORO>(
        &mut registry,
        b"INV001".to_string(),
        true,
        &auth,
        &version,
        ts.ctx(),
    );

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = lock_manager::ENotAuthorized)]
fun test_add_lock_unauthorized() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);

    // Try to add lock as unauthorized user
    ts.next_tx(UNAUTHORIZED);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let clock = clock::create_for_testing(ts.ctx());

    lock_manager::add_lock<TEST_VOLORO>(
        &mut registry,
        b"INV001".to_string(),
        100,
        1,
        b"Test".to_string(),
        0,
        &auth,
        &version,
        &clock,
        ts.ctx(),
    );

    clock::destroy_for_testing(clock);
    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = lock_manager::ENotAuthorized)]
fun test_remove_lock_unauthorized() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let clock = clock::create_for_testing(ts.ctx());

    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    // Add a lock as admin
    lock_manager::add_lock<TEST_VOLORO>(
        &mut registry,
        b"INV001".to_string(),
        100,
        1,
        b"Test".to_string(),
        0,
        &auth,
        &version,
        &clock,
        ts.ctx(),
    );

    clock::destroy_for_testing(clock);
    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);

    // Try to remove lock as unauthorized user
    ts.next_tx(UNAUTHORIZED);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    lock_manager::remove_lock<TEST_VOLORO>(
        &mut registry,
        b"INV001".to_string(),
        0,
        &auth,
        &version,
        ts.ctx(),
    );

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

// ==================== Lock Record Validation Tests ====================

#[test]
#[expected_failure(abort_code = lock_manager::EInvalidTime)]
fun test_add_lock_release_time_in_past() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let mut clock = clock::create_for_testing(ts.ctx());

    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    // Set clock to current time (e.g., 10000ms)
    clock::set_for_testing(&mut clock, 10000);

    // Try to add lock with release time in the past
    lock_manager::add_lock<TEST_VOLORO>(
        &mut registry,
        b"INV001".to_string(),
        100,
        1,
        b"Test".to_string(),
        5000, // release_time_ms in the past
        &auth,
        &version,
        &clock,
        ts.ctx(),
    );

    clock::destroy_for_testing(clock);
    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_add_lock_with_future_release_time() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let mut clock = clock::create_for_testing(ts.ctx());

    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    // Set clock to current time
    clock::set_for_testing(&mut clock, 10000);

    // Add lock with release time in the future
    lock_manager::add_lock<TEST_VOLORO>(
        &mut registry,
        b"INV001".to_string(),
        100,
        1,
        b"Future lock".to_string(),
        20000, // release_time_ms in the future
        &auth,
        &version,
        &clock,
        ts.ctx(),
    );

    assert!(lock_manager::lock_count(&registry, b"INV001".to_string()) == 1, 0);

    clock::destroy_for_testing(clock);
    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

// ==================== Multiple Lock Records Tests ====================

#[test]
fun test_multiple_locks_count() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let clock = clock::create_for_testing(ts.ctx());

    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    // Add multiple locks
    lock_manager::add_lock<TEST_VOLORO>(
        &mut registry,
        b"INV001".to_string(),
        100,
        1,
        b"Lock 1".to_string(),
        0,
        &auth,
        &version,
        &clock,
        ts.ctx(),
    );

    lock_manager::add_lock<TEST_VOLORO>(
        &mut registry,
        b"INV001".to_string(),
        200,
        2,
        b"Lock 2".to_string(),
        0,
        &auth,
        &version,
        &clock,
        ts.ctx(),
    );

    lock_manager::add_lock<TEST_VOLORO>(
        &mut registry,
        b"INV001".to_string(),
        300,
        3,
        b"Lock 3".to_string(),
        0,
        &auth,
        &version,
        &clock,
        ts.ctx(),
    );

    assert!(lock_manager::lock_count(&registry, b"INV001".to_string()) == 3, 0);

    clock::destroy_for_testing(clock);
    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_compute_transferable_with_multiple_locks() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let mut clock = clock::create_for_testing(ts.ctx());

    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    // Set clock to current time
    clock::set_for_testing(&mut clock, 1000);
    let current_time = 1000u64;

    // Add locks with different release times
    // Lock 1: 100 tokens, releases at 2000ms
    lock_manager::add_lock<TEST_VOLORO>(
        &mut registry,
        b"INV001".to_string(),
        100,
        1,
        b"Lock 1".to_string(),
        2000,
        &auth,
        &version,
        &clock,
        ts.ctx(),
    );

    // Lock 2: 100 tokens, releases at 3000ms
    lock_manager::add_lock<TEST_VOLORO>(
        &mut registry,
        b"INV001".to_string(),
        100,
        2,
        b"Lock 2".to_string(),
        3000,
        &auth,
        &version,
        &clock,
        ts.ctx(),
    );

    // Balance of 300, 200 locked at current_time
    let transferable = lock_manager::compute_transferable(
        &registry,
        b"INV001".to_string(),
        300, // balance
        current_time,
    );
    assert!(transferable == 100, 0); // 300 - 200 = 100

    // After first lock releases (at 2001ms), 100 still locked
    let transferable_after_first = lock_manager::compute_transferable(
        &registry,
        b"INV001".to_string(),
        300,
        2001,
    );
    assert!(transferable_after_first == 200, 1); // 300 - 100 = 200

    // After all locks release (at 3001ms), nothing locked
    let transferable_after_all = lock_manager::compute_transferable(
        &registry,
        b"INV001".to_string(),
        300,
        3001,
    );
    assert!(transferable_after_all == 300, 2); // All transferable

    clock::destroy_for_testing(clock);
    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_compute_transferable_locks_exceed_balance() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let clock = clock::create_for_testing(ts.ctx());

    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    // Add lock for more than balance
    lock_manager::add_lock<TEST_VOLORO>(
        &mut registry,
        b"INV001".to_string(),
        500,
        1,
        b"Big lock".to_string(),
        0, // permanent
        &auth,
        &version,
        &clock,
        ts.ctx(),
    );

    // Balance of 100, but 500 locked - should return 0
    let transferable = lock_manager::compute_transferable(
        &registry,
        b"INV001".to_string(),
        100, // balance less than locked
        0,
    );
    assert!(transferable == 0, 0);

    clock::destroy_for_testing(clock);
    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

// ==================== Remove Lock with Multiple Locks Tests ====================

#[test]
fun test_remove_middle_lock() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let clock = clock::create_for_testing(ts.ctx());

    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    // Add three locks
    lock_manager::add_lock<TEST_VOLORO>(
        &mut registry,
        b"INV001".to_string(),
        100,
        1,
        b"Lock 1".to_string(),
        0,
        &auth,
        &version,
        &clock,
        ts.ctx(),
    );

    lock_manager::add_lock<TEST_VOLORO>(
        &mut registry,
        b"INV001".to_string(),
        200,
        2,
        b"Lock 2".to_string(),
        0,
        &auth,
        &version,
        &clock,
        ts.ctx(),
    );

    lock_manager::add_lock<TEST_VOLORO>(
        &mut registry,
        b"INV001".to_string(),
        300,
        3,
        b"Lock 3".to_string(),
        0,
        &auth,
        &version,
        &clock,
        ts.ctx(),
    );

    assert!(lock_manager::lock_count(&registry, b"INV001".to_string()) == 3, 0);

    // Remove the middle lock (index 1)
    lock_manager::remove_lock<TEST_VOLORO>(
        &mut registry,
        b"INV001".to_string(),
        1,
        &auth,
        &version,
        ts.ctx(),
    );

    assert!(lock_manager::lock_count(&registry, b"INV001".to_string()) == 2, 1);

    // Verify transferable: 100 + 300 = 400 locked
    let transferable = lock_manager::compute_transferable(
        &registry,
        b"INV001".to_string(),
        600,
        0,
    );
    assert!(transferable == 200, 2); // 600 - 400 = 200

    clock::destroy_for_testing(clock);
    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = lock_manager::EIndexOutOfRange)]
fun test_remove_lock_index_greater_than_count() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let clock = clock::create_for_testing(ts.ctx());

    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    // Add one lock
    lock_manager::add_lock<TEST_VOLORO>(
        &mut registry,
        b"INV001".to_string(),
        100,
        1,
        b"Lock".to_string(),
        0,
        &auth,
        &version,
        &clock,
        ts.ctx(),
    );

    assert!(lock_manager::lock_count(&registry, b"INV001".to_string()) == 1, 0);

    // Try to remove at index 2 when only 1 lock exists
    lock_manager::remove_lock<TEST_VOLORO>(
        &mut registry,
        b"INV001".to_string(),
        2, // Invalid index
        &auth,
        &version,
        ts.ctx(),
    );

    clock::destroy_for_testing(clock);
    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

// ==================== Liquidate Only Mode Tests ====================

#[test]
fun test_liquidate_only_toggle() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    // Initially not in liquidate-only mode
    assert!(!lock_manager::is_liquidate_only(&registry, b"INV001".to_string()), 0);

    // Enable liquidate-only
    lock_manager::set_liquidate_only<TEST_VOLORO>(
        &mut registry,
        b"INV001".to_string(),
        true,
        &auth,
        &version,
        ts.ctx(),
    );
    assert!(lock_manager::is_liquidate_only(&registry, b"INV001".to_string()), 1);

    // Disable liquidate-only
    lock_manager::set_liquidate_only<TEST_VOLORO>(
        &mut registry,
        b"INV001".to_string(),
        false,
        &auth,
        &version,
        ts.ctx(),
    );
    assert!(!lock_manager::is_liquidate_only(&registry, b"INV001".to_string()), 2);

    // Enable again
    lock_manager::set_liquidate_only<TEST_VOLORO>(
        &mut registry,
        b"INV001".to_string(),
        true,
        &auth,
        &version,
        ts.ctx(),
    );
    assert!(lock_manager::is_liquidate_only(&registry, b"INV001".to_string()), 3);

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

// ==================== Full Lock vs Partial Lock Interaction Tests ====================

#[test]
fun test_full_lock_overrides_partial_locks() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let clock = clock::create_for_testing(ts.ctx());

    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    // Add partial lock for 100 tokens
    lock_manager::add_lock<TEST_VOLORO>(
        &mut registry,
        b"INV001".to_string(),
        100,
        1,
        b"Partial".to_string(),
        0,
        &auth,
        &version,
        &clock,
        ts.ctx(),
    );

    // With 500 balance and 100 locked, 400 should be transferable
    let transferable_before = lock_manager::compute_transferable(
        &registry,
        b"INV001".to_string(),
        500,
        0,
    );
    assert!(transferable_before == 400, 0);

    // Now fully lock the investor
    lock_manager::lock_investor<TEST_VOLORO>(
        &mut registry,
        b"INV001".to_string(),
        &auth,
        &version,
        ts.ctx(),
    );

    // Full lock should make transferable = 0 regardless of partial locks
    let transferable_after = lock_manager::compute_transferable(
        &registry,
        b"INV001".to_string(),
        500,
        0,
    );
    assert!(transferable_after == 0, 1);

    // Unlock the full lock
    lock_manager::unlock_investor<TEST_VOLORO>(
        &mut registry,
        b"INV001".to_string(),
        &auth,
        &version,
        ts.ctx(),
    );

    // Partial locks should still apply
    let transferable_restored = lock_manager::compute_transferable(
        &registry,
        b"INV001".to_string(),
        500,
        0,
    );
    assert!(transferable_restored == 400, 2);

    clock::destroy_for_testing(clock);
    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

// ==================== Multiple Investors Tests ====================

#[test]
fun test_lock_operations_different_investors() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let clock = clock::create_for_testing(ts.ctx());

    // Register two investors
    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV002".to_string(),
        &version,
        ts.ctx(),
    );

    // Lock investor 1 fully
    lock_manager::lock_investor<TEST_VOLORO>(
        &mut registry,
        b"INV001".to_string(),
        &auth,
        &version,
        ts.ctx(),
    );

    // Add partial lock to investor 2
    lock_manager::add_lock<TEST_VOLORO>(
        &mut registry,
        b"INV002".to_string(),
        100,
        1,
        b"Partial".to_string(),
        0,
        &auth,
        &version,
        &clock,
        ts.ctx(),
    );

    // Verify investor 1 is fully locked
    assert!(lock_manager::is_investor_locked(&registry, b"INV001".to_string()), 0);
    assert!(!lock_manager::is_investor_locked(&registry, b"INV002".to_string()), 1);

    // Verify transferable amounts
    let transferable_inv1 = lock_manager::compute_transferable(
        &registry,
        b"INV001".to_string(),
        500,
        0,
    );
    assert!(transferable_inv1 == 0, 2); // Fully locked

    let transferable_inv2 = lock_manager::compute_transferable(
        &registry,
        b"INV002".to_string(),
        500,
        0,
    );
    assert!(transferable_inv2 == 400, 3); // 500 - 100 partial lock

    clock::destroy_for_testing(clock);
    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

// ==================== Edge Cases Tests ====================

#[test]
fun test_lock_count_returns_zero_initially() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    assert!(lock_manager::lock_count(&registry, b"INV001".to_string()) == 0, 0);

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_compute_transferable_zero_balance() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    // With zero balance, transferable should be 0
    let transferable = lock_manager::compute_transferable(
        &registry,
        b"INV001".to_string(),
        0, // zero balance
        0,
    );
    assert!(transferable == 0, 0);

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_permanent_lock_never_releases() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let clock = clock::create_for_testing(ts.ctx());

    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    // Add permanent lock (release_time_ms = 0)
    lock_manager::add_lock<TEST_VOLORO>(
        &mut registry,
        b"INV001".to_string(),
        100,
        1,
        b"Permanent".to_string(),
        0, // permanent - never releases
        &auth,
        &version,
        &clock,
        ts.ctx(),
    );

    // Even far in the future, lock should still apply
    let transferable = lock_manager::compute_transferable(
        &registry,
        b"INV001".to_string(),
        500,
        999999999999, // Very far in the future
    );
    assert!(transferable == 400, 0); // Still 100 locked

    clock::destroy_for_testing(clock);
    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}
