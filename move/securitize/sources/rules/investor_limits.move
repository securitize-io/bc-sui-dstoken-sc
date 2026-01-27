/// Module: investor_limits
///
/// Rule that enforces limits on the number of investors by category
/// total, accredited, non-accredited, by region, etc.
module securitize::investor_limits;

use securitize::{
    abilities::{ManageRules, RegisterRule},
    events::emit_uint_rule_set_event,
    registry_service::InvestorInfo,
    rule_wrapper::{RuleInitWrapper, RuleUpdateWrapper, new_init},
    trust_service::Auth,
    version::Version
};
use std::string::String;

// ==== Error Codes ====

#[error(code = 0)]
const EMaxInvestorsExceeded: vector<u8> = b"Maximum total investors limit exceeded";
#[error(code = 1)]
const EMaxUSInvestorsExceeded: vector<u8> = b"Maximum US investors limit exceeded";
#[error(code = 2)]
const EMaxUSAccreditedExceeded: vector<u8> = b"Maximum US accredited investors limit exceeded";
#[error(code = 3)]
const EMaxNonAccreditedExceeded: vector<u8> = b"Maximum non-accredited investors limit exceeded";
#[error(code = 4)]
const EMaxJPInvestorsExceeded: vector<u8> = b"Maximum JP investors limit exceeded";
#[error(code = 5)]
const EMaxEURetailExceeded: vector<u8> = b"Maximum EU retail investors limit exceeded";
#[error(code = 6)]
const EBelowMinimumInvestors: vector<u8> = b"Total investors would fall below minimum required";
#[error(code = 7)]
const ENotAuthorized: vector<u8> = b"Caller is not authorized to perform this action";

// ==== Compliance Region Constants ====

const US: u64 = 1;
const EU: u64 = 2;
const JP: u64 = 8;

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
///
/// # Aborts
/// * `ENotAuthorized` - If caller lacks RegisterRule ability
public fun new<T>(
    auth: &Auth<T>,
    total_investors_limit: u64,
    minimum_total_investors: u64,
    us_investors_limit: u64,
    us_accredited_limit: u64,
    non_accredited_limit: u64,
    jp_investors_limit: u64,
    eu_retail_limit: u64,
    max_us_percentage: u64,
    version: &Version,
    ctx: &TxContext,
): RuleInitWrapper<InvestorLimits> {
    version.check_is_valid();
    assert!(auth.owner_has_ability<T, RegisterRule>(ctx.sender()), ENotAuthorized);
    emit_uint_rule_set_event<T>(b"total_investors_limit".to_string(), 0, total_investors_limit);
    emit_uint_rule_set_event<T>(b"minimum_total_investors".to_string(), 0, minimum_total_investors);
    emit_uint_rule_set_event<T>(b"us_investors_limit".to_string(), 0, us_investors_limit);
    emit_uint_rule_set_event<T>(b"us_accredited_limit".to_string(), 0, us_accredited_limit);
    emit_uint_rule_set_event<T>(b"non_accredited_limit".to_string(), 0, non_accredited_limit);
    emit_uint_rule_set_event<T>(b"jp_investors_limit".to_string(), 0, jp_investors_limit);
    emit_uint_rule_set_event<T>(b"eu_retail_limit".to_string(), 0, eu_retail_limit);
    emit_uint_rule_set_event<T>(b"max_us_percentage".to_string(), 0, max_us_percentage);

    new_init(InvestorLimits {
        total_investors_limit,
        minimum_total_investors,
        us_investors_limit,
        us_accredited_limit,
        non_accredited_limit,
        jp_investors_limit,
        eu_retail_limit,
        max_us_percentage,
    })
}

// ==================== Rule Management ====================

/// Set total investor limit
///
/// # Aborts
/// * `ENotAuthorized` - If caller lacks ManageRules ability
public fun set_total_limit<T>(
    auth: &Auth<T>,
    wrapper: &mut RuleUpdateWrapper<InvestorLimits>,
    limit: u64,
    version: &Version,
    ctx: &TxContext,
) {
    version.check_is_valid();
    assert!(auth.owner_has_ability<T, ManageRules>(ctx.sender()), ENotAuthorized);
    let rule = wrapper.borrow_update_mut();
    emit_uint_rule_set_event<T>(
        b"total_investors_limit".to_string(),
        rule.total_investors_limit,
        limit,
    );
    rule.total_investors_limit = limit;
}

