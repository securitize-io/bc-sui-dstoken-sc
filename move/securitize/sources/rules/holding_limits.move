/// Rule that enforces minimum and maximum holding amounts per investor.
/// Supports region-specific minimum holdings (US, EU) as per Aptos implementation.
module securitize::holding_limits;

use securitize::version::Version;
use sui::vec_map::{Self, VecMap};

// ==== Error Codes ====

const EBelowMinHolding: u64 = 0;
const EAboveMaxHolding: u64 = 1;
const ERegionNotFound: u64 = 2;
const EInvalidMinimum: u64 = 3;
const EInvalidMaximum: u64 = 4;

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
// ==================== Initialization ====================

/// Create with region-specific minimums
public fun new(
    min_holdings_per_investor: u64,
    max_holdings_per_investor: u64,
    regions: vector<u64>,
    region_mins: vector<u64>,
    version: &Version,
): HoldingLimits {
    version.check_is_valid();
    let mut region_min_tokens = vec_map::empty();

    regions.zip_do!(region_mins, |region, min| {
        assert!(min > 0, EInvalidMinimum);
        region_min_tokens.insert(region, min);
    });

    HoldingLimits {
        min_holdings_per_investor,
        max_holdings_per_investor,
        region_min_tokens,
    }
}

// ==================== Rule Management ====================

/// Set minimum holdings
public fun set_min_holdings(rule: &mut HoldingLimits, min: u64, version: &Version) {
    version.check_is_valid();
    assert!(min >= 0, EInvalidMinimum);
    rule.min_holdings_per_investor = min;
}

/// Set maximum holdings
public fun set_max_holdings(rule: &mut HoldingLimits, max: u64, version: &Version) {
    version.check_is_valid();
    assert!(max >= 0, EInvalidMaximum);
    rule.max_holdings_per_investor = max;
}

/// Set region-specific minimum holdings
public fun set_region_min_holdings(
    rule: &mut HoldingLimits,
    region: u64,
    min: u64,
    version: &Version,
) {
    version.check_is_valid();
    assert!(min >= 0, EInvalidMinimum);

    // Remove existing entry if present, then insert new value
    if (rule.region_min_tokens.contains(&region)) {
        rule.region_min_tokens.remove(&region);
    };
    rule.region_min_tokens.insert(region, min);
}

/// Remove region-specific minimum
public fun remove_region_min_holdings(rule: &mut HoldingLimits, region: u64, version: &Version) {
    version.check_is_valid();
    // Remove if exists
    if (rule.region_min_tokens.contains(&region)) {
        rule.region_min_tokens.remove(&region);
    };
}

// ==================== Validation ====================

public fun validate_holding_limits_for_transfer(
    rule: &HoldingLimits,
    amount: u64,
    from_is_platform_wallet: bool,
    from_balance: u64,
    from_region: u64,
    to_balance: u64,
    to_region: u64,
) {
    // ---- SENDER ----
    if (!from_is_platform_wallet) {
        let from_balance_after = from_balance - amount;
        if (from_balance_after > 0){
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

/// Validate only MINIMUM holdings (global + region)
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

/// Validate only MAXIMUM holdings (global)
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

/// Get region-specific minimum holdings
public fun region_min_holdings(rule: &HoldingLimits, region: u64): u64 {
    assert!(rule.region_min_tokens.contains(&region), ERegionNotFound);
    *rule.region_min_tokens.get(&region)
}
