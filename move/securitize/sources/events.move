/// Module: events
///
/// Centralized event definitions for the Securitize DS Token protocol.
/// Contains all event structs emitted across the protocol for tracking
/// token operations, investor management, compliance changes, and role assignments.
module securitize::events;

use std::{string::String, type_name::TypeName};
use sui::event;

// ============================================================================
// EVENT STRUCTS
// ============================================================================

// ==== Setup Events ====

public struct DeployerAdded has copy, drop {
    deployer: address,
}

public struct DeployerRemoved has copy, drop {
    deployer: address,
}

public struct AdminSwitched has copy, drop {
    old_admin: address,
    new_admin: address,
}

// ==== DS Token Events ====

public struct Issue<phantom T> has copy, drop {
    to: address,
    value: u64,
    value_locked: u64,
}

public struct Burn<phantom T> has copy, drop {
    burner: address,
    value: u64,
    reason: String,
}

public struct Seize<phantom T> has copy, drop {
    from: address,
    to: address,
    value: u64,
    reason: String,
}

public struct Transfer<phantom T> has copy, drop {
    from: address,
    to: address,
    value: u64,
}

public struct Pause<phantom T> has copy, drop {
    pauser: address,
}

public struct Unpause<phantom T> has copy, drop {
    pauser: address,
}

public struct NameUpdated<phantom T> has copy, drop {
    old_name: String,
    new_name: String,
}

public struct DescriptionUpdated<phantom T> has copy, drop {
    old_description: String,
    new_description: String,
}

public struct IconUriUpdated<phantom T> has copy, drop {
    old_icon_uri: String,
    new_icon_uri: String,
}

// ==== Trust Service Events ====

public struct DSTrustServiceRoleAdded<phantom T> has copy, drop {
    target_address: address,
    role: TypeName,
    sender: address,
}

public struct DSTrustServiceRoleRemoved<phantom T> has copy, drop {
    target_address: address,
    role: TypeName,
    sender: address,
}

// ==== Registry Service Events ====

public struct DSRegistryServiceInvestorAdded<phantom T> has copy, drop {
    investor_id: String,
    sender: address,
}

public struct DSRegistryServiceInvestorRemoved<phantom T> has copy, drop {
    investor_id: String,
    sender: address,
}

public struct DSRegistryServiceInvestorCountryChanged<phantom T> has copy, drop {
    investor_id: String,
    country: String,
    sender: address,
}

public struct DSRegistryServiceInvestorAttributeChanged<phantom T> has copy, drop {
    investor_id: String,
    attribute_id: u64,
    value: u64,
    expiry: u64,
    sender: address,
}

public struct DSRegistryServiceWalletAdded<phantom T> has copy, drop {
    wallet: address,
    investor_id: String,
    sender: address,
}

public struct DSRegistryServiceWalletRemoved<phantom T> has copy, drop {
    wallet: address,
    investor_id: String,
    sender: address,
}

// ==== Compliance Service Events ====

public struct DSComplianceRuleAdded<phantom T> has copy, drop {
    rule_type: TypeName,
}

public struct DSComplianceRuleRemoved<phantom T> has copy, drop {
    rule_type: TypeName,
}

public struct DSComplianceTransferRecorded<phantom T> has copy, drop {
    from: address,
    to: address,
    amount: u64,
}

public struct DSComplianceIssuanceRecorded<phantom T> has copy, drop {
    to: address,
    amount: u64,
}

public struct DSComplianceBurnRecorded<phantom T> has copy, drop {
    from: address,
    amount: u64,
}

public struct DSComplianceSeizeRecorded<phantom T> has copy, drop {
    from: address,
    amount: u64,
}

// ==== Lock Manager Events ====

public struct InvestorFullyLocked<phantom T> has copy, drop {
    investor_id: String,
}

public struct InvestorFullyUnlocked<phantom T> has copy, drop {
    investor_id: String,
}

public struct InvestorLiquidateOnlySet<phantom T> has copy, drop {
    investor_id: String,
    enabled: bool,
}

public struct HolderLocked<phantom T> has copy, drop {
    holder_id: String,
    value: u64,
    reason: u64,
    reason_string: String,
    release_time_ms: u64,
}

public struct HolderUnlocked<phantom T> has copy, drop {
    holder_id: String,
    value: u64,
    reason: u64,
    reason_string: String,
    release_time_ms: u64,
}

// ==== Wallet Manager Events ====

public struct DSWalletManagerSpecialWalletAdded<phantom T> has copy, drop {
    wallet: address,
    wallet_type: u64,
    caller: address,
}

public struct DSWalletManagerSpecialWalletRemoved<phantom T> has copy, drop {
    wallet: address,
    old_type: u64,
    caller: address,
}

// ==== Generic Compliance Rule Set Events ====

/// Generic event for setting u64 rule values
public struct DSComplianceUIntRuleSet<phantom T> has copy, drop {
    rule_name: String,
    prev_value: u64,
    new_value: u64,
}

/// Generic event for setting bool rule values
public struct DSComplianceBoolRuleSet<phantom T> has copy, drop {
    rule_name: String,
    prev_value: bool,
    new_value: bool,
}

/// Generic event for setting map-style rule values (e.g., region-specific settings)
public struct DSComplianceStringToUIntMapRuleSet<phantom T> has copy, drop {
    rule_name: String,
    key_value: String,
    prev_value: u64,
    new_value: u64,
}

// ============================================================================
// EMIT FUNCTIONS
// ============================================================================

// ==== Setup Emit Functions ====

public(package) fun emit_deployer_added_event(deployer: address) {
    event::emit(DeployerAdded { deployer });
}

public(package) fun emit_deployer_removed_event(deployer: address) {
    event::emit(DeployerRemoved { deployer });
}

public(package) fun emit_admin_switched_event(old_admin: address, new_admin: address) {
    event::emit(AdminSwitched { old_admin, new_admin });
}

// ==== DS Token Emit Functions ====

public(package) fun emit_issue_event<T>(to: address, value: u64, value_locked: u64) {
    event::emit(Issue<T> { to, value, value_locked });
}

public(package) fun emit_burn_event<T>(burner: address, value: u64, reason: String) {
    event::emit(Burn<T> { burner, value, reason });
}

public(package) fun emit_seize_event<T>(from: address, to: address, value: u64, reason: String) {
    event::emit(Seize<T> { from, to, value, reason });
}

public(package) fun emit_transfer_event<T>(from: address, to: address, value: u64) {
    event::emit(Transfer<T> { from, to, value });
}

public(package) fun emit_pause_event<T>(pauser: address) {
    event::emit(Pause<T> { pauser });
}

public(package) fun emit_unpause_event<T>(pauser: address) {
    event::emit(Unpause<T> { pauser });
}

public(package) fun emit_name_updated_event<T>(old_name: String, new_name: String) {
    event::emit(NameUpdated<T> { old_name, new_name });
}

public(package) fun emit_description_updated_event<T>(old_description: String, new_description: String) {
    event::emit(DescriptionUpdated<T> { old_description, new_description });
}

public(package) fun emit_icon_uri_updated_event<T>(old_icon_uri: String, new_icon_uri: String) {
    event::emit(IconUriUpdated<T> { old_icon_uri, new_icon_uri });
}

// ==== Trust Service Emit Functions ====

public(package) fun emit_role_added_event<T>(
    target_address: address,
    role: TypeName,
    sender: address,
) {
    event::emit(DSTrustServiceRoleAdded<T> { target_address, role, sender });
}

public(package) fun emit_role_removed_event<T>(
    target_address: address,
    role: TypeName,
    sender: address,
) {
    event::emit(DSTrustServiceRoleRemoved<T> { target_address, role, sender });
}

// ==== Registry Service Emit Functions ====

public(package) fun emit_investor_added_event<T>(investor_id: String, sender: address) {
    event::emit(DSRegistryServiceInvestorAdded<T> { investor_id, sender });
}

public(package) fun emit_investor_removed_event<T>(investor_id: String, sender: address) {
    event::emit(DSRegistryServiceInvestorRemoved<T> { investor_id, sender });
}

public(package) fun emit_investor_country_changed_event<T>(
    investor_id: String,
    country: String,
    sender: address,
) {
    event::emit(DSRegistryServiceInvestorCountryChanged<T> { investor_id, country, sender });
}

