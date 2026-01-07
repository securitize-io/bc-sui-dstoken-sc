/// Module: lockup_restriction
///
/// Rule that enforces lock-up periods on token issuances.
/// Tokens are locked for a configurable period after issuance, with separate
/// lock periods for US and non-US investors.
///
/// This module validates that transfers do not exceed the amount of unlocked
/// (transferable) tokens based on issuance timestamps tracked in InvestorInfo.
module securitize::lockup_restriction;

use securitize::{
    abilities::ManageRules,
    registry_service::Issuance,
    trust_service::Auth,
    version::Version
};
use std::string::String;
use sui::event;

// ==== Constants ====

const US: u64 = 1;

/// Maximum lock period: 200 years in milliseconds
/// This prevents the edge case of overflow when adding lock_period to issuance timestamps
const MAX_LOCK_PERIOD_MS: u64 = 6_307_200_000_000; // 200 years

// ==== Error Codes ====

const EUnderLockup: u64 = 0;
const ELockPeriodTooLong: u64 = 1;

// ==== Events ====

public struct DSComplianceLockupRestrictionRuleCreated<phantom T> has copy, drop {
    us_lock_period_ms: u64,
    non_us_lock_period_ms: u64,
}

public struct DSComplianceLockupRestrictionRuleSet<phantom T, V: copy + drop> has copy, drop {
    field: String,
    old_value: V,
    new_value: V,
}

// ==== Structs ====

/// Lockup restriction configuration - lock periods
public struct LockupRestriction has drop, store {
    /// Lock period for US investors (in milliseconds)
    us_lock_period_ms: u64,
    /// Lock period for non-US investors (in milliseconds)
    non_us_lock_period_ms: u64,
}

// ==================== Initialization ====================

/// Create a new LockupRestriction rule with configurable lock periods
public fun new<T>(
    auth: &Auth<T>,
    us_lock_period_ms: u64,
    non_us_lock_period_ms: u64,
    version: &Version,
    ctx: &TxContext,
): LockupRestriction {
    version.check_is_valid();
    auth.owner_has_ability<T, ManageRules>(ctx.sender());
    assert!(us_lock_period_ms <= MAX_LOCK_PERIOD_MS, ELockPeriodTooLong);
    assert!(non_us_lock_period_ms <= MAX_LOCK_PERIOD_MS, ELockPeriodTooLong);
    event::emit(DSComplianceLockupRestrictionRuleCreated<T> {
        us_lock_period_ms,
        non_us_lock_period_ms,
    });
    LockupRestriction {
        us_lock_period_ms,
        non_us_lock_period_ms,
    }
}

// ==================== Rule Management ====================

/// Set US lock period (in milliseconds)
public fun set_us_lock_period<T>(
    auth: &Auth<T>,
    rule: &mut LockupRestriction,
    period_ms: u64,
    version: &Version,
    ctx: &TxContext,
) {
    version.check_is_valid();
    auth.owner_has_ability<T, ManageRules>(ctx.sender());
    assert!(period_ms <= MAX_LOCK_PERIOD_MS, ELockPeriodTooLong);
    event::emit(DSComplianceLockupRestrictionRuleSet<T, u64> {
        field: b"us_lock_period_ms".to_string(),
        old_value: rule.us_lock_period_ms,
        new_value: period_ms,
    });
    rule.us_lock_period_ms = period_ms;
}

/// Set non-US lock period (in milliseconds)
public fun set_non_us_lock_period<T>(
    auth: &Auth<T>,
    rule: &mut LockupRestriction,
    period_ms: u64,
    version: &Version,
    ctx: &TxContext,
) {
    version.check_is_valid();
    auth.owner_has_ability<T, ManageRules>(ctx.sender());
    assert!(period_ms <= MAX_LOCK_PERIOD_MS, ELockPeriodTooLong);
    event::emit(DSComplianceLockupRestrictionRuleSet<T, u64> {
        field: b"non_us_lock_period_ms".to_string(),
        old_value: rule.non_us_lock_period_ms,
        new_value: period_ms,
    });
    rule.non_us_lock_period_ms = period_ms;
}

// ==================== Validation ====================

/// Validate that a transfer does not exceed the transferable (issuances unlocked) token amount.
public fun validate_rule(
    rule: &LockupRestriction,
    investor_issuances: &vector<Issuance>,
    amount: u64,
    from_region: u64,
    from_is_special_wallet: bool,
    current_transferable_balance: u64,
    timestamp_ms: u64,
) {
    // Special wallets as senders are exempt from lockup restrictions
    if (from_is_special_wallet) return;

    let transferable = compute_transferable_tokens(
        rule,
        investor_issuances,
        from_region,
        current_transferable_balance,
        timestamp_ms,
    );

    assert!(transferable >= amount, EUnderLockup);
}

/// Compute the number of transferable (unlocked) tokens for an investor.
///
/// This calculates the balance minus any tokens still under lockup from issuances.
public fun compute_transferable_tokens(
    rule: &LockupRestriction,
    investor_issuances: &vector<Issuance>,
    region: u64,
    balance: u64,
    timestamp_ms: u64,
): u64 {
    // No issuances = all tokens transferable
    if (investor_issuances.is_empty()) {
        return balance
    };

    let lock_period = get_lock_period(rule, region);

    // Lock period of 0 means no lockup restriction
    if (lock_period == 0) {
        return balance
    };

    let mut total_locked = 0u64;

    investor_issuances.do_ref!(|issuance| {
        // Check if issuance is still under lockup
        let locked // Global initial lock window
         =
            timestamp_ms < lock_period
            // Issuance-relative lock window
            || issuance.issuance_time_ms() + lock_period > timestamp_ms;

        if (locked) {
            total_locked = total_locked + issuance.issuance_amount();
        };
    });

    // There may be more locked tokens than actual balance, so take minimum
    let locked = if (total_locked > balance) balance else total_locked;
    balance - locked
}

/// Check if a specific issuance is still under lockup
public fun is_issuance_locked(
    rule: &LockupRestriction,
    issuance: &Issuance,
    region: u64,
    timestamp_ms: u64,
): bool {
    let lock_period = get_lock_period(rule, region);

    // Lock period of 0 means no lockup
    if (lock_period == 0) {
        return false
    };

    timestamp_ms < lock_period || issuance.issuance_time_ms() + lock_period > timestamp_ms
}

// ==================== View Functions ====================

public fun get_lock_period(rule: &LockupRestriction, region: u64): u64 {
    if (region == US) {
        rule.us_lock_period_ms
    } else {
        rule.non_us_lock_period_ms
    }
}

/// Get US lock period
public fun us_lock_period(rule: &LockupRestriction): u64 {
    rule.us_lock_period_ms
}

/// Get non-US lock period
public fun non_us_lock_period(rule: &LockupRestriction): u64 {
    rule.non_us_lock_period_ms
}

/// Get the lock period for a specific region
public fun lock_period_for_region(rule: &LockupRestriction, region: u64): u64 {
    get_lock_period(rule, region)
}
