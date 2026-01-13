/// Module: accredited_only
///
/// Rule that restricts transfers to only accredited investors.
/// Can be configured globally or for specific jurisdictions.
module securitize::accredited_only;

use securitize::{
    abilities::ManageRules,
    rule_wrapper::RuleWrapper,
    trust_service::Auth,
    version::Version,
};
use std::string::String;
use sui::event;

// ==== Error Codes ====

const ENotAccredited: u64 = 0;
const ENotUSAccredited: u64 = 1;
const ENotAuthorized: u64 = 2;

// ==== Compliance Region Constants ====

const US: u64 = 1;

// ==== Structs ====

/// Accredited-only rule configuration
public struct AccreditedOnly has drop, store {
    /// Require accreditation globally
    force_accredited: bool,
    /// Require US accreditation for US investors
    force_us_accredited: bool,
}

// ==== Events ====

public struct DSComplianceAccreditedOnlyRuleCreated<phantom T> has copy, drop {
    force_accredited: bool,
    force_us_accredited: bool,
}

public struct DSComplianceAccreditedOnlyRuleSet<phantom T, V: copy + drop> has copy, drop {
    field: String,
    old_value: V,
    new_value: V,
}

// ==================== Initialization ====================

/// Create a new AccreditedOnly rule
///
/// # Aborts
/// * `ENotAuthorized` - If caller lacks ManageRules ability
public fun new<T>(
    auth: &Auth<T>,
    force_accredited: bool,
    force_us_accredited: bool,
    version: &Version,
    ctx: &TxContext,
): AccreditedOnly {
    version.check_is_valid();
    assert!(auth.owner_has_ability<T, ManageRules>(ctx.sender()), ENotAuthorized);
    event::emit(DSComplianceAccreditedOnlyRuleCreated<T> {
        force_accredited,
        force_us_accredited,
    });
    AccreditedOnly {
        force_accredited,
        force_us_accredited,
    }
}

// ==================== Rule Management ====================

/// Set global accreditation requirement
///
/// # Aborts
/// * `ENotAuthorized` - If caller lacks ManageRules ability
public fun set_force_accredited<T>(
    auth: &Auth<T>,
    wrapper: &mut RuleWrapper<AccreditedOnly>,
    force: bool,
    version: &Version,
    ctx: &TxContext,
) {
    version.check_is_valid();
    assert!(auth.owner_has_ability<T, ManageRules>(ctx.sender()), ENotAuthorized);
    let rule = wrapper.borrow_mut();
    event::emit(DSComplianceAccreditedOnlyRuleSet<T, bool> {
        field: b"force_accredited".to_string(),
        old_value: rule.force_accredited,
        new_value: force,
    });
    rule.force_accredited = force;
}

/// Set US accreditation requirement
///
/// # Aborts
/// * `ENotAuthorized` - If caller lacks ManageRules ability
public fun set_force_us_accredited<T>(
    auth: &Auth<T>,
    wrapper: &mut RuleWrapper<AccreditedOnly>,
    force: bool,
    version: &Version,
    ctx: &TxContext,
) {
    version.check_is_valid();
    assert!(auth.owner_has_ability<T, ManageRules>(ctx.sender()), ENotAuthorized);
    let rule = wrapper.borrow_mut();
    event::emit(DSComplianceAccreditedOnlyRuleSet<T, bool> {
        field: b"force_us_accredited".to_string(),
        old_value: rule.force_us_accredited,
        new_value: force,
    });
    rule.force_us_accredited = force;
}

// ==================== Validation ====================

/// Validate that investor is accredited based on rule configuration.
///
/// # Aborts
/// * `ENotAccredited` - If global accreditation is required and investor is not accredited
/// * `ENotUSAccredited` - If US accreditation is required, investor is in US, and not accredited
public fun validate_rule(rule: &AccreditedOnly, region: u64, is_accredited: bool) {
    // Check global requirement
    if (rule.force_accredited) {
        assert!(is_accredited, ENotAccredited);
    };

    // Check US-specific requirement for US region
    if (rule.force_us_accredited && region == US) {
        assert!(is_accredited, ENotUSAccredited);
    };
}

// ==================== View Functions ====================

/// Check if global accreditation is required
public fun is_force_accredited(rule: &AccreditedOnly): bool {
    rule.force_accredited
}

/// Check if US accreditation is required
public fun is_force_us_accredited(rule: &AccreditedOnly): bool {
    rule.force_us_accredited
}