public(package) fun emit_investor_attribute_changed_event<T>(
    investor_id: String,
    attribute_id: u64,
    value: u64,
    expiry: u64,
    sender: address,
) {
    event::emit(DSRegistryServiceInvestorAttributeChanged<T> {
        investor_id,
        attribute_id,
        value,
        expiry,
        sender,
    });
}

public(package) fun emit_wallet_added_event<T>(
    wallet: address,
    investor_id: String,
    sender: address,
) {
    event::emit(DSRegistryServiceWalletAdded<T> { wallet, investor_id, sender });
}

public(package) fun emit_wallet_removed_event<T>(
    wallet: address,
    investor_id: String,
    sender: address,
) {
    event::emit(DSRegistryServiceWalletRemoved<T> { wallet, investor_id, sender });
}

// ==== Compliance Service Emit Functions ====

public(package) fun emit_compliance_rule_added_event<T>(rule_type: TypeName) {
    event::emit(DSComplianceRuleAdded<T> { rule_type });
}

public(package) fun emit_compliance_rule_removed_event<T>(rule_type: TypeName) {
    event::emit(DSComplianceRuleRemoved<T> { rule_type });
}

public(package) fun emit_compliance_transfer_recorded_event<T>(
    from: address,
    to: address,
    amount: u64,
) {
    event::emit(DSComplianceTransferRecorded<T> { from, to, amount });
}

public(package) fun emit_compliance_issuance_recorded_event<T>(to: address, amount: u64) {
    event::emit(DSComplianceIssuanceRecorded<T> { to, amount });
}

public(package) fun emit_compliance_burn_recorded_event<T>(from: address, amount: u64) {
    event::emit(DSComplianceBurnRecorded<T> { from, amount });
}

public(package) fun emit_compliance_seize_recorded_event<T>(from: address, amount: u64) {
    event::emit(DSComplianceSeizeRecorded<T> { from, amount });
}

// ==== Lock Manager Emit Functions ====

public(package) fun emit_investor_fully_locked_event<T>(investor_id: String) {
    event::emit(InvestorFullyLocked<T> { investor_id });
}

public(package) fun emit_investor_fully_unlocked_event<T>(investor_id: String) {
    event::emit(InvestorFullyUnlocked<T> { investor_id });
}

public(package) fun emit_liquidate_only_set_event<T>(investor_id: String, enabled: bool) {
    event::emit(InvestorLiquidateOnlySet<T> { investor_id, enabled });
}

public(package) fun emit_lock_added_event<T>(
    holder_id: String,
    value: u64,
    reason: u64,
    reason_string: String,
    release_time_ms: u64,
) {
    event::emit(HolderLocked<T> { holder_id, value, reason, reason_string, release_time_ms });
}

public(package) fun emit_lock_removed_event<T>(
    holder_id: String,
    value: u64,
    reason: u64,
    reason_string: String,
    release_time_ms: u64,
) {
    event::emit(HolderUnlocked<T> { holder_id, value, reason, reason_string, release_time_ms });
}

// ==== Wallet Manager Emit Functions ====

public(package) fun emit_special_wallet_added_event<T>(
    wallet: address,
    wallet_type: u64,
    caller: address,
) {
    event::emit(DSWalletManagerSpecialWalletAdded<T> { wallet, wallet_type, caller });
}

public(package) fun emit_special_wallet_removed_event<T>(
    wallet: address,
    old_type: u64,
    caller: address,
) {
    event::emit(DSWalletManagerSpecialWalletRemoved<T> { wallet, old_type, caller });
}

// ==== Generic Compliance Rule Set Emit Functions ====

public(package) fun emit_uint_rule_set_event<T>(
    rule_name: String,
    prev_value: u64,
    new_value: u64,
) {
    event::emit(DSComplianceUIntRuleSet<T> { rule_name, prev_value, new_value });
}

public(package) fun emit_bool_rule_set_event<T>(
    rule_name: String,
    prev_value: bool,
    new_value: bool,
) {
    event::emit(DSComplianceBoolRuleSet<T> { rule_name, prev_value, new_value });
}

public(package) fun emit_string_to_uint_map_rule_set_event<T>(
    rule_name: String,
    key_value: String,
    prev_value: u64,
    new_value: u64,
) {
    event::emit(DSComplianceStringToUIntMapRuleSet<T> {
        rule_name,
        key_value,
        prev_value,
        new_value,
    });
}