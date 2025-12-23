/// Module: lockup_restriction
///
/// Rule that enforces lock-up periods on token issuances.
/// Tokens are locked for a configurable period after issuance, with separate
/// lock periods for US and non-US investors (Regulation D/S compliance).
///
/// This module validates that transfers do not exceed the amount of unlocked
/// (transferable) tokens based on issuance timestamps tracked in InvestorInfo.
module securitize::lockup_restriction;

use securitize::version::Version;
use securitize::registry_service::Issuance;

// ==== Constants ====

const US: u64 = 1;

// ==== Error Codes ====

const EUnderLockup: u64 = 0;

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
public fun new(
    us_lock_period_ms: u64,
    non_us_lock_period_ms: u64,
    version: &Version,
): LockupRestriction {
    version.check_is_valid();
    LockupRestriction {
        us_lock_period_ms,
        non_us_lock_period_ms,
    }
}

// ==================== Rule Management ====================

/// Set US lock period (in milliseconds)
public fun set_us_lock_period(rule: &mut LockupRestriction, period_ms: u64, version: &Version) {
    version.check_is_valid();
    rule.us_lock_period_ms = period_ms;
}

/// Set non-US lock period (in milliseconds)
public fun set_non_us_lock_period(rule: &mut LockupRestriction, period_ms: u64, version: &Version) {
    version.check_is_valid();
    rule.non_us_lock_period_ms = period_ms;
}

// ==================== Validation ====================

/// Validate that a transfer does not exceed the transferable (unlocked) token amount.
///
/// This checks if the sender has enough unlocked tokens to transfer.
/// Tokens are locked based on the lock period for the sender's region.
///
/// # Arguments
/// * `rule` - The lockup restriction configuration
/// * `investor_issuances` - Vector of issuance records for the investor (from ComplianceConfig)
/// * `amount` - Amount being transferred
/// * `from_region` - Compliance region of the sender
/// * `from_is_platform_wallet` - Whether sender is a platform wallet (exempt)
/// * `transferable_balance` - Current Transferable_balance balance of the investor
/// * `clock` - Sui clock for current timestamp
public fun validate_rule(
    rule: &LockupRestriction,
    investor_issuances: &vector<Issuance>,
    amount: u64,
    from_region: u64,
    from_is_platform_wallet: bool,
    current_transferable_balance: u64,
    now_ms: u64,
) {
    // Platform wallets are exempt from lockup restrictions
    if (from_is_platform_wallet) return;

    let transferable = compute_transferable_tokens(
        rule,
        investor_issuances,
        from_region,
        current_transferable_balance,
        now_ms,
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
    now_ms: u64,
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
        // Locked if: now_ms < lock_period OR issuance_time > (now_ms - lock_period)
        let locked =
            // Global initial lock window
            now_ms < lock_period
            // Issuance-relative lock window
            || issuance.issuance_time_ms() + lock_period > now_ms;

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
    now_ms: u64,
): bool {
    let lock_period = get_lock_period(rule, region);

    // Lock period of 0 means no lockup
    if (lock_period == 0) {
        return false
    };

    now_ms < lock_period || issuance.issuance_time_ms() + lock_period > now_ms
}

/// Filter out expired issuances from a vector.
/// Returns a new vector with only the still-locked issuances.
public fun filter_expired_issuances(
    rule: &LockupRestriction,
    issuances: &vector<Issuance>,
    region: u64,
    now_ms: u64
): vector<Issuance> {
    let mut result = vector::empty();
    let lock_period = get_lock_period(rule, region);

    // Lock period of 0 means no lockup - all issuances are "expired"
    if (lock_period == 0) {
        return result
    };

    issuances.do_ref!(|issuance| {
        let locked =
            now_ms < lock_period
            || issuance.issuance_time_ms() + lock_period > now_ms;

        if (locked) {
            result.push_back(*issuance);
        };
    });
    result
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
