module securitize::lock_manager;

use securitize::{
    registry_service::{InvestorInfo},
    trust_service::{Auth, Master, TransferAgent},
    version::Version
};
use std::string::String;
use sui::event;

const MAX_LOCKS: u64 = 30;

const EAlreadyLocked: u64 = 1;
const ENotLocked: u64 = 2;
const ETooManyLocks: u64 = 3;
const EIndexOutOfRange: u64 = 4;
const EInvalidValue: u64 = 5;
const EInvalidTime: u64 = 6;

// ==== Events ====

public struct DSLockManagerInvestorFullyLocked<phantom T> has copy, drop {
    investor: String,
}

public struct DSLockManagerInvestorFullyUnlocked<phantom T> has copy, drop {
    investor: String,
}

public struct DSLockManagerLiquidateOnlySet<phantom T> has copy, drop {
    investor: String,
    enabled: bool,
}

public struct DSLockManagerLockAdded<phantom T> has copy, drop {
    investor: String,
    index: u64,
    value: u64,
    reason_code: u64,
    reason_string: String,
    release_time_ms: u64,
}

public struct DSLockManagerLockRemoved<phantom T> has copy, drop {
    investor: String,
    index: u64,
}

// ==== Lock Manager Abilities ====

public struct LockInvestor has drop {}

public struct UnlockInvestor has drop {}

public struct SetLiquidateOnly has drop {}

public struct AddLockRecord has drop {}

public struct RemoveLockRecord has drop {}

/// Called by the setup module during token deployment.
public(package) fun new<T>(
    auth: &mut Auth<T>,
    version: &Version,
    ctx: &TxContext,
) {
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

public fun lock_investor<T>(
    registry: &mut InvestorInfo<T>,
    investor: String,
    auth: &Auth<T>,
    version: &Version,
    ctx: &TxContext,
) {
    version.check_is_valid();
    auth.owner_has_ability<T, LockInvestor>(ctx.sender());
    let lock_state = registry.get_investor_locks_mut(investor);
    assert!(!lock_state.is_fully_locked(), EAlreadyLocked);
    lock_state.set_fully_locked(true);
    event::emit(DSLockManagerInvestorFullyLocked<T> { investor });
}

public fun unlock_investor<T>(
    registry: &mut InvestorInfo<T>,
    investor: String,
    auth: &Auth<T>,
    version: &Version,
    ctx: &TxContext,
) {
    version.check_is_valid();
    auth.owner_has_ability<T, UnlockInvestor>(ctx.sender());
    let lock_state = registry.get_investor_locks_mut(investor);
    assert!(lock_state.is_fully_locked(), ENotLocked);
    lock_state.set_fully_locked(false);
    event::emit(DSLockManagerInvestorFullyUnlocked<T> { investor });
}

public fun set_liquidate_only<T>(
    registry: &mut InvestorInfo<T>,
    investor: String,
    enabled: bool,
    auth: &Auth<T>,
    version: &Version,
    ctx: &TxContext,
) {
    version.check_is_valid();
    auth.owner_has_ability<T, SetLiquidateOnly>(ctx.sender());
    let lock_state = registry.get_investor_locks_mut(investor);
    lock_state.set_liquidate_only(enabled);
    event::emit(DSLockManagerLiquidateOnlySet<T> { investor, enabled });
}

public fun add_lock<T>(
    registry: &mut InvestorInfo<T>,
    investor: String,
    value: u64,
    reason_code: u64,
    reason_string: String,
    release_time_ms: u64,
    auth: &Auth<T>,
    version: &Version,
    ctx: &TxContext,
) {
    version.check_is_valid();
    auth.owner_has_ability<T, AddLockRecord>(ctx.sender());
    assert!(value > 0, EInvalidValue);
    assert!(release_time_ms > 0, EInvalidTime);

    let lock_state = registry.get_investor_locks_mut(investor);
    let idx = lock_state.locks_length();
    assert!(idx < MAX_LOCKS, ETooManyLocks);

    lock_state.add_lock(value, reason_code, reason_string, release_time_ms);

    event::emit(DSLockManagerLockAdded<T> {
        investor,
        index: idx,
        value,
        reason_code,
        reason_string,
        release_time_ms,
    });
}

public fun remove_lock<T>(
    registry: &mut InvestorInfo<T>,
    investor: String,
    index: u64,
    auth: &Auth<T>,
    version: &Version,
    ctx: &TxContext,
) {
    version.check_is_valid();
    auth.owner_has_ability<T, RemoveLockRecord>(ctx.sender());
    let lock_state = registry.get_investor_locks_mut(investor);
    let len = lock_state.locks_length();
    assert!(index < len, EIndexOutOfRange);

    lock_state.remove_lock(index);

    event::emit(DSLockManagerLockRemoved<T> { investor, index });
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