/// Set minimum total investors
///
/// # Aborts
/// * `ENotAuthorized` - If caller lacks ManageRules ability
public fun set_minimum_total_investors<T>(
    auth: &Auth<T>,
    wrapper: &mut RuleUpdateWrapper<InvestorLimits>,
    minimum: u64,
    version: &Version,
    ctx: &TxContext,
) {
    version.check_is_valid();
    assert!(auth.owner_has_ability<T, ManageRules>(ctx.sender()), ENotAuthorized);
    let rule = wrapper.borrow_update_mut();
    emit_uint_rule_set_event<T>(
        b"minimum_total_investors".to_string(),
        rule.minimum_total_investors,
        minimum,
    );
    rule.minimum_total_investors = minimum;
}

/// Set US investor limit
///
/// # Aborts
/// * `ENotAuthorized` - If caller lacks ManageRules ability
public fun set_us_limit<T>(
    auth: &Auth<T>,
    wrapper: &mut RuleUpdateWrapper<InvestorLimits>,
    limit: u64,
    version: &Version,
    ctx: &TxContext,
) {
    version.check_is_valid();
    assert!(auth.owner_has_ability<T, ManageRules>(ctx.sender()), ENotAuthorized);
    let rule = wrapper.borrow_update_mut();
    emit_uint_rule_set_event<T>(b"us_investors_limit".to_string(), rule.us_investors_limit, limit);
    rule.us_investors_limit = limit;
}

/// Set US accredited limit
///
/// # Aborts
/// * `ENotAuthorized` - If caller lacks ManageRules ability
public fun set_us_accredited_limit<T>(
    auth: &Auth<T>,
    wrapper: &mut RuleUpdateWrapper<InvestorLimits>,
    limit: u64,
    version: &Version,
    ctx: &TxContext,
) {
    version.check_is_valid();
    assert!(auth.owner_has_ability<T, ManageRules>(ctx.sender()), ENotAuthorized);
    let rule = wrapper.borrow_update_mut();
    emit_uint_rule_set_event<T>(
        b"us_accredited_limit".to_string(),
        rule.us_accredited_limit,
        limit,
    );
    rule.us_accredited_limit = limit;
}

/// Set non-accredited limit
///
/// # Aborts
/// * `ENotAuthorized` - If caller lacks ManageRules ability
public fun set_non_accredited_limit<T>(
    auth: &Auth<T>,
    wrapper: &mut RuleUpdateWrapper<InvestorLimits>,
    limit: u64,
    version: &Version,
    ctx: &TxContext,
) {
    version.check_is_valid();
    assert!(auth.owner_has_ability<T, ManageRules>(ctx.sender()), ENotAuthorized);
    let rule = wrapper.borrow_update_mut();
    emit_uint_rule_set_event<T>(
        b"non_accredited_limit".to_string(),
        rule.non_accredited_limit,
        limit,
    );
    rule.non_accredited_limit = limit;
}

/// Set JP investor limit
///
/// # Aborts
/// * `ENotAuthorized` - If caller lacks ManageRules ability
public fun set_jp_limit<T>(
    auth: &Auth<T>,
    wrapper: &mut RuleUpdateWrapper<InvestorLimits>,
    limit: u64,
    version: &Version,
    ctx: &TxContext,
) {
    version.check_is_valid();
    assert!(auth.owner_has_ability<T, ManageRules>(ctx.sender()), ENotAuthorized);
    let rule = wrapper.borrow_update_mut();
    emit_uint_rule_set_event<T>(b"jp_investors_limit".to_string(), rule.jp_investors_limit, limit);
    rule.jp_investors_limit = limit;
}

/// Set EU retail limit
///
/// # Aborts
/// * `ENotAuthorized` - If caller lacks ManageRules ability
public fun set_eu_retail_limit<T>(
    auth: &Auth<T>,
    wrapper: &mut RuleUpdateWrapper<InvestorLimits>,
    limit: u64,
    version: &Version,
    ctx: &TxContext,
) {
    version.check_is_valid();
    assert!(auth.owner_has_ability<T, ManageRules>(ctx.sender()), ENotAuthorized);
    let rule = wrapper.borrow_update_mut();
    emit_uint_rule_set_event<T>(b"eu_retail_limit".to_string(), rule.eu_retail_limit, limit);
    rule.eu_retail_limit = limit;
}

/// Set max US percentage
///
/// # Aborts
/// * `ENotAuthorized` - If caller lacks ManageRules ability
public fun set_max_us_percentage<T>(
    auth: &Auth<T>,
    wrapper: &mut RuleUpdateWrapper<InvestorLimits>,
    percentage: u64,
    version: &Version,
    ctx: &TxContext,
) {
    version.check_is_valid();
    assert!(auth.owner_has_ability<T, ManageRules>(ctx.sender()), ENotAuthorized);
    let rule = wrapper.borrow_update_mut();
    emit_uint_rule_set_event<T>(
        b"max_us_percentage".to_string(),
        rule.max_us_percentage,
        percentage,
    );
    rule.max_us_percentage = percentage;
}

