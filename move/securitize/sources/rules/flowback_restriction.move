/// Module: flowback_restriction
///
/// Rule that prevents non-US investors from transferring tokens to US investors
/// during a specified Regulation S distribution period (flowback restriction).
module securitize::flowback_restriction;

use sui::clock::Clock;
use securitize::version::Version;

// ==== TEMP Compliance Region Constants ====

const US: u64 = 1;
const EU: u64 = 2;
const FORBIDDEN: u64 = 4;
const JP: u64 = 8;

// ==== Error Codes ====

const EFlowbackRestricted: u64 = 0;

// ==== Structs ====

/// Flowback restriction configuration
public struct FlowbackRestriction has drop, store {
    /// End time (in ms) for the flowback restriction period (0 = transfer restriction)
    block_flowback_end_time_ms: u64,
}

// ==================== Initialization ====================

/// Create a new FlowbackRestriction rule with an end time
public fun new(block_flowback_end_time_ms: u64, version: &Version): FlowbackRestriction {
    version.check_is_valid();
    FlowbackRestriction {
        block_flowback_end_time_ms,
    }
}

// ==================== Rule Management ====================

/// Set flowback end time
public fun set_flowback_end_time(rule: &mut FlowbackRestriction, end_time: u64, version: &Version) {
    version.check_is_valid();
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
    clock: &Clock,
) {
    let end = rule.block_flowback_end_time_ms;
    let now = clock.timestamp_ms();

    let is_non_us_to_us = from_region != US && to_region == US;
    let restriction_active = (end == 0) || (now < end);

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
