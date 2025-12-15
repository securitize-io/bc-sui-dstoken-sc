module securitize::investor_lock_manager;

use securitize::{trust_service::{Auth, Master, TransferAgent}, version::Version};
use std::string::String;
use sui::{clock::Clock, event, table::{Self, Table}};

const MAX_LOCKS: u64 = 30;

const EAlreadyLocked: u64 = 1;
const ENotLocked: u64 = 2;
const ETooManyLocks: u64 = 3;
const EIndexOutOfRange: u64 = 4;
const EInvalidValue: u64 = 5;
const EInvalidTime: u64 = 6;

// ==== Structs ====

public struct Lock has drop, store {
    value: u64,
    reason_code: u64,
    reason_string: String,
    release_time_ms: u64,
}

public struct InvestorLockState has drop, store {
    fully_locked: bool,
    liquidate_only: bool,
    locks: vector<Lock>,
}

public struct LockRegistry<phantom T> has key {
    id: UID,
    investors: Table<String, InvestorLockState>,
}

// ==== Events ====

public struct InvestorFullyLockedEvent has copy, drop {
    investor: String,
}

public struct InvestorFullyUnlockedEvent has copy, drop {
    investor: String,
}

public struct InvestorLiquidateOnlyEvent has copy, drop {
    investor: String,
    enabled: bool,
}

public struct LockAddedEvent has copy, drop {
    investor: String,
    index: u64,
    value: u64,
    reason_code: u64,
    reason_string: String,
    release_time_ms: u64,
}

public struct LockRemovedEvent has copy, drop {
    investor: String,
    index: u64,
}

// ==== Lock Manager Abilities ====

public struct LockInvestor has drop {}

public struct UnlockInvestor has drop {}

public struct SetLiquidateOnly has drop {}

public struct AddLockRecord has drop {}

public struct RemoveLockRecord has drop {}

public(package) fun new<T>(
    auth: &mut Auth<T>,
    version: &Version,
    ctx: &mut TxContext,
): LockRegistry<T> {
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

    LockRegistry {
        id: object::new(ctx),
        investors: table::new(ctx),
    }
}

// ==== Public Functions ====

public fun lock_investor<T>(
    registry: &mut LockRegistry<T>,
    investor: String,
    auth: &Auth<T>,
    version: &Version,
    ctx: &TxContext,
) {
    version.check_is_valid();
    auth.owner_has_ability<T, LockInvestor>(ctx.sender());
    let lock_state = investor_lock_state_mut(registry, &investor);
    assert!(!lock_state.fully_locked, EAlreadyLocked);
    lock_state.fully_locked = true;
    event::emit(InvestorFullyLockedEvent { investor });
}

public fun unlock_investor<T>(
    registry: &mut LockRegistry<T>,
    investor: String,
    auth: &Auth<T>,
    version: &Version,
    ctx: &TxContext,
) {
    version.check_is_valid();
    auth.owner_has_ability<T, UnlockInvestor>(ctx.sender());
    let lock_state = investor_lock_state_mut(registry, &investor);
    assert!(lock_state.fully_locked, ENotLocked);
    lock_state.fully_locked = false;
    event::emit(InvestorFullyUnlockedEvent { investor });
}

public fun set_liquidate_only<T>(
    registry: &mut LockRegistry<T>,
    investor: String,
    enabled: bool,
    auth: &Auth<T>,
    version: &Version,
    ctx: &TxContext,
) {
    version.check_is_valid();
    auth.owner_has_ability<T, SetLiquidateOnly>(ctx.sender());
    let lock_state = investor_lock_state_mut(registry, &investor);
    lock_state.liquidate_only = enabled;
    event::emit(InvestorLiquidateOnlyEvent { investor, enabled });
}

public fun add_lock<T>(
    registry: &mut LockRegistry<T>,
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

    let st = investor_lock_state_mut(registry, &investor);
    let idx = st.locks.length();
    assert!(idx < MAX_LOCKS, ETooManyLocks);

    let lock = Lock {
        value,
        reason_code,
        reason_string,
        release_time_ms,
    };
    st.locks.push_back(lock);

    event::emit(LockAddedEvent {
        investor,
        index: idx,
        value,
        reason_code,
        reason_string,
        release_time_ms,
    });
}

public fun remove_lock<T>(
    registry: &mut LockRegistry<T>,
    investor: String,
    index: u64,
    auth: &Auth<T>,
    version: &Version,
    ctx: &TxContext,
) {
    version.check_is_valid();
    auth.owner_has_ability<T, RemoveLockRecord>(ctx.sender());
    let lock_state = investor_lock_state_mut(registry, &investor);
    let len = lock_state.locks.length();
    assert!(index < len, EIndexOutOfRange);

    // remove i record
    let last = len - 1;
    if (index != last) {
        lock_state.locks.swap(index, last);
    };
    let _ = lock_state.locks.pop_back();

    event::emit(LockRemovedEvent { investor, index });
}

public fun compute_transferable<T>(
    registry: &LockRegistry<T>,
    investor: &String,
    balance: u64,
    clock: &Clock,
): u64 {
    // Fully locked → transferable = 0
    if (is_investor_locked(registry, investor)) return 0;

    if (!table::contains(&registry.investors, *investor)) return balance;
    let st = table::borrow(&registry.investors, *investor);

    let now = clock.timestamp_ms();
    let mut locked_sum = 0;

    st.locks.do_ref!(|l| {
        if (l.release_time_ms == 0 || l.release_time_ms >= now) {
            locked_sum = locked_sum + l.value
        }
    });

    // min(total_locked, balance)
    if (locked_sum >= balance) 0 else balance - locked_sum
}

// ==== Private Functions ====

fun investor_lock_state_mut<T>(
    registry: &mut LockRegistry<T>,
    investor: &String,
): &mut InvestorLockState {
    if (!table::contains(&registry.investors, *investor)) {
        let state = InvestorLockState {
            fully_locked: false,
            liquidate_only: false,
            locks: vector::empty(),
        };
        table::add(&mut registry.investors, *investor, state);
    };
    table::borrow_mut(&mut registry.investors, *investor)
}

// ==== View Functions ====

public fun is_liquidate_only<T>(registry: &LockRegistry<T>, investor: &String): bool {
    if (!table::contains(&registry.investors, *investor)) return false;
    table::borrow(&registry.investors, *investor).liquidate_only
}

public fun is_investor_locked<T>(registry: &LockRegistry<T>, investor: &String): bool {
    if (!table::contains(&registry.investors, *investor)) return false;
    table::borrow(&registry.investors, *investor).fully_locked
}

public fun lock_count<T>(registry: &LockRegistry<T>, investor: &String): u64 {
    if (!table::contains(&registry.investors, *investor)) return 0;
    table::borrow(&registry.investors, *investor).locks.length()
}