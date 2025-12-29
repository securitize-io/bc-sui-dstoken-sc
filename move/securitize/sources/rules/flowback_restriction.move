/// Module: flowback_restriction
///
/// Rule that prevents non-US investors from transferring tokens to US investors
/// during a specified Regulation S distribution period (flowback restriction).
module securitize::flowback_restriction;

use sui::clock::Clock;
use securitize::version::Version;
use securitize::trust_service::Auth;
use std::string::String;
use sui::event;

// ==== TEMP Compliance Region Constants ====

const US: u64 = 1;

// ==== Error Codes ====

const EFlowbackRestricted: u64 = 0;

// ==== Abilities ====

public struct ManageFlowbackRestriction() has drop;

// ==== Events ====

public struct DSComplianceFlowbackRestrictionRuleCreated<phantom T> has copy, drop {
    block_flowback_end_time_ms: u64,
}

public struct DSComplianceFlowbackRestrictionRuleSet<phantom T, V: copy + drop> has copy, drop {
    field: String,
    old_value: V,
    new_value: V,
}

// ==== Structs ====

/// Flowback restriction configuration
public struct FlowbackRestriction has drop, store {
    /// End time (in ms) for the flowback restriction period (0 = transfer restriction)
    block_flowback_end_time_ms: u64,
}

// ==================== Initialization ====================

/// Create a new FlowbackRestriction rule with an end time
public fun new<T>(
    auth: &Auth<T>,
    block_flowback_end_time_ms: u64,
    version: &Version,
    ctx: &TxContext,
): FlowbackRestriction {
    version.check_is_valid();
    auth.owner_has_ability<T, ManageFlowbackRestriction>(ctx.sender());
    event::emit(DSComplianceFlowbackRestrictionRuleCreated<T> {
        block_flowback_end_time_ms,
    });
    FlowbackRestriction {
        block_flowback_end_time_ms,
    }
}

// ==================== Rule Management ====================

/// Set flowback end time
public fun set_flowback_end_time<T>(
    auth: &Auth<T>,
    rule: &mut FlowbackRestriction,
    end_time: u64,
    version: &Version,
    ctx: &TxContext,
) {
    version.check_is_valid();
    auth.owner_has_ability<T, ManageFlowbackRestriction>(ctx.sender());
    event::emit(DSComplianceFlowbackRestrictionRuleSet<T, u64> {
        field: b"block_flowback_end_time_ms".to_string(),
        old_value: rule.block_flowback_end_time_ms,
        new_value: end_time,
    });
    rule.block_flowback_end_time_ms = end_time;
}

// ==================== Validation ====================

/// Validate that flowback restriction doesn't apply to this transfer
///
/// This checks if a non-US investor is trying to transfer to a US investor
/// during the restricted period.
public fun validate_rule(
    rule: &FlowbackRestriction,
    from_region: u64,
    to_region: u64,
    from_is_platform_wallet: bool,
    timestamp_ms: u64,
) {
    let end = rule.block_flowback_end_time_ms;

    let is_non_us_to_us = from_region != US && to_region == US;
    let restriction_active = (end == 0) || (timestamp_ms < end);

    assert!(
        !(is_non_us_to_us && !from_is_platform_wallet && restriction_active),
        EFlowbackRestricted,
    );
}

// ==================== View Functions ====================

/// Get flowback end time
public fun flowback_end_time(rule: &FlowbackRestriction): u64 {
    rule.block_flowback_end_time_ms
}

/// Check if flowback restriction is currently active
public fun is_active(rule: &FlowbackRestriction, clock: &Clock): bool {
    if (rule.block_flowback_end_time_ms == 0) {
        return false
    };

    let current_time = clock.timestamp_ms();
    current_time < rule.block_flowback_end_time_ms
}
