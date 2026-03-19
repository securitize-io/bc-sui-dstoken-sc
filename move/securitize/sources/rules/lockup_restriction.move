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
    abilities::{ManageRules, RegisterRule},
    events::emit_uint_rule_set_event,
    registry_service::Issuance,
    rule_wrapper::{RuleInitWrapper, RuleUpdateWrapper, new_init},
    trust_service::Auth,
    version::Version
};

// ==== Error Codes ====

#[error(code = 0)]
const EUnderLockup: vector<u8> =
    b"Transfer amount exceeds unlocked tokens - issuance still under lockup";
#[error(code = 1)]
const ELockPeriodTooLong: vector<u8> = b"Lock period exceeds maximum allowed (200 years)";
#[error(code = 2)]
const ENotAuthorized: vector<u8> = b"Caller is not authorized to perform this action";
#[error(code = 3)]
const EArithmeticOverflow: vector<u8> = b"Arithmetic overflow occurred";

// ==== Constants ====

const US: u64 = 1;

/// Maximum lock period: 200 years in milliseconds
/// This prevents the edge case of overflow when adding lock_period to issuance timestamps
const MAX_LOCK_PERIOD_MS: u64 = 6_307_200_000_000; // 200 years

// ==== Structs ====

/// Lockup restriction configuration - lock periods
public struct LockupRestriction has drop, store {
    /// Lock period for US investors (in milliseconds)
    us_lock_period_ms: u64,
    /// Lock period for non-US investors (in milliseconds)
    non_us_lock_period_ms: u64,
}

// ==================== Initialization ====================

/// Create a new LockupRestriction rule with configurable lock periods.
///
/// # Aborts
/// * `ENotAuthorized` - If caller lacks RegisterRule ability
/// * `ELockPeriodTooLong` - If either lock period exceeds maximum (200 years)
public fun new<T>(
    auth: &Auth<T>,
    us_lock_period_ms: u64,
    non_us_lock_period_ms: u64,
    version: &Version,
    ctx: &TxContext,
): RuleInitWrapper<T, LockupRestriction> {
    version.check_is_valid();
    assert!(auth.owner_has_ability<T, RegisterRule>(ctx.sender()), ENotAuthorized);
    assert!(us_lock_period_ms <= MAX_LOCK_PERIOD_MS, ELockPeriodTooLong);
    assert!(non_us_lock_period_ms <= MAX_LOCK_PERIOD_MS, ELockPeriodTooLong);
    emit_uint_rule_set_event<T>(b"usLockPeriod".to_string(), 0, us_lock_period_ms);
    emit_uint_rule_set_event<T>(b"nonUSLockPeriod".to_string(), 0, non_us_lock_period_ms);
    new_init(LockupRestriction {
        us_lock_period_ms,
        non_us_lock_period_ms,
    })
}

// ==================== Rule Management ====================

/// Set US lock period (in milliseconds).
///
/// # Aborts
/// * `ENotAuthorized` - If caller lacks ManageRules ability
/// * `ELockPeriodTooLong` - If period exceeds maximum (200 years)
public fun set_us_lock_period<T>(
    auth: &Auth<T>,
    wrapper: &mut RuleUpdateWrapper<T, LockupRestriction>,
    period_ms: u64,
    version: &Version,
    ctx: &TxContext,
) {
    version.check_is_valid();
    assert!(auth.owner_has_ability<T, ManageRules>(ctx.sender()), ENotAuthorized);
    assert!(period_ms <= MAX_LOCK_PERIOD_MS, ELockPeriodTooLong);
    let rule = wrapper.borrow_update_mut();
    emit_uint_rule_set_event<T>(
        b"usLockPeriod".to_string(),
        rule.us_lock_period_ms,
        period_ms,
    );
    rule.us_lock_period_ms = period_ms;
}

/// Set non-US lock period (in milliseconds).
///
/// # Aborts
/// * `ENotAuthorized` - If caller lacks ManageRules ability
/// * `ELockPeriodTooLong` - If period exceeds maximum (200 years)
public fun set_non_us_lock_period<T>(
    auth: &Auth<T>,
    wrapper: &mut RuleUpdateWrapper<T, LockupRestriction>,
    period_ms: u64,
    version: &Version,
    ctx: &TxContext,
) {
    version.check_is_valid();
    assert!(auth.owner_has_ability<T, ManageRules>(ctx.sender()), ENotAuthorized);
    assert!(period_ms <= MAX_LOCK_PERIOD_MS, ELockPeriodTooLong);
    let rule = wrapper.borrow_update_mut();
    emit_uint_rule_set_event<T>(
        b"nonUSLockPeriod".to_string(),
        rule.non_us_lock_period_ms,
        period_ms,
    );
    rule.non_us_lock_period_ms = period_ms;
}

// ==================== Validation ====================

/// Validate that a transfer does not exceed the transferable (issuances unlocked) token amount.
///
/// # Aborts
/// * `EUnderLockup` - If transfer amount exceeds transferable balance
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
        // Check if issuance is still under lockup (u256 to prevent overflow)
        let lock_end_ms = try_from_u256_to_u64!(
            (issuance.issuance_time_ms() as u256) + (lock_period as u256),
        );
        let locked // Global initial lock window
         =
            timestamp_ms < lock_period
            // Issuance-relative lock window
            || lock_end_ms > timestamp_ms;

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

    let lock_end_ms = try_from_u256_to_u64!(
        (issuance.issuance_time_ms() as u256) + (lock_period as u256),
    );
    timestamp_ms < lock_period || lock_end_ms > timestamp_ms
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

// ==== Macros ====

macro fun try_from_u256_to_u64($number: u256): u64 {
    let mut number_option = std::u256::try_as_u64($number);
    assert!(number_option.is_some(), EArithmeticOverflow);
    number_option.extract()
}
