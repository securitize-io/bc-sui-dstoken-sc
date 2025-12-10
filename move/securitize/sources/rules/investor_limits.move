/// Module: investor_limits
///
/// Rule that enforces limits on the number of investors by category
/// (total, accredited, non-accredited, by region, etc.)
module securitize::investor_limits;

use securitize::{version::Version};

// ==== TEMP Compliance Region Constants ====

const US: u64 = 1;
const EU: u64 = 2;
const FORBIDDEN: u64 = 4;
const JP: u64 = 8;

// ==== Error Codes ====

const EMaxInvestorsExceeded: u64 = 0;
const EMaxUSInvestorsExceeded: u64 = 1;
const EMaxUSAccreditedExceeded: u64 = 2;
const EMaxNonAccreditedExceeded: u64 = 3;
const EMaxJPInvestorsExceeded: u64 = 4;
const EMaxEURetailExceeded: u64 = 5;
const EBelowMinimumInvestors: u64 = 6;

// ==== Structs ====

/// Investor limits configuration
public struct InvestorLimits has drop, store {
    /// Total investor limit (0 = no limit)
    total_investors_limit: u64,
    /// Minimum total investors required (0 = no minimum)
    minimum_total_investors: u64,
    /// US investor limit (0 = no limit)
    us_investors_limit: u64,
    /// US accredited investor limit (0 = no limit)
    us_accredited_limit: u64,
    /// Non-accredited investor limit (0 = no limit)
    non_accredited_limit: u64,
    /// JP investor limit (0 = no limit)
    jp_investors_limit: u64,
    /// EU retail investor limit (0 = no limit)
    eu_retail_limit: u64,
    /// Maximum US investors as percentage of total (0 = no limit)
    max_us_percentage: u64,
}

// ==================== Initialization ====================

/// Create a new InvestorLimits rule
public fun new(
    total_investors_limit: u64,
    minimum_total_investors: u64,
    us_investors_limit: u64,
    us_accredited_limit: u64,
    non_accredited_limit: u64,
    jp_investors_limit: u64,
    eu_retail_limit: u64,
    max_us_percentage: u64,
    version: &Version,
): InvestorLimits {
    version.check_is_valid();
    InvestorLimits {
        total_investors_limit,
        minimum_total_investors,
        us_investors_limit,
        us_accredited_limit,
        non_accredited_limit,
        jp_investors_limit,
        eu_retail_limit,
        max_us_percentage,
    }
}

// ==================== Rule Management ====================

/// Set total investor limit
public fun set_total_limit(rule: &mut InvestorLimits, limit: u64, version: &Version) {
    version.check_is_valid();
    rule.total_investors_limit = limit;
}

/// Set minimum total investors
public fun set_minimum_total_investors(rule: &mut InvestorLimits, minimum: u64, version: &Version) {
    version.check_is_valid();
    rule.minimum_total_investors = minimum;
}

/// Set US investor limit
public fun set_us_limit(rule: &mut InvestorLimits, limit: u64, version: &Version) {
    version.check_is_valid();
    rule.us_investors_limit = limit;
}

/// Set US accredited limit
public fun set_us_accredited_limit(rule: &mut InvestorLimits, limit: u64, version: &Version) {
    version.check_is_valid();
    rule.us_accredited_limit = limit;
}

/// Set non-accredited limit
public fun set_non_accredited_limit(rule: &mut InvestorLimits, limit: u64, version: &Version) {
    version.check_is_valid();
    rule.non_accredited_limit = limit;
}

/// Set JP investor limit
public fun set_jp_limit(rule: &mut InvestorLimits, limit: u64, version: &Version) {
    version.check_is_valid();
    rule.jp_investors_limit = limit;
}

/// Set EU retail limit
public fun set_eu_retail_limit(rule: &mut InvestorLimits, limit: u64, version: &Version) {
    version.check_is_valid();
    rule.eu_retail_limit = limit;
}

/// Set max US percentage
public fun set_max_us_percentage(rule: &mut InvestorLimits, percentage: u64, version: &Version) {
    version.check_is_valid();
    rule.max_us_percentage = percentage;
}

