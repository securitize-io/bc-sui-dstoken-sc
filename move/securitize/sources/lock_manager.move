/// Module: lock_manager
///
/// Manages token locks for investors, including full account locks, liquidate-only
/// restrictions, and time-based lock records for specific token amounts.
module securitize::lock_manager;

use securitize::{
    abilities::{LockInvestor, UnlockInvestor, SetLiquidateOnly, AddLockRecord, RemoveLockRecord},
    events::{
        emit_investor_fully_locked_event,
        emit_investor_fully_unlocked_event,
        emit_liquidate_only_set_event,
        emit_lock_added_event,
        emit_lock_removed_event
    },
    registry_service::{InvestorInfo, lock_value, lock_reason_code, lock_reason_string, lock_release_time_ms},
    trust_service::{Auth, Master, TransferAgent},
    version::Version
};
use std::string::String;
use sui::clock::Clock;

const MAX_LOCKS: u64 = 30;

#[error(code = 0)]
const ENotAuthorized: vector<u8> = b"Caller is not authorized to perform this action";
#[error(code = 1)]
const EAlreadyLocked: vector<u8> = b"Investor is already fully locked";
#[error(code = 2)]
const ENotLocked: vector<u8> = b"Investor is not fully locked";
#[error(code = 3)]
const ETooManyLocks: vector<u8> = b"Maximum number of lock records exceeded";
#[error(code = 4)]
const EIndexOutOfRange: vector<u8> = b"Lock index is out of range";
#[error(code = 5)]
const EInvalidValue: vector<u8> = b"Lock value must be greater than zero";
#[error(code = 6)]
const EInvalidTime: vector<u8> = b"Release time must be zero or in the future";

/// Called by the setup module during token deployment.
public(package) fun new<T>(auth: &mut Auth<T>, version: &Version, ctx: &TxContext) {
    // Register abilities for Master role
    auth.add_role_ability<T, Master, LockInvestor>(version, ctx);
    auth.add_role_ability<T, Master, UnlockInvestor>(version, ctx);
    auth.add_role_ability<T, Master, SetLiquidateOnly>(version, ctx);
    auth.add_role_ability<T, Master, AddLockRecord>(version, ctx);
    auth.add_role_ability<T, Master, RemoveLockRecord>(version, ctx);

    // Register abilities for TransferAgent role
    auth.add_role_ability<T, TransferAgent, LockInvestor>(version, ctx);
    auth.add_role_ability<T, TransferAgent, UnlockInvestor>(version, ctx);
    auth.add_role_ability<T, TransferAgent, SetLiquidateOnly>(version, ctx);
    auth.add_role_ability<T, TransferAgent, AddLockRecord>(version, ctx);
    auth.add_role_ability<T, TransferAgent, RemoveLockRecord>(version, ctx);
}

// ==== Public Functions ====

/// Fully locks an investor's account, preventing all transfers.
///
/// # Aborts
/// * `ENotAuthorized` - If caller lacks LockInvestor ability
/// * `EAlreadyLocked` - If the investor is already fully locked
public fun lock_investor<T>(
    registry: &mut InvestorInfo<T>,
    investor: String,
    auth: &Auth<T>,
    version: &Version,
    ctx: &TxContext,
) {
    version.check_is_valid();
    assert!(auth.owner_has_ability<T, LockInvestor>(ctx.sender()), ENotAuthorized);
    let lock_state = registry.get_investor_locks_mut(investor);
    assert!(!lock_state.is_fully_locked(), EAlreadyLocked);
    lock_state.set_fully_locked(true);
    emit_investor_fully_locked_event<T>(investor);
}

/// Unlocks a fully locked investor's account, allowing transfers again.
///
/// # Aborts
/// * `ENotAuthorized` - If caller lacks UnlockInvestor ability
/// * `ENotLocked` - If the investor is not fully locked
public fun unlock_investor<T>(
    registry: &mut InvestorInfo<T>,
    investor: String,
    auth: &Auth<T>,
    version: &Version,
    ctx: &TxContext,
) {
    version.check_is_valid();
    assert!(auth.owner_has_ability<T, UnlockInvestor>(ctx.sender()), ENotAuthorized);
    let lock_state = registry.get_investor_locks_mut(investor);
    assert!(lock_state.is_fully_locked(), ENotLocked);
    lock_state.set_fully_locked(false);
    emit_investor_fully_unlocked_event<T>(investor);
}

