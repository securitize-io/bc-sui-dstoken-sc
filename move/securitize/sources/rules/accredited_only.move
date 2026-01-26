/// Module: accredited_only
///
/// Rule that restricts transfers to only accredited investors.
/// Can be configured globally or for specific jurisdictions.
module securitize::accredited_only;

use securitize::{
    abilities::{ManageRules, RegisterRule},
    events::emit_bool_rule_set_event,
    rule_wrapper::{RuleInitWrapper, RuleUpdateWrapper, new_init},
    trust_service::Auth,
    version::Version
};

// ==== Error Codes ====

#[error(code = 0)]
const ENotAccredited: vector<u8> = b"Investor is not accredited";
#[error(code = 1)]
const ENotUSAccredited: vector<u8> = b"US investor is not accredited";
#[error(code = 2)]
const ENotAuthorized: vector<u8> = b"Caller is not authorized to perform this action";

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

// ==================== Initialization ====================

/// Create a new AccreditedOnly rule
///
/// # Aborts
/// * `ENotAuthorized` - If caller lacks RegisterRule ability
public fun new<T>(
    auth: &Auth<T>,
    force_accredited: bool,
    force_us_accredited: bool,
    version: &Version,
    ctx: &TxContext,
): RuleInitWrapper<AccreditedOnly> {
    version.check_is_valid();
    assert!(auth.owner_has_ability<T, RegisterRule>(ctx.sender()), ENotAuthorized);
    emit_bool_rule_set_event<T>(
        b"force_accredited".to_string(),
        false,
        force_accredited,
    );
    emit_bool_rule_set_event<T>(
        b"force_us_accredited".to_string(),
        false,
        force_us_accredited,
    );
    new_init(AccreditedOnly {
        force_accredited,
        force_us_accredited,
    })
}

// ==================== Rule Management ====================

/// Set global accreditation requirement
///
/// # Aborts
/// * `ENotAuthorized` - If caller lacks ManageRules ability
public fun set_force_accredited<T>(
    auth: &Auth<T>,
    wrapper: &mut RuleUpdateWrapper<AccreditedOnly>,
    force: bool,
    version: &Version,
    ctx: &TxContext,
) {
    version.check_is_valid();
    assert!(auth.owner_has_ability<T, ManageRules>(ctx.sender()), ENotAuthorized);
    let rule = wrapper.borrow_update_mut();
    emit_bool_rule_set_event<T>(b"force_accredited".to_string(), rule.force_accredited, force);
    rule.force_accredited = force;
}

/// Set US accreditation requirement
///
/// # Aborts
/// * `ENotAuthorized` - If caller lacks ManageRules ability
public fun set_force_us_accredited<T>(
    auth: &Auth<T>,
    wrapper: &mut RuleUpdateWrapper<AccreditedOnly>,
    force: bool,
    version: &Version,
    ctx: &TxContext,
) {
    version.check_is_valid();
    assert!(auth.owner_has_ability<T, ManageRules>(ctx.sender()), ENotAuthorized);
    let rule = wrapper.borrow_update_mut();
    emit_bool_rule_set_event<T>(
        b"force_us_accredited".to_string(),
        rule.force_us_accredited,
        force,
    );
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
