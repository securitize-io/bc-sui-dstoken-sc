/// Module: force_full_transfer
///
/// Rule that requires investors to transfer their entire token balance.
/// Can be configured separately for US investors or applied worldwide.
module securitize::force_full_transfer;

use securitize::{
    abilities::{ManageRules, RegisterRule},
    events::emit_bool_rule_set_event,
    rule_wrapper::{RuleInitWrapper, RuleUpdateWrapper, new_init},
    trust_service::Auth,
    version::Version
};

// ==== Error Codes ====

#[error(code = 0)]
const EPartialTransferNotAllowed: vector<u8> =
    b"Partial transfers not allowed - must transfer entire balance";
#[error(code = 1)]
const ENotAuthorized: vector<u8> = b"Caller is not authorized to perform this action";

// ==== Compliance Region Constants ====

const US: u64 = 1;

// ==== Structs ====

/// Force full transfer configuration
public struct ForceFullTransfer has drop, store {
    /// Require US investors to transfer entire balance
    force_full_transfer_us: bool,
    /// Require all investors worldwide to transfer entire balance
    force_full_transfer_worldwide: bool,
}

// ==================== Initialization ====================

/// Create a new ForceFullTransfer rule
///
/// # Aborts
/// * `ENotAuthorized` - If caller lacks RegisterRule ability
public fun new<T>(
    auth: &Auth<T>,
    force_full_transfer_us: bool,
    force_full_transfer_worldwide: bool,
    version: &Version,
    ctx: &TxContext,
): RuleInitWrapper<ForceFullTransfer> {
    version.check_is_valid();
    assert!(auth.owner_has_ability<T, RegisterRule>(ctx.sender()), ENotAuthorized);
    emit_bool_rule_set_event<T>(
        b"force_full_transfer_us".to_string(),
        false,
        force_full_transfer_us,
    );
    emit_bool_rule_set_event<T>(
        b"force_full_transfer_worldwide".to_string(),
        false,
        force_full_transfer_worldwide,
    );
    new_init(ForceFullTransfer {
        force_full_transfer_us,
        force_full_transfer_worldwide,
    })
}

// ==================== Rule Management ====================

/// Set force full transfer for US investors
///
/// # Aborts
/// * `ENotAuthorized` - If caller lacks ManageRules ability
public fun set_force_us<T>(
    auth: &Auth<T>,
    wrapper: &mut RuleUpdateWrapper<ForceFullTransfer>,
    force: bool,
    version: &Version,
    ctx: &TxContext,
) {
    version.check_is_valid();
    assert!(auth.owner_has_ability<T, ManageRules>(ctx.sender()), ENotAuthorized);
    let rule = wrapper.borrow_update_mut();
    emit_bool_rule_set_event<T>(
        b"force_full_transfer_us".to_string(),
        rule.force_full_transfer_us,
        force,
    );
    rule.force_full_transfer_us = force;
}

/// Set force full transfer worldwide
///
/// # Aborts
/// * `ENotAuthorized` - If caller lacks ManageRules ability
public fun set_force_worldwide<T>(
    auth: &Auth<T>,
    wrapper: &mut RuleUpdateWrapper<ForceFullTransfer>,
    force: bool,
    version: &Version,
    ctx: &TxContext,
) {
    version.check_is_valid();
    assert!(auth.owner_has_ability<T, ManageRules>(ctx.sender()), ENotAuthorized);
    let rule = wrapper.borrow_update_mut();
    emit_bool_rule_set_event<T>(
        b"force_full_transfer_worldwide".to_string(),
        rule.force_full_transfer_worldwide,
        force,
    );
    rule.force_full_transfer_worldwide = force;
}

// ==================== Validation ====================

/// Validate that transfer complies with force full transfer rules.
///
/// # Aborts
/// * `EPartialTransferNotAllowed` - If partial transfer when full transfer is required
public fun validate_rule(
    rule: &ForceFullTransfer,
    from_region: u64,
    from_is_special_wallet: bool,
    from_is_exit_investor: bool,
) {
    // Special wallets as senders are exempt from force full transfer rule
    if (from_is_special_wallet) return;
    // Check worldwide restriction first (applies to all)
    assert!(
        !rule.force_full_transfer_worldwide || from_is_exit_investor,
        EPartialTransferNotAllowed,
    );

    // Check US-specific restriction
    let is_us_investor = from_region == US;

    assert!(
        !rule.force_full_transfer_us || !is_us_investor || from_is_exit_investor,
        EPartialTransferNotAllowed,
    );
}

// ==================== View Functions ====================

/// Check if US investors must transfer full balance
public fun is_force_us(rule: &ForceFullTransfer): bool {
    rule.force_full_transfer_us
}

/// Check if all investors must transfer full balance
public fun is_force_worldwide(rule: &ForceFullTransfer): bool {
    rule.force_full_transfer_worldwide
}