// ==================== Validation ====================

/// Validate investor limits for transfer
public fun validate_investor_limits_for_transfer<T>(
    limits_rule: &InvestorLimits,
    registry: &InvestorInfo<T>,
    from_is_accredited: bool,
    from_is_exit_investor: bool,
    from_is_qualified: bool,
    to_region: u64,
    to_country: String,
    to_is_accredited: bool,
    to_is_qualified: bool,
    to_is_new_investor: bool,
    equal_region: bool,
    equal_country: bool,
) {
    let total_investors = registry.get_total_investors_count();
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
            registry,
            from_is_exit_investor,
            from_is_accredited,
            to_is_new_investor,
            to_is_accredited,
            equal_region,
        );
    } else if (to_region == JP) {
        let jp_count = registry.get_jp_investor_count();
        limits_rule.validate_transfer_jp_investors(
            jp_count,
            from_is_exit_investor,
            to_is_new_investor,
            equal_region,
        );
    } else if (to_region == EU && !to_is_qualified) {
        // TODO EU retail = EU region && not qualified (Retail)
        let mut eu_retail_count = registry.get_eu_retail_investor_count(to_country);
        if (eu_retail_count.is_some()) {
            limits_rule.validate_transfer_eu_retail(
                eu_retail_count.extract(),
                from_is_exit_investor,
                from_is_qualified,
                to_is_new_investor,
                equal_country,
            );
        }
    };

    // Validate non-accredited limits
    if (!to_is_accredited) {
        let accredited_count = registry.get_accredited_investor_count();
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
public fun validate_investor_limits_for_issuance<T>(
    limits_rule: &InvestorLimits,
    registry: &InvestorInfo<T>,
    to_region: u64,
    to_country: String,
    to_is_accredited: bool,
    to_is_qualified: bool,
    to_is_new_investor: bool,
) {
    // Only check limits if this creates a new investor
    if (!to_is_new_investor) return;

    let total_investors = registry.get_total_investors_count();
    let accredited_count = registry.get_accredited_investor_count();
    let us_count = registry.get_us_investor_count();
    let us_accredited = registry.get_us_accredited_investor_count();
    let jp_count = registry.get_jp_investor_count();

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
        // EU retail = EU && not qualified
        let mut retail_count = registry.get_eu_retail_investor_count(to_country);
        if (retail_count.is_some()) {
            limits_rule.validate_issuance_eu_retail(retail_count.extract(), to_is_new_investor);
        }
    } else if (to_region == JP) {
        // JP investor limit
        limits_rule.validate_issuance_jp_investors(jp_count, to_is_new_investor);
    };
}

/// Validate US investor limits
public fun validate_us_investor_limits<T>(
    limits_rule: &InvestorLimits,
    registry: &InvestorInfo<T>,
    from_is_exit_investor: bool,
    from_is_accredited: bool,
    to_is_new_investor: bool,
    to_is_accredited: bool,
    equal_region: bool,
) {
    let us_count = registry.get_us_investor_count();
    let total_investors = registry.get_total_investors_count();

    limits_rule.validate_transfer_us_investors(
        us_count,
        total_investors,
        from_is_exit_investor,
        to_is_new_investor,
        equal_region,
    );

    if (to_is_accredited) {
        let us_accredited = registry.get_us_accredited_investor_count();

        limits_rule.validate_transfer_us_accredited(
            us_accredited,
            to_is_new_investor,
            from_is_exit_investor,
            from_is_accredited,
            equal_region,
        );
    };
}

/// Validate total investor count.
///
/// # Aborts
/// * `EMaxInvestorsExceeded` - If adding new investor would exceed total limit
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

/// Validate total investor count.
///
/// # Aborts
/// * `EMaxInvestorsExceeded` - If adding new investor would exceed total limit
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

/// Validate US investor count.
///
/// # Aborts
/// * `EMaxUSInvestorsExceeded` - If adding new US investor would exceed US limit
public fun validate_transfer_us_investors(
    rule: &InvestorLimits,
    current_us_count: u64,
    total_count: u64,
    from_is_exit_investor: bool,
    to_is_new_us_investor: bool,
    equal_region: bool,
) {
    let limit = effective_us_limit(rule.us_investors_limit, rule.max_us_percentage, total_count);

    if (limit == 0) return;

    if (to_is_new_us_investor && (!equal_region || !from_is_exit_investor)) {
        assert!(current_us_count < limit, EMaxUSInvestorsExceeded);
    }
}