// ==================== Validation ====================

/// Validate investor limits for transfer
public fun validate_investor_limits_for_transfer<T>(
    limits_rule: &InvestorLimits,
    to_region: u64,
    from_is_accredited: bool,
    from_is_exit_investor: bool,
    to_is_accredited: bool,
    to_is_qualified: bool,
    to_is_new_investor: bool,
    equal_country: bool,
    // registry: &InvestorRegistry<T>,
) {
    // Validate total investor limits (for adding new investors)
    // let total_investors = registry.total_investors();
    let total_investors = 0;
    limits_rule.validate_transfer_total_investors(
        total_investors,
        from_is_exit_investor,
        to_is_new_investor,
    );

    // Validate minimum total investors (prevents reducing below minimum)
    limits_rule.validate_transfer_minimum_total_investors(
        total_investors,
        from_is_exit_investor,
        to_is_new_investor,
    );

    // Validate region-specific limits
    if (to_region == US) {
        validate_us_investor_limits<T>(
            limits_rule,
            // registry,
            from_is_exit_investor,
            from_is_accredited,
            to_is_new_investor,
            to_is_accredited,
            equal_country,
        );
    } else if (to_region == JP) {
        // let jp_count = registry.jp_count();
        let jp_count = 0;
        limits_rule.validate_transfer_jp_investors(
            jp_count,
            from_is_exit_investor,
            to_is_new_investor,
            equal_country,
        );
    } else if (to_region == EU && !to_is_qualified) {
        // EU retail = EU region + not qualified (Retail)
        // let eu_retail_count = registry.eu_retail_count();
        let eu_retail_count = 0;
        limits_rule.validate_transfer_eu_retail(
            eu_retail_count,
            from_is_exit_investor,
            to_is_new_investor,
            equal_country,
        );
    };

    // Validate non-accredited limits
    if (!to_is_accredited) {
        let accredited_count = 0;
        // let accredited_count = registry.accredited_count();
        let non_accredited = total_investors - accredited_count;
        limits_rule.validate_transfer_non_accredited(
            non_accredited,
            to_is_new_investor,
            from_is_exit_investor,
            from_is_accredited,
        );
    };
}

/// Validate investor limits for issuance
public fun validate_investor_limits_for_issuance(
    limits_rule: &InvestorLimits,
    to_region: u64,
    to_is_accredited: bool,
    to_is_qualified: bool,
    to_is_new_investor: bool,
) {
    // Only check limits if this creates a new investor
    if (!to_is_new_investor) return;

    // TODO: Get actual counts from registry
    let total_investors = 0;
    let accredited_count = 0;
    let us_count = 0;
    let us_accredited = 0;
    let jp_count = 0;
    // TODO get count for country

    // Validate total investor limit
    limits_rule.validate_issuance_total_investors(total_investors, to_is_new_investor);

    // Validate non-accredited limit
    if (!to_is_accredited) {
        let non_accredited = total_investors - accredited_count;
        limits_rule.validate_issuance_non_accredited(non_accredited, to_is_new_investor);
    };

    // Region-specific validations
    if (to_region == US) {
        // US investor limit
        limits_rule.validate_issuance_us_investors(us_count, total_investors, to_is_new_investor);
        if (to_is_accredited) {
            limits_rule.validate_issuance_us_accredited(us_accredited, to_is_new_investor);
        }
    } else if (to_region == EU && !to_is_qualified) {
        // EU retail = EU + not qualified
        let retail_count = 0;
        // TODO: let eu_retail_count for country
        limits_rule.validate_issuance_eu_retail(retail_count, to_is_new_investor);
    } else if (to_region == JP) {
        // JP investor limit
        limits_rule.validate_issuance_jp_investors(jp_count, to_is_new_investor);
    };
}

