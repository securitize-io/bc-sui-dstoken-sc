/// Module: backdating_issuance
///
/// Configuration rule that controls whether backdating is allowed for issuances.
/// The compliance service reads this configuration to determine the effective
/// issuance timestamp.
module securitize::backdating_issuance;

use securitize::{
    abilities::ManageRules,
    rule_wrapper::RuleWrapper,
    trust_service::Auth,
    version::Version,
};
use std::string::String;
use sui::event;

// ==== Error Codes ====

const ENotAuthorized: u64 = 0;

// ==== Structs ====

/// Backdating issuance rule configuration
public struct BackdatingIssuance has drop, store {
    /// Whether backdating is allowed for issuances
    disallow_backdating: bool,
}

// ==== Events ====

public struct DSComplianceBackdatingIssuanceRuleCreated<phantom T> has copy, drop {
    disallow_backdating: bool,
}

public struct DSComplianceBackdatingIssuanceRuleSet<phantom T, V: copy + drop> has copy, drop {
    field: String,
    old_value: V,
    new_value: V,
}

// ==================== Initialization ====================

/// Create a new BackdatingIssuance rule
///
/// # Aborts
/// * `ENotAuthorized` - If caller lacks ManageRules ability
public fun new<T>(
    auth: &Auth<T>,
    disallow_backdating: bool,
    version: &Version,
    ctx: &TxContext,
): BackdatingIssuance {
    version.check_is_valid();
    assert!(auth.owner_has_ability<T, ManageRules>(ctx.sender()), ENotAuthorized);
    event::emit(DSComplianceBackdatingIssuanceRuleCreated<T> {
        disallow_backdating,
    });
    BackdatingIssuance {
        disallow_backdating,
    }
}

// ==================== Rule Management ====================

/// Set whether backdating is allowed
///
/// # Aborts
/// * `ENotAuthorized` - If caller lacks ManageRules ability
public fun set_disallow_backdating<T>(
    auth: &Auth<T>,
    wrapper: &mut RuleWrapper<BackdatingIssuance>,
    disallow: bool,
    version: &Version,
    ctx: &TxContext,
) {
    version.check_is_valid();
    assert!(auth.owner_has_ability<T, ManageRules>(ctx.sender()), ENotAuthorized);
    let rule = wrapper.borrow_mut();
    event::emit(DSComplianceBackdatingIssuanceRuleSet<T, bool> {
        field: b"disallow_backdating".to_string(),
        old_value: rule.disallow_backdating,
        new_value: disallow,
    });
    rule.disallow_backdating = disallow;
}

// ==================== View Functions ====================

/// Check if backdating is allowed
public fun is_backdating_allowed(rule: &BackdatingIssuance): bool {
    !rule.disallow_backdating
}
