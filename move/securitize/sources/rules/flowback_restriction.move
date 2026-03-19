/// Module: flowback_restriction
///
/// Rule that prevents non-US investors from transferring tokens to US investors
/// during a specified Regulation S distribution period flowback restriction.
module securitize::flowback_restriction;

use securitize::{
    abilities::{ManageRules, RegisterRule},
    events::emit_uint_rule_set_event,
    rule_wrapper::{RuleInitWrapper, RuleUpdateWrapper, new_init},
    trust_service::Auth,
    version::Version
};
use sui::clock::Clock;

// ==== Error Codes ====

#[error(code = 0)]
const EFlowbackRestricted: vector<u8> =
    b"Transfer from non-US to US investor is restricted during flowback period";
#[error(code = 1)]
const ENotAuthorized: vector<u8> = b"Caller is not authorized to perform this action";

// ==== Compliance Region Constants ====

const US: u64 = 1;

// ==== Structs ====

/// Flowback restriction configuration
public struct FlowbackRestriction has drop, store {
    /// End time (in ms) for the flowback restriction period (0 = transfer restriction)
    block_flowback_end_time_ms: u64,
}

// ==================== Initialization ====================

/// Create a new FlowbackRestriction rule with an end time
///
/// # Aborts
/// * `ENotAuthorized` - If caller lacks RegisterRule ability
public fun new<T>(
    auth: &Auth<T>,
    block_flowback_end_time_ms: u64,
    version: &Version,
    ctx: &TxContext,
): RuleInitWrapper<T, FlowbackRestriction> {
    version.check_is_valid();
    assert!(auth.owner_has_ability<T, RegisterRule>(ctx.sender()), ENotAuthorized);
    emit_uint_rule_set_event<T>(
        b"blockFlowbackEndTime".to_string(),
        0,
        block_flowback_end_time_ms,
    );
    new_init(FlowbackRestriction {
        block_flowback_end_time_ms,
    })
}

// ==================== Rule Management ====================

/// Set flowback end time
///
/// # Aborts
/// * `ENotAuthorized` - If caller lacks ManageRules ability
public fun set_flowback_end_time<T>(
    auth: &Auth<T>,
    wrapper: &mut RuleUpdateWrapper<T, FlowbackRestriction>,
    end_time: u64,
    version: &Version,
    ctx: &TxContext,
) {
    version.check_is_valid();
    assert!(auth.owner_has_ability<T, ManageRules>(ctx.sender()), ENotAuthorized);
    let rule = wrapper.borrow_update_mut();
    emit_uint_rule_set_event<T>(
        b"blockFlowbackEndTime".to_string(),
        rule.block_flowback_end_time_ms,
        end_time,
    );
    rule.block_flowback_end_time_ms = end_time;
}

// ==================== Validation ====================

/// Validate that flowback restriction doesn't apply to this transfer.
///
/// This checks if a non-US investor is trying to transfer to a US investor
/// during the restricted period.
///
/// # Aborts
/// * `EFlowbackRestricted` - If non-US to US transfer during active restriction period
public fun validate_rule(
    rule: &FlowbackRestriction,
    from_region: u64,
    to_region: u64,
    from_is_special_wallet: bool,
    timestamp_ms: u64,
) {
    let end = rule.block_flowback_end_time_ms;

    let is_non_us_to_us = from_region != US && to_region == US;
    let restriction_active = (end == 0) || (timestamp_ms < end);

    assert!(
        !(is_non_us_to_us && !from_is_special_wallet && restriction_active),
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