/// Validate US investor limits
public fun validate_us_investor_limits<T>(
    limits_rule: &InvestorLimits,
    // registry: &InvestorRegistry<T>,
    from_is_exit_investor: bool,
    from_is_accredited: bool,
    to_is_new_investor: bool,
    to_is_accredited: bool,
    equal_country: bool,
) {
    // let us_count = registry.us_count();
    // let total_investors = registry.total_investors();
    let us_count = 0;
    let total_investors = 0;

    limits_rule.validate_transfer_us_investors(
        us_count,
        total_investors,
        from_is_exit_investor,
        to_is_new_investor,
        equal_country,
    );

    if (to_is_accredited) {
        // let us_accredited = registry.us_accredited_count();
        let us_accredited = 0;

        limits_rule.validate_transfer_us_accredited(
            us_accredited,
            to_is_new_investor,
            from_is_exit_investor,
            from_is_accredited,
            equal_country,
        );
    };
}

/// Validate total investor count
public fun validate_transfer_total_investors(
    rule: &InvestorLimits,
    current_count: u64,
    from_is_exit_investor: bool,
    to_is_new_investor: bool,
) {
    if (rule.total_investors_limit == 0) return;

    if (to_is_new_investor && !from_is_exit_investor) {
        assert!(current_count < rule.total_investors_limit, EMaxInvestorsExceeded);
    }
}

/// Validate total investor count
public fun validate_issuance_total_investors(
    rule: &InvestorLimits,
    current_count: u64,
    to_is_new_investor: bool,
) {
    if (rule.total_investors_limit == 0) return;

    if (to_is_new_investor) {
        assert!(current_count < rule.total_investors_limit, EMaxInvestorsExceeded);
    }
}

/// Validate US investor count
public fun validate_transfer_us_investors(
    rule: &InvestorLimits,
    current_us_count: u64,
    total_count: u64,
    from_is_exit_investor: bool,
    to_is_new_us_investor: bool,
    equal_country: bool,
) {
    if (rule.us_investors_limit == 0) return;

    if (to_is_new_us_investor && (!equal_country || !from_is_exit_investor)) {
        assert!(current_us_count < rule.us_investors_limit, EMaxUSInvestorsExceeded);

        // Check percentage limit
        if (rule.max_us_percentage > 0 && total_count > 0) {
            assert!(
                current_us_count * 100 < total_count * rule.max_us_percentage,
                EMaxUSInvestorsExceeded,
            );
        };
    }
}

/// Validate US investor count
public fun validate_issuance_us_investors(
    rule: &InvestorLimits,
    current_us_count: u64,
    total_count: u64,
    is_new_us_investor: bool,
) { if (rule.us_investors_limit == 0) return; if (is_new_us_investor) {
        // Check absolute limit
        if (rule.us_investors_limit > 0) {
            assert!(current_us_count < rule.us_investors_limit, EMaxUSInvestorsExceeded);
        };

        // Check percentage limit
        if (rule.max_us_percentage > 0 && total_count > 0) {
            assert!(
                current_us_count * 100 < total_count * rule.max_us_percentage,
                EMaxUSInvestorsExceeded,
            );
        };
    } }

/// Validate US accredited investor count
public fun validate_transfer_us_accredited(
    rule: &InvestorLimits,
    current_count: u64,
    to_is_new_investor: bool,
    from_is_exit_investor: bool,
    from_is_accredited: bool,
    equal_country: bool,
) {
    if (rule.us_accredited_limit == 0) return;

    if (to_is_new_investor && (!equal_country || !from_is_accredited || !from_is_exit_investor)) {
        assert!(current_count < rule.us_accredited_limit, EMaxUSAccreditedExceeded);
    }
}

/// Validate US accredited investor count
public fun validate_issuance_us_accredited(
    rule: &InvestorLimits,
    current_count: u64,
    to_is_new_investor: bool,
) {
    if (rule.us_accredited_limit == 0) return;

    if (to_is_new_investor) {
        assert!(current_count < rule.us_accredited_limit, EMaxUSAccreditedExceeded);
    }
}

