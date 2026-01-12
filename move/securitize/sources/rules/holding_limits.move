/// Module: holding_limits
///
/// Rule that enforces minimum and maximum holding amounts per investor.
/// Supports region-specific minimum holdings.
module securitize::holding_limits;

use securitize::{abilities::ManageRules, trust_service::Auth, version::Version};
use std::string::String;
use sui::{event, vec_map::{Self, VecMap}};

// ==== Error Codes ====

const EBelowMinHolding: u64 = 0;
const EAboveMaxHolding: u64 = 1;
const ERegionNotFound: u64 = 2;
const ENotAuthorized: u64 = 3;

// ==== Structs ====

/// Holding limits configuration
public struct HoldingLimits has drop, store {
    /// Minimum holdings per investor (0 = no minimum)
    min_holdings_per_investor: u64,
    /// Maximum holdings per investor (0 = no maximum)
    max_holdings_per_investor: u64,
    /// Region-specific minimum holdings (e.g., US, EU)
    region_min_tokens: VecMap<u64, u64>,
}

// ==== Events ====

public struct DSComplianceHoldingLimitsRuleCreated<phantom T> has copy, drop {
    min_holdings_per_investor: u64,
    max_holdings_per_investor: u64,
    regions: vector<u64>,
    region_mins: vector<u64>,
}

public struct DSComplianceHoldingLimitsRuleSet<phantom T, V: copy + drop> has copy, drop {
    field: String,
    region: Option<u64>,
    old_value: V,
    new_value: V,
}

// ==================== Initialization ====================

/// Create with region-specific minimums.
///
/// # Aborts
/// * `ENotAuthorized` - If caller lacks ManageRules ability
public fun new<T>(
    auth: &Auth<T>,
    min_holdings_per_investor: u64,
    max_holdings_per_investor: u64,
    regions: vector<u64>,
    region_mins: vector<u64>,
    version: &Version,
    ctx: &TxContext,
): HoldingLimits {
    version.check_is_valid();
    assert!(auth.owner_has_ability<T, ManageRules>(ctx.sender()), ENotAuthorized);
    let mut region_min_tokens = vec_map::empty();

    regions.zip_do!(region_mins, |region, min| {
        region_min_tokens.insert(region, min);
    });

    event::emit(DSComplianceHoldingLimitsRuleCreated<T> {
        min_holdings_per_investor,
        max_holdings_per_investor,
        regions,
        region_mins,
    });

    HoldingLimits {
        min_holdings_per_investor,
        max_holdings_per_investor,
        region_min_tokens,
    }
}

// ==================== Rule Management ====================

/// Set minimum holdings
///
/// # Aborts
/// * `ENotAuthorized` - If caller lacks ManageRules ability
public fun set_min_holdings<T>(
    auth: &Auth<T>,
    rule: &mut HoldingLimits,
    min: u64,
    version: &Version,
    ctx: &TxContext,
) {
    version.check_is_valid();
    assert!(auth.owner_has_ability<T, ManageRules>(ctx.sender()), ENotAuthorized);
    event::emit(DSComplianceHoldingLimitsRuleSet<T, u64> {
        field: b"min_holdings_per_investor".to_string(),
        region: option::none(),
        old_value: rule.min_holdings_per_investor,
        new_value: min,
    });
    rule.min_holdings_per_investor = min;
}

/// Set maximum holdings
///
/// # Aborts
/// * `ENotAuthorized` - If caller lacks ManageRules ability
public fun set_max_holdings<T>(
    auth: &Auth<T>,
    rule: &mut HoldingLimits,
    max: u64,
    version: &Version,
    ctx: &TxContext,
) {
    version.check_is_valid();
    assert!(auth.owner_has_ability<T, ManageRules>(ctx.sender()), ENotAuthorized);
    event::emit(DSComplianceHoldingLimitsRuleSet<T, u64> {
        field: b"max_holdings_per_investor".to_string(),
        region: option::none(),
        old_value: rule.max_holdings_per_investor,
        new_value: max,
    });
    rule.max_holdings_per_investor = max;
}

