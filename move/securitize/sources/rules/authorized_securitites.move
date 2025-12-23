/// Module: authorized_securities
///
/// Rule that manages a list of authorized securities that investors can hold.
/// This enables control over which security tokens are permitted for trading
/// and ensures compliance with regulatory requirements for authorized offerings.
///
/// Securities can be authorized or revoked by authorized roles, and transfers
/// can be validated to ensure only authorized securities are being traded.
module securitize::authorized_securities;

use securitize::version::Version;
use sui::vec_set::{Self, VecSet};
use std::string::String;

// ==== Error Codes ====

const ESecurityNotAuthorized: u64 = 0;
const ESecurityAlreadyAuthorized: u64 = 1;
const ESecurityNotFound: u64 = 2;
const EEmptySecurityId: u64 = 3;

// ==== Structs ====

/// Authorized securities configuration
public struct AuthorizedSecurities has drop, store {
    /// Set of authorized security identifiers (e.g., CUSIP, ISIN, or internal IDs)
    authorized_ids: VecSet<String>,
    /// Whether to enforce authorization checks (can be disabled for permissionless mode)
    enforcement_enabled: bool,
}

// ==================== Initialization ====================

/// Create a new AuthorizedSecurities rule
/// Starts with an empty set of authorized securities
public fun new(version: &Version): AuthorizedSecurities {
    version.check_is_valid();
    AuthorizedSecurities {
        authorized_ids: vec_set::empty(),
        enforcement_enabled: true,
    }
}

// ==================== Rule Management ====================

/// Authorize a security
public fun authorize_security(
    rule: &mut AuthorizedSecurities,
    security_id: String,
    version: &Version,
) {
    version.check_is_valid();
    assert!(security_id.length() > 0, EEmptySecurityId);
    assert!(!rule.authorized_ids.contains(&security_id), ESecurityAlreadyAuthorized);
    rule.authorized_ids.insert(security_id);
}

/// Revoke authorization for a security
public fun revoke_security(
    rule: &mut AuthorizedSecurities,
    security_id: String,
    version: &Version,
) {
    version.check_is_valid();
    assert!(rule.authorized_ids.contains(&security_id), ESecurityNotFound);
    rule.authorized_ids.remove(&security_id);
}

/// Enable or disable enforcement of authorization checks
public fun set_enforcement_enabled(
    rule: &mut AuthorizedSecurities,
    enabled: bool,
    version: &Version,
) {
    version.check_is_valid();
    rule.enforcement_enabled = enabled;
}

// ==================== Validation ====================

/// Validate that a security is authorized for transfer/issuance
///
/// # Arguments
/// * `rule` - The authorized securities configuration
/// * `security_id` - The security identifier to validate
///
/// # Aborts
/// * `ESecurityNotAuthorized` - If enforcement is enabled and security is not authorized
public fun validate_rule(
    rule: &AuthorizedSecurities,
    security_id: &String,
) {
    // Skip check if enforcement is disabled
    if (!rule.enforcement_enabled) return;

    assert!(rule.authorized_ids.contains(security_id), ESecurityNotAuthorized);
}

/// Validate multiple securities in a batch
public fun validate_securities(
    rule: &AuthorizedSecurities,
    security_ids: &vector<String>,
) {
    // Skip check if enforcement is disabled
    if (!rule.enforcement_enabled) return;

    security_ids.do_ref!(|id| {
        assert!(rule.authorized_ids.contains(id), ESecurityNotAuthorized);
    });
}

// ==================== View Functions ====================

/// Check if a security is authorized
public fun is_authorized(rule: &AuthorizedSecurities, security_id: &String): bool {
    rule.authorized_ids.contains(security_id)
}

/// Check if enforcement is enabled
public fun is_enforcement_enabled(rule: &AuthorizedSecurities): bool {
    rule.enforcement_enabled
}

/// Get the number of authorized securities
public fun authorized_count(rule: &AuthorizedSecurities): u64 {
    rule.authorized_ids.length()
}

/// Check if the rule has any authorized securities
public fun has_authorized_securities(rule: &AuthorizedSecurities): bool {
    rule.authorized_ids.length() > 0
}