/// Validate non-accredited investor count
public fun validate_transfer_non_accredited(
    rule: &InvestorLimits,
    current_non_accredited: u64,
    to_is_new_investor: bool,
    from_is_exit_investor: bool,
    from_is_accredited: bool,
) {
    if (rule.non_accredited_limit == 0) return;

    if (to_is_new_investor && (from_is_accredited || !from_is_exit_investor)) {
        assert!(current_non_accredited < rule.non_accredited_limit, EMaxNonAccreditedExceeded);
    }
}

/// Validate non-accredited investor count
public fun validate_issuance_non_accredited(
    rule: &InvestorLimits,
    current_count: u64,
    to_is_new_investor: bool,
) {
    if (rule.us_accredited_limit == 0) return;

    if (to_is_new_investor) {
        assert!(current_count < rule.non_accredited_limit, EMaxUSAccreditedExceeded);
    }
}

/// Validate EU retail investor count
public fun validate_transfer_eu_retail(
    rule: &InvestorLimits,
    current_count: u64,
    from_is_exit_investor: bool,
    to_is_new_eu_retail_investor: bool,
    equal_country: bool,
) {
    if (rule.eu_retail_limit == 0) return;

    if (to_is_new_eu_retail_investor && (!equal_country || !from_is_exit_investor)) {
        assert!(current_count < rule.eu_retail_limit, EMaxEURetailExceeded);
    }
}

/// Validate EU retail investor count
public fun validate_issuance_eu_retail(
    rule: &InvestorLimits,
    current_count: u64,
    to_is_new_eu_retail_investor: bool,
) {
    if (rule.eu_retail_limit == 0) return;

    if (to_is_new_eu_retail_investor) {
        assert!(current_count < rule.eu_retail_limit, EMaxEURetailExceeded);
    }
}

/// Validate JP investor count
public fun validate_transfer_jp_investors(
    rule: &InvestorLimits,
    current_count: u64,
    from_is_exit_investor: bool,
    to_is_new_jp_investor: bool,
    equal_country: bool,
) {
    if (rule.jp_investors_limit == 0) return;

    if (to_is_new_jp_investor && (!equal_country || !from_is_exit_investor)) {
        assert!(current_count < rule.jp_investors_limit, EMaxJPInvestorsExceeded);
    }
}

/// Validate JP investor count
public fun validate_issuance_jp_investors(
    rule: &InvestorLimits,
    current_count: u64,
    to_is_new_jp_investor: bool,
) {
    if (rule.jp_investors_limit == 0) return;

    if (to_is_new_jp_investor) {
        assert!(current_count < rule.jp_investors_limit, EMaxJPInvestorsExceeded);
    }
}

/// Validate minimum total investors requirement
/// Used to prevent transfers that would reduce total investors below minimum
/// is_losing_investor: true if this action would cause an investor to have 0 balance
public fun validate_transfer_minimum_total_investors(
    rule: &InvestorLimits,
    current_count: u64,
    from_is_exit_investor: bool,
    to_is_new_investor: bool,
) {
    if (rule.minimum_total_investors == 0) return;

    if (from_is_exit_investor && !to_is_new_investor) {
        assert!(current_count > rule.minimum_total_investors, EBelowMinimumInvestors);
    };
}

// ==================== Query Functions ====================

public fun total_limit(rule: &InvestorLimits): u64 {
    rule.total_investors_limit
}

public fun minimum_total_investors(rule: &InvestorLimits): u64 {
    rule.minimum_total_investors
}

public fun us_limit(rule: &InvestorLimits): u64 {
    rule.us_investors_limit
}

public fun us_accredited_limit(rule: &InvestorLimits): u64 {
    rule.us_accredited_limit
}

public fun non_accredited_limit(rule: &InvestorLimits): u64 {
    rule.non_accredited_limit
}

public fun jp_limit(rule: &InvestorLimits): u64 {
    rule.jp_investors_limit
}

public fun eu_retail_limit(rule: &InvestorLimits): u64 {
    rule.eu_retail_limit
}

public fun max_us_percentage(rule: &InvestorLimits): u64 {
    rule.max_us_percentage
}
