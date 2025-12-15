/// Module: force_full_transfer
module securitize::force_full_transfer;

// ==== Error Codes ====

use securitize::version::Version;

const EPartialTransferNotAllowed: u64 = 0;

// ==== TEMP Compliance Region Constants ====

const US: u64 = 1;
const EU: u64 = 2;
const FORBIDDEN: u64 = 4;
const JP: u64 = 8;

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
public fun new(
    force_full_transfer_us: bool,
    force_full_transfer_worldwide: bool,
    version: &Version
): ForceFullTransfer {
    version.check_is_valid();
    ForceFullTransfer {
        force_full_transfer_us,
        force_full_transfer_worldwide,
    }
}

// ==================== Rule Management ====================

/// Set force full transfer for US investors
public fun set_force_us(rule: &mut ForceFullTransfer, force: bool, version: &Version) {
    version.check_is_valid();
    rule.force_full_transfer_us = force;
}

/// Set force full transfer worldwide
public fun set_force_worldwide(rule: &mut ForceFullTransfer, force: bool, version: &Version) {
    version.check_is_valid();
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