/// Sets the liquidate-only restriction for an investor.
/// When enabled, the investor can only transfer tokens to the issuer wallet.
///
/// # Aborts
/// * `ENotAuthorized` - If caller lacks SetLiquidateOnly ability
public fun set_liquidate_only<T>(
    registry: &mut InvestorInfo<T>,
    investor: String,
    enabled: bool,
    auth: &Auth<T>,
    version: &Version,
    ctx: &TxContext,
) {
    version.check_is_valid();
    assert!(auth.owner_has_ability<T, SetLiquidateOnly>(ctx.sender()), ENotAuthorized);
    let lock_state = registry.get_investor_locks_mut(investor);
    lock_state.set_liquidate_only(enabled);
    emit_liquidate_only_set_event<T>(investor, enabled);
}

/// Adds a time-based lock record for a specific token amount.
///
/// # Aborts
/// * `ENotAuthorized` - If caller lacks AddLockRecord ability
/// * `EInvalidValue` - If the value is zero
/// * `EInvalidTime` - If the release time is non-zero and in the past
/// * `ETooManyLocks` - If the investor already has the maximum number of locks
public fun add_lock<T>(
    registry: &mut InvestorInfo<T>,
    investor: String,
    value: u64,
    reason_code: u64,
    reason_string: String,
    release_time_ms: u64,
    auth: &Auth<T>,
    version: &Version,
    clock: &Clock,
    ctx: &TxContext,
) {
    version.check_is_valid();
    assert!(auth.owner_has_ability<T, AddLockRecord>(ctx.sender()), ENotAuthorized);
    assert!(value > 0, EInvalidValue);
    assert!(release_time_ms == 0 || release_time_ms > clock.timestamp_ms(), EInvalidTime);

    let lock_state = registry.get_investor_locks_mut(investor);
    let idx = lock_state.locks_length();
    assert!(idx < MAX_LOCKS, ETooManyLocks);

    lock_state.add_lock(value, reason_code, reason_string, release_time_ms);

    emit_lock_added_event<T>(investor, idx, value, reason_code, reason_string, release_time_ms);
}

/// Removes a lock record at the specified index.
///
/// # Aborts
/// * `ENotAuthorized` - If caller lacks RemoveLockRecord ability
/// * `EIndexOutOfRange` - If the index is out of range
public fun remove_lock<T>(
    registry: &mut InvestorInfo<T>,
    investor: String,
    index: u64,
    auth: &Auth<T>,
    version: &Version,
    ctx: &TxContext,
) {
    version.check_is_valid();
    assert!(auth.owner_has_ability<T, RemoveLockRecord>(ctx.sender()), ENotAuthorized);
    let lock_state = registry.get_investor_locks_mut(investor);
    let len = lock_state.locks_length();
    assert!(index < len, EIndexOutOfRange);

    let lock = lock_state.remove_lock(index);

    emit_lock_removed_event<T>(
        investor,
        index,
        lock_value(&lock),
        lock_reason_code(&lock),
        lock_reason_string(&lock),
        lock_release_time_ms(&lock),
    );
}

public fun compute_transferable<T>(
    registry: &InvestorInfo<T>,
    investor: String,
    balance: u64,
    timestamp_ms: u64,
): u64 {
    let lock_state = registry.get_investor_locks(investor);

    // Fully locked → transferable = 0
    if (lock_state.is_fully_locked()) return 0;

    let locked_sum = lock_state.compute_locked_sum(timestamp_ms);

    // min(total_locked, balance)
    if (locked_sum >= balance) 0 else balance - locked_sum
}

// ==== View Functions ====

public fun is_liquidate_only<T>(registry: &InvestorInfo<T>, investor: String): bool {
    let lock_state = registry.get_investor_locks(investor);
    lock_state.is_liquidate_only()
}

public fun is_investor_locked<T>(registry: &InvestorInfo<T>, investor: String): bool {
    let lock_state = registry.get_investor_locks(investor);
    lock_state.is_fully_locked()
}

public fun lock_count<T>(registry: &InvestorInfo<T>, investor: String): u64 {
    let lock_state = registry.get_investor_locks(investor);
    lock_state.locks_length()
}
