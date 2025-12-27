/// Module: authorized_securities
///
/// Rule that validates issuance against a maximum authorized securities limit.
/// This ensures the total supply never exceeds the authorized amount,
/// maintaining compliance with regulatory requirements for authorized offerings.
///
/// When max_supply is 0, the check is disabled (unlimited issuance allowed).
module securitize::authorized_securities;

use securitize::version::Version;

// ==== Error Codes ====

const EMaxAuthorizedSecuritiesExceeded: u64 = 0;

// ==== Structs ====

/// Authorized securities configuration
public struct AuthorizedSecurities has drop, store {
    max_supply: u64,
}

// ==================== Initialization ====================

/// Create a new AuthorizedSecurities rule
/// Starts with max_supply of 0 (unlimited)
public fun new(version: &Version): AuthorizedSecurities {
    version.check_is_valid();
    AuthorizedSecurities {
        max_supply: 0,
    }
}

// ==================== Rule Management ====================

/// Set the maximum authorized securities (max supply)
public fun set_max_supply(
    rule: &mut AuthorizedSecurities,
    max_supply: u64,
    version: &Version,
) {
    version.check_is_valid();
    rule.max_supply = max_supply;
}

// ==================== Validation ====================

/// Validate that issuance does not exceed max authorized securities
public fun validate_rule(
    rule: &AuthorizedSecurities,
    total_supply: u64,
    issuance_value: u64,
) {
    // If max_supply is 0, check is disabled (unlimited)
    if (rule.max_supply == 0) return;

    assert!(
        total_supply + issuance_value <= rule.max_supply,
        EMaxAuthorizedSecuritiesExceeded
    );
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
