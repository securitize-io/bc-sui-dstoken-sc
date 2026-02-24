/// Module: authorized_securities
///
/// Rule that validates issuance against a maximum authorized securities limit.
/// This ensures the total supply never exceeds the authorized amount,
/// maintaining compliance with regulatory requirements for authorized offerings.
///
/// When max_supply is 0, the check is disabled unlimited issuance allowed.
module securitize::authorized_securities;

use securitize::{
    abilities::{ManageRules, RegisterRule},
    events::emit_uint_rule_set_event,
    rule_wrapper::{RuleInitWrapper, RuleUpdateWrapper, new_init},
    trust_service::Auth,
    version::Version
};

// ==== Error Codes ====

#[error(code = 0)]
const EMaxAuthorizedSecuritiesExceeded: vector<u8> =
    b"Issuance would exceed maximum authorized securities";
#[error(code = 1)]
const ENotAuthorized: vector<u8> = b"Caller is not authorized to perform this action";

// ==== Structs ====

/// Authorized securities configuration
public struct AuthorizedSecurities has drop, store {
    max_supply: u64,
}

// ==================== Initialization ====================

/// Create a new AuthorizedSecurities rule
/// Starts with max_supply of 0 (unlimited)
///
/// # Aborts
/// * `ENotAuthorized` - If caller lacks ManageRules ability
public fun new<T>(
    auth: &Auth<T>,
    max_supply: u64,
    version: &Version,
    ctx: &TxContext,
): RuleInitWrapper<AuthorizedSecurities> {
    version.check_is_valid();
    assert!(auth.owner_has_ability<T, RegisterRule>(ctx.sender()), ENotAuthorized);
    emit_uint_rule_set_event<T>(
        b"authorizedSecurities".to_string(),
        0,
        max_supply,
    );
    new_init(AuthorizedSecurities {
        max_supply,
    })
}

// ==================== Rule Management ====================

/// Set the maximum authorized securities (max supply)
///
/// # Aborts
/// * `ENotAuthorized` - If caller lacks RegisterRule ability
public fun set_max_supply<T>(
    auth: &Auth<T>,
    wrapper: &mut RuleUpdateWrapper<AuthorizedSecurities>,
    max_supply: u64,
    version: &Version,
    ctx: &TxContext,
) {
    version.check_is_valid();
    assert!(auth.owner_has_ability<T, ManageRules>(ctx.sender()), ENotAuthorized);
    let rule = wrapper.borrow_update_mut();
    emit_uint_rule_set_event<T>(b"authorizedSecurities".to_string(), rule.max_supply, max_supply);
    rule.max_supply = max_supply;
}

// ==================== Validation ====================

/// Validate that issuance does not exceed max authorized securities.
///
/// # Aborts
/// * `EMaxAuthorizedSecuritiesExceeded` - If total supply plus issuance exceeds max_supply
public fun validate_rule(rule: &AuthorizedSecurities, total_supply: u64, issuance_value: u64) {
    // If max_supply is 0, check is disabled (unlimited)
    if (rule.max_supply == 0) return;

    assert!(total_supply + issuance_value <= rule.max_supply, EMaxAuthorizedSecuritiesExceeded);
}

// ==================== View Functions ====================

/// Get the max authorized securities limit
public fun max_supply(rule: &AuthorizedSecurities): u64 {
    rule.max_supply
}

/// Check if the limit is enforced (max_supply > 0)
public fun is_enforced(rule: &AuthorizedSecurities): bool {
    rule.max_supply > 0
}