/// Validate US investor count.
///
/// # Aborts
/// * `EMaxUSInvestorsExceeded` - If adding new US investor would exceed US limit
public fun validate_issuance_us_investors(
    rule: &InvestorLimits,
    current_us_count: u64,
    total_count: u64,
    is_new_us_investor: bool,
) {
    let limit = effective_us_limit(rule.us_investors_limit, rule.max_us_percentage, total_count);

    if (limit == 0) return;

    if (is_new_us_investor) {
        // Check limit
        assert!(current_us_count < limit, EMaxUSInvestorsExceeded);
    }
}

/// Validate US accredited investor count.
///
/// # Aborts
/// * `EMaxUSAccreditedExceeded` - If adding new US accredited investor would exceed limit
public fun validate_transfer_us_accredited(
    rule: &InvestorLimits,
    current_count: u64,
    to_is_new_investor: bool,
    from_is_exit_investor: bool,
    from_is_accredited: bool,
    equal_region: bool,
) {
    if (rule.us_accredited_limit == 0) return;

    if (to_is_new_investor && (!equal_region || !from_is_accredited || !from_is_exit_investor)) {
        assert!(current_count < rule.us_accredited_limit, EMaxUSAccreditedExceeded);
    }
}

/// Validate US accredited investor count.
///
/// # Aborts
/// * `EMaxUSAccreditedExceeded` - If adding new US accredited investor would exceed limit
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

/// Validate non-accredited investor count.
///
/// # Aborts
/// * `EMaxNonAccreditedExceeded` - If adding new non-accredited investor would exceed limit
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

/// Validate non-accredited investor count.
///
/// # Aborts
/// * `EMaxNonAccreditedExceeded` - If adding new non-accredited investor would exceed limit
public fun validate_issuance_non_accredited(
    rule: &InvestorLimits,
    current_count: u64,
    to_is_new_investor: bool,
) {
    if (rule.non_accredited_limit == 0) return;

    if (to_is_new_investor) {
        assert!(current_count < rule.non_accredited_limit, EMaxNonAccreditedExceeded);
    }
}

/// Validate EU retail investor count.
///
/// # Aborts
/// * `EMaxEURetailExceeded` - If adding new EU retail investor would exceed limit
public fun validate_transfer_eu_retail(
    rule: &InvestorLimits,
    current_count: u64,
    from_is_exit_investor: bool,
    from_is_qualified: bool,
    to_is_new_eu_retail_investor: bool,
    equal_country: bool,
) {
    if (rule.eu_retail_limit == 0) return;

    let from_is_exit_investor_retail_equal_country =
        equal_country && from_is_exit_investor && !from_is_qualified;

    if (to_is_new_eu_retail_investor && !from_is_exit_investor_retail_equal_country) {
        assert!(current_count < rule.eu_retail_limit, EMaxEURetailExceeded);
    }
}

/// Validate EU retail investor count.
///
/// # Aborts
/// * `EMaxEURetailExceeded` - If adding new EU retail investor would exceed limit
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

/// Validate JP investor count.
///
/// # Aborts
/// * `EMaxJPInvestorsExceeded` - If adding new JP investor would exceed limit
public fun validate_transfer_jp_investors(
    rule: &InvestorLimits,
    current_count: u64,
    from_is_exit_investor: bool,
    to_is_new_jp_investor: bool,
    equal_region: bool,
) {
    if (rule.jp_investors_limit == 0) return;

    if (to_is_new_jp_investor && (!equal_region || !from_is_exit_investor)) {
        assert!(current_count < rule.jp_investors_limit, EMaxJPInvestorsExceeded);
    }
}

/// Validate JP investor count.
///
/// # Aborts
/// * `EMaxJPInvestorsExceeded` - If adding new JP investor would exceed limit
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

/// Validate minimum total investors requirement.
/// Used to prevent transfers that would reduce total investors below minimum.
///
/// # Aborts
/// * `EBelowMinimumInvestors` - If transfer would reduce count below minimum
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

/// Returns the effective US investor limit.
/// - If both absolute and percentage limits are set, returns their minimum.
/// - If only one is set, returns that one.
/// - If both are zero, returns 0 (unlimited).
/// Percentage limit uses floor(total * percentage / 100)
public fun effective_us_limit(absolute_limit: u64, max_percentage: u64, total: u64): u64 {
    let percentage_limit = if (max_percentage == 0) 0
    else (((total as u128) * (max_percentage as u128)) / 100) as u64;

    if (absolute_limit == 0) {
        percentage_limit
    } else if (percentage_limit == 0) {
        absolute_limit
    } else if (absolute_limit < percentage_limit) {
        absolute_limit
    } else {
        percentage_limit
    }
}

// ==================== View Functions ====================

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
