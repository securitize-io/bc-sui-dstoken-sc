/// Module: backdating_issuance
///
/// Configuration rule that controls whether backdating is allowed for issuances.
/// The compliance service reads this configuration to determine the effective
/// issuance timestamp.
module securitize::backdating_issuance;

use securitize::{
    abilities::{ManageRules, RegisterRule},
    events::emit_bool_rule_set_event,
    rule_wrapper::{RuleInitWrapper, RuleUpdateWrapper, new_init},
    trust_service::Auth,
    version::Version
};

// ==== Error Codes ====

#[error(code = 0)]
const ENotAuthorized: vector<u8> = b"Caller is not authorized to perform this action";

// ==== Structs ====

/// Backdating issuance rule configuration
public struct BackdatingIssuance has drop, store {
    /// Whether backdating is allowed for issuances
    disallow_backdating: bool,
}

// ==================== Initialization ====================

/// Create a new BackdatingIssuance rule
///
/// # Aborts
/// * `ENotAuthorized` - If caller lacks RegisterRule ability
public fun new<T>(
    auth: &Auth<T>,
    disallow_backdating: bool,
    version: &Version,
    ctx: &TxContext,
): RuleInitWrapper<BackdatingIssuance> {
    version.check_is_valid();
    assert!(auth.owner_has_ability<T, RegisterRule>(ctx.sender()), ENotAuthorized);
    emit_bool_rule_set_event<T>(
        b"disallow_backdating".to_string(),
        false,
        disallow_backdating,
    );
    new_init(BackdatingIssuance {
        disallow_backdating,
    })
}

// ==================== Rule Management ====================

/// Set whether backdating is allowed
///
/// # Aborts
/// * `ENotAuthorized` - If caller lacks ManageRules ability
public fun set_disallow_backdating<T>(
    auth: &Auth<T>,
    wrapper: &mut RuleUpdateWrapper<BackdatingIssuance>,
    disallow: bool,
    version: &Version,
    ctx: &TxContext,
) {
    version.check_is_valid();
    assert!(auth.owner_has_ability<T, ManageRules>(ctx.sender()), ENotAuthorized);
    let rule = wrapper.borrow_update_mut();
    emit_bool_rule_set_event<T>(
        b"disallow_backdating".to_string(),
        rule.disallow_backdating,
        disallow,
    );
    rule.disallow_backdating = disallow;
}

// ==================== View Functions ====================

/// Check if backdating is allowed
public fun is_backdating_allowed(rule: &BackdatingIssuance): bool {
    !rule.disallow_backdating
}
