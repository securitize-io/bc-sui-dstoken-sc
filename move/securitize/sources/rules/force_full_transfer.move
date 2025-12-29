/// Module: force_full_transfer
module securitize::force_full_transfer;

use securitize::version::Version;
use securitize::trust_service::Auth;
use std::string::String;
use sui::event;

const EPartialTransferNotAllowed: u64 = 0;

// ==== TEMP Compliance Region Constants ====

const US: u64 = 1;

// ==== Abilities ====

public struct ManageForceFullTransfer() has drop;

// ==== Events ====

public struct DSComplianceForceFullTransferRuleCreated<phantom T> has copy, drop {
    force_full_transfer_us: bool,
    force_full_transfer_worldwide: bool,
}

public struct DSComplianceForceFullTransferRuleSet<phantom T, V: copy + drop> has copy, drop {
    field: String,
    old_value: V,
    new_value: V,
}

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
public fun new<T>(
    auth: &Auth<T>,
    force_full_transfer_us: bool,
    force_full_transfer_worldwide: bool,
    version: &Version,
    ctx: &TxContext,
): ForceFullTransfer {
    version.check_is_valid();
    auth.owner_has_ability<T, ManageForceFullTransfer>(ctx.sender());
    event::emit(DSComplianceForceFullTransferRuleCreated<T> {
        force_full_transfer_us,
        force_full_transfer_worldwide,
    });
    ForceFullTransfer {
        force_full_transfer_us,
        force_full_transfer_worldwide,
    }
}

// ==================== Rule Management ====================

/// Set force full transfer for US investors
public fun set_force_us<T>(
    auth: &Auth<T>,
    rule: &mut ForceFullTransfer,
    force: bool,
    version: &Version,
    ctx: &TxContext,
) {
    version.check_is_valid();
    auth.owner_has_ability<T, ManageForceFullTransfer>(ctx.sender());
    event::emit(DSComplianceForceFullTransferRuleSet<T, bool> {
        field: b"force_full_transfer_us".to_string(),
        old_value: rule.force_full_transfer_us,
        new_value: force,
    });
    rule.force_full_transfer_us = force;
}

/// Set force full transfer worldwide
public fun set_force_worldwide<T>(
    auth: &Auth<T>,
    rule: &mut ForceFullTransfer,
    force: bool,
    version: &Version,
    ctx: &TxContext,
) {
    version.check_is_valid();
    auth.owner_has_ability<T, ManageForceFullTransfer>(ctx.sender());
    event::emit(DSComplianceForceFullTransferRuleSet<T, bool> {
        field: b"force_full_transfer_worldwide".to_string(),
        old_value: rule.force_full_transfer_worldwide,
        new_value: force,
    });
    rule.force_full_transfer_worldwide = force;
}

// ==================== Validation ====================

/// Validate that transfer complies with force full transfer rules
public fun validate_rule(rule: &ForceFullTransfer, from_region: u64, from_is_exit_investor: bool) {
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
