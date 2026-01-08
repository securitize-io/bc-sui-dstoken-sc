/// Module: backdating_issuance
///
/// Configuration rule that controls whether backdating is allowed for issuances.
/// The compliance service reads this configuration to determine the effective
/// issuance timestamp.
module securitize::backdating_issuance;

use securitize::{abilities::ManageRules, trust_service::Auth, version::Version};
use std::string::String;
use sui::event;

// ==== Structs ====

/// Backdating issuance rule configuration
public struct BackdatingIssuance has drop, store {
    /// Whether backdating is allowed for issuances
    allow_backdating: bool,
}

// ==== Events ====

public struct DSComplianceBackdatingIssuanceRuleCreated<phantom T> has copy, drop {
    allow_backdating: bool,
}

public struct DSComplianceBackdatingIssuanceRuleSet<phantom T, V: copy + drop> has copy, drop {
    field: String,
    old_value: V,
    new_value: V,
}

// ==================== Initialization ====================

/// Create a new BackdatingIssuance rule
public fun new<T>(
    auth: &Auth<T>,
    allow_backdating: bool,
    version: &Version,
    ctx: &TxContext,
): BackdatingIssuance {
    version.check_is_valid();
    auth.owner_has_ability<T, ManageRules>(ctx.sender());
    event::emit(DSComplianceBackdatingIssuanceRuleCreated<T> {
        allow_backdating,
    });
    BackdatingIssuance {
        allow_backdating,
    }
}

// ==================== Rule Management ====================

/// Set whether backdating is allowed
public fun set_allow_backdating<T>(
    auth: &Auth<T>,
    rule: &mut BackdatingIssuance,
    allow: bool,
    version: &Version,
    ctx: &TxContext,
) {
    version.check_is_valid();
    auth.owner_has_ability<T, ManageRules>(ctx.sender());
    event::emit(DSComplianceBackdatingIssuanceRuleSet<T, bool> {
        field: b"allow_backdating".to_string(),
        old_value: rule.allow_backdating,
        new_value: allow,
    });
    rule.allow_backdating = allow;
}

// ==================== View Functions ====================

/// Check if backdating is allowed
public fun is_backdating_allowed(rule: &BackdatingIssuance): bool {
    rule.allow_backdating
}