/// Set region-specific minimum holdings.
///
/// # Aborts
/// * `ENotAuthorized` - If caller lacks ManageRules ability
public fun set_region_min_holdings<T>(
    auth: &Auth<T>,
    rule: &mut HoldingLimits,
    region: u64,
    min: u64,
    version: &Version,
    ctx: &TxContext,
) {
    version.check_is_valid();
    assert!(auth.owner_has_ability<T, ManageRules>(ctx.sender()), ENotAuthorized);

    let old_value = if (rule.region_min_tokens.contains(&region)) {
        let (_, old) = rule.region_min_tokens.remove(&region);
        old
    } else {
        0
    };
    rule.region_min_tokens.insert(region, min);
    event::emit(DSComplianceHoldingLimitsRuleSet<T, u64> {
        field: b"region_min_tokens".to_string(),
        region: option::some(region),
        old_value,
        new_value: min,
    });
}

/// Remove region-specific minimum
///
/// # Aborts
/// * `ENotAuthorized` - If caller lacks ManageRules ability
public fun remove_region_min_holdings<T>(
    auth: &Auth<T>,
    rule: &mut HoldingLimits,
    region: u64,
    version: &Version,
    ctx: &TxContext,
) {
    version.check_is_valid();
    assert!(auth.owner_has_ability<T, ManageRules>(ctx.sender()), ENotAuthorized);
    // Remove if exists
    if (rule.region_min_tokens.contains(&region)) {
        let (_, old_value) = rule.region_min_tokens.remove(&region);
        event::emit(DSComplianceHoldingLimitsRuleSet<T, u64> {
            field: b"region_min_tokens".to_string(),
            region: option::some(region),
            old_value,
            new_value: 0,
        });
    };
}

// ==================== Validation ====================

public fun validate_holding_limits_for_transfer(
    rule: &HoldingLimits,
    amount: u64,
    from_is_special_wallet: bool,
    from_balance: u64,
    from_region: u64,
    to_balance: u64,
    to_region: u64,
) {
    // ---- SENDER ----
    if (!from_is_special_wallet) {
        let from_balance_after = from_balance - amount;
        if (from_balance_after > 0) {
            rule.validate_min_holdings(from_balance_after, from_region);
        }
    };
    // ---- RECEIVER ----
    let to_balance_after = to_balance + amount;
    // Min holdings check (region-aware)
    rule.validate_min_holdings(to_balance_after, to_region);
    // Max holdings check (receiver only)
    rule.validate_max_holdings(to_balance_after);
}

/// Validate holding limits for issuance (receiver only)
public fun validate_holding_limits_for_issuance(
    rule: &HoldingLimits,
    amount: u64,
    to_balance: u64,
    to_region: u64,
) {
    let to_balance_after = to_balance + amount;
    // Min holdings check (region-aware)
    rule.validate_min_holdings(to_balance_after, to_region);
    // Max holdings check
    rule.validate_max_holdings(to_balance_after);
}

/// Validate only MINIMUM holdings (global + region).
///
/// # Aborts
/// * `EBelowMinHolding` - If balance is below global or region minimum
public fun validate_min_holdings(rule: &HoldingLimits, balance_after: u64, region: u64) {
    // Global minimum
    if (rule.min_holdings_per_investor > 0) {
        assert!(balance_after >= rule.min_holdings_per_investor, EBelowMinHolding);
    };

    // Region-specific minimum
    if (rule.region_min_tokens.contains(&region)) {
        let region_min = *rule.region_min_tokens.get(&region);
        assert!(balance_after >= region_min, EBelowMinHolding);
    };
}

/// Validate only MAXIMUM holdings (global).
///
/// # Aborts
/// * `EAboveMaxHolding` - If balance exceeds maximum
public fun validate_max_holdings(rule: &HoldingLimits, balance_after: u64) {
    if (rule.max_holdings_per_investor > 0) {
        assert!(balance_after <= rule.max_holdings_per_investor, EAboveMaxHolding);
    };
}

// ==================== View Functions ====================

/// Get minimum holdings
public fun min_holdings(rule: &HoldingLimits): u64 {
    rule.min_holdings_per_investor
}

/// Get maximum holdings
public fun max_holdings(rule: &HoldingLimits): u64 {
    rule.max_holdings_per_investor
}

/// Get region-specific minimum holdings.
///
/// # Aborts
/// * `ERegionNotFound` - If the region does not have a minimum configured
public fun region_min_holdings(rule: &HoldingLimits, region: u64): u64 {
    assert!(rule.region_min_tokens.contains(&region), ERegionNotFound);
    *rule.region_min_tokens.get(&region)
}
