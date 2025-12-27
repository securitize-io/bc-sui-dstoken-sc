module securitize::ds_token;

use std::string::{String};
use securitize::{
    version::Version, 
    trust_service::{Auth, Master, Issuer, TransferAgent},
    registry_service::InvestorInfo,
    compliance_service::{Self, ComplianceConfig},
};
use sui::{
    coin::TreasuryCap, 
    coin_registry::{Currency, MetadataCap},
    clock::Clock, 
    dynamic_object_field as dof, 
    event, 
    derived_object
};
use rwa::vault::{RwaVault, RwaTransferRequest};
use rwa::rule::{Self, RwaRule};
use rwa::registry::RwaRegistry;

// ==== Error Codes ====

/// Error code when attempting to pause an already paused treasury
const ETreasuryAlreadyPaused: u64 = 0;
/// Error code when attempting to unpause a treasury that is not paused
const ETreasuryNotPaused: u64 = 1;
/// Error code when the caller is not authorized to perform the action
const ENotAuthorized: u64 = 2;
/// Error code when attempting transfer while token transfers are paused
const ETreasuryPaused: u64 = 3;
/// Error code when the vault owner does not match the expected address
const EVaultOwnerMismatch: u64 = 4;
/// Error code when the value to issue/transfer is zero
const EValueZero: u64 = 5;
/// Error code when the lengths of locked values and release times do not match
const EInvalidLengthOfParameters: u64 = 6;
/// Error code when the total locked value exceeds the issued value
const EValueLockedLargerThanValue: u64 = 7;
/// Error code when there is not enough balance to perform the operation
const ENotEnoughBalance: u64 = 9;

/// Witness struct for the Ds Protocol.
/// To be used inside the Permissioned Token Standard.
public struct DsProtocol() has drop;

public struct DsTokenKey<phantom T>() has copy, drop, store;

// ==== Structs ====

/// Treasury for managing a ds token.
public struct Treasury<phantom T> has key {
    id: UID,
    /// Capability to manage token metadata (name, description, icon)
    metadata_cap: MetadataCap<T>,
    paused: bool,
}

/// Key used to store the TreasuryCap<T> in the RwaRule<T>.
public struct TreasuryCapKey() has copy, drop, store;

// ==== Ds Token Abilities ====

public struct IssueTokens() has drop;

public struct BurnTokens() has drop;

public struct SeizeTokens() has drop;

public struct MetadataUpdate() has drop;

public struct Pauser() has drop;

// ==== Events ====

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
    is_paused: bool,
}

/// Initializes a new Treasury for the given token type T.
///
/// Called by the setup module during token deployment.
public(package) fun new<T: key>(
    uid: &mut UID,
    auth: &mut Auth<T>,
    rwa_registry: &mut RwaRegistry,
    treasury_cap: TreasuryCap<T>,
    metadata_cap: MetadataCap<T>,
    version: &Version,
    ctx: &TxContext,
): Treasury<T> {
    // Assign abilities to roles
    auth.add_role_ability<T, Master, IssueTokens>(version,ctx);
    auth.add_role_ability<T, Master, BurnTokens>(version,ctx);
    auth.add_role_ability<T, Master, SeizeTokens>(version,ctx);
    auth.add_role_ability<T, Master, MetadataUpdate>(version,ctx);
    auth.add_role_ability<T, Master, Pauser>(version,ctx);

    auth.add_role_ability<T, Issuer, IssueTokens>(version,ctx);
    auth.add_role_ability<T, Issuer, BurnTokens>(version,ctx);

    auth.add_role_ability<T, TransferAgent, BurnTokens>(version,ctx);
    auth.add_role_ability<T, TransferAgent, SeizeTokens>(version,ctx);
    auth.add_role_ability<T, TransferAgent, Pauser>(version,ctx);
    // Initialize the Treasury
    let mut treasury = Treasury {
        id: derived_object::claim(uid, DsTokenKey<T>()),
        metadata_cap,
        paused: false,
    };
    // Register the RwaRule
    let clawback_allowed = true;
    rule::new(rwa_registry, &treasury_cap, clawback_allowed, DsProtocol());
    dof::add(&mut treasury.id, TreasuryCapKey(), treasury_cap);
    treasury
}

/// Makes the Treasury a shared object for public access
#[lint_allow(share_owned)]
public(package) fun share<T>(treasury: Treasury<T>) {
    transfer::share_object(treasury);
}

// ==== Public Functions ====

/// Issues new tokens and deposits them into the specified vault.
/// Only authorized addresses with the IssueTokens ability can call this function.
///
/// # Aborts
/// * `ENotAuthorized` - If the sender does not have the IssueTokens ability
public fun issue_tokens<T>(
    treasury: &mut Treasury<T>,
    auth: &Auth<T>,
    investors: &mut InvestorInfo<T>,
    compliance_config: &mut ComplianceConfig<T>,
    rwa_rule: &RwaRule<T>,
    to: &mut RwaVault,
    to_address: address,
    value: u64,
    version: &Version,
    values_locked: vector<u64>,
    release_times: vector<u64>,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    version.check_is_valid();
    assert!(auth.owner_has_ability<T, IssueTokens>(ctx.sender()), ENotAuthorized);
    assert!(to.owner_address() == to_address, EVaultOwnerMismatch);
    assert!(value > 0, EValueZero);
    assert!(values_locked.length() == release_times.length(), EInvalidLengthOfParameters);
    let timestamp_ms = clock.timestamp_ms();
    let total_supply = dof::borrow<TreasuryCapKey, TreasuryCap<T>>(
        &treasury.id,
        TreasuryCapKey(),
    ).total_supply();
    compliance_service::validate_issue(
        compliance_config,
        investors,
        to_address,
        value,
        total_supply,
        timestamp_ms,
        version,
    );
    let balance = dof::borrow_mut<TreasuryCapKey, TreasuryCap<T>>(
        &mut treasury.id,
        TreasuryCapKey(),
    ).mint_balance(value);
    if (investors.is_wallet(to_address)) {
        let id = investors.get_investor_id_by_wallet(to_address);
        let total_balance = investors.investor_wallet_balance_total(id);
        investors.update_investor_total_balance(id, total_balance + value);
    };
    // Deposit to the investor's vault
    rule::deposit_to_vault(
        rwa_rule,
        to,
        balance,
        DsProtocol(),
    );
    let mut total_locked = 0;
    let mut i = 0;
    while (i < values_locked.length()) {
        total_locked = total_locked + values_locked[i];
        // lock_manager::add_manual_lock_record();
        i = i + 1;
    };
    assert!(total_locked <= value, EValueLockedLargerThanValue);
    event::emit(
        Issue<T> {
            to: to_address,
            value,
            value_locked: total_locked,
        }
    );
    event::emit(
        Transfer<T> {
            from: @0x0,
            to: to_address,
            value
        }
    );
}

/// Burns tokens from the specified vault, reducing the total supply.
/// Only authorized addresses with the BurnTokens ability can call this function.
///
/// # Aborts
/// * `ENotAuthorized` - If the sender does not have the BurnTokens ability
public fun burn<T>(
    treasury: &mut Treasury<T>,
    auth: &Auth<T>,
    investors: &mut InvestorInfo<T>,
    rwa_rule: &RwaRule<T>,
    from: &mut RwaVault,
    from_address: address,
    value: u64,
    reason: String,
    version: &Version,
    ctx: &mut TxContext,
) {
    version.check_is_valid();
    assert!(auth.owner_has_ability<T, BurnTokens>(ctx.sender()), ENotAuthorized);
    assert!(from.owner_address() == from_address, EVaultOwnerMismatch);
    assert!(from.balance<T>() >= value, ENotEnoughBalance);
    compliance_service::validate_burn(investors, from_address, value);
    let balance = rule::clawback(
        rwa_rule,
        from,
        value,
        DsProtocol(),
    );
    // Burn the balance
    dof::borrow_mut<TreasuryCapKey, TreasuryCap<T>>(
        &mut treasury.id,
        TreasuryCapKey(),
    ).burn(balance.into_coin(ctx));
    if (investors.is_wallet(from_address)) {
        let id = investors.get_investor_id_by_wallet(from_address);
        let total_balance = investors.investor_wallet_balance_total(id);
        investors.update_investor_total_balance(id, total_balance - value);
    };
    event::emit(
        Burn<T> {
            burner: from_address,
            value: value,
            reason: reason,
        }
    );
    event::emit(
        Transfer<T> {
            from: from_address,
            to: @0x0,
            value
        }
    );
}

/// Seizes tokens from one vault and transfers them to another vault.
/// Only authorized addresses with the SeizeTokens ability can call this function.
///
/// # Aborts
/// * `ENotAuthorized` - If the sender does not have the SeizeTokens ability
public fun seize<T>(
    auth: &Auth<T>,
    investors: &mut InvestorInfo<T>,
    rwa_rule: &RwaRule<T>,
    from: &mut RwaVault,
    from_address: address,
    to: &mut RwaVault,
    to_address: address,
    value: u64,
    reason: String,
    version: &Version,
    ctx: &mut TxContext,
) {
    version.check_is_valid();
    assert!(auth.owner_has_ability<T, SeizeTokens>(ctx.sender()), ENotAuthorized);
    assert!(from.owner_address() == from_address, EVaultOwnerMismatch);
    assert!(to.owner_address() == to_address, EVaultOwnerMismatch);
    assert!(from.balance<T>() >= value, ENotEnoughBalance);
    compliance_service::validate_seize(investors, from_address, to_address, value);
    // Withdraw from the investor's vault and deposit to the treasury's vault
    rule::clawback_to_vault(
        rwa_rule,
        from,
        to,
        value,
        DsProtocol(),
    );
    if (investors.is_wallet(to_address)) {
        let id = investors.get_investor_id_by_wallet(to_address);
        let total_balance = investors.investor_wallet_balance_total(id);
        investors.update_investor_total_balance(id, total_balance + value);
    };
    if (investors.is_wallet(from_address)) {
        let id = investors.get_investor_id_by_wallet(from_address);
        let total_balance = investors.investor_wallet_balance_total(id);
        investors.update_investor_total_balance(id, total_balance - value);
    };
    event::emit(
        Seize<T> {
            from: from_address,
            to: to_address,
            value,
            reason: reason,
        }
    );
    event::emit(
        Transfer<T> {
            from: from_address,
            to: to_address,
            value,
        }
    );
}

/// Processes a token transfer request between vaults.
/// The treasury must not be paused for the transfer to succeed.
///
/// # Aborts
/// * `ETreasuryPaused` - If the treasury is currently paused
public fun transfer<T>(
    treasury: &Treasury<T>,
    investors: &mut InvestorInfo<T>,
    compliance_config: &ComplianceConfig<T>,
    rwa_rule: &RwaRule<T>,
    request: RwaTransferRequest<T>,
    version: &Version,
    clock: &Clock
) {
    version.check_is_valid();
    let from_address = request.request_from_address();
    let to_address = request.request_to_address();
    let value = request.request_amount();
    assert!(value > 0, EValueZero);
    // If the treasury is paused, don't allow investor-to-investor transfers
    if (treasury.is_paused()) {
        assert!(!(investors.is_wallet(from_address) && investors.is_wallet(to_address)), ETreasuryPaused);
    };
    assert!(
        !(investors.is_wallet(from_address) && 
        investors.is_wallet(to_address) &&
        treasury.is_paused()), ETreasuryPaused
    );
    compliance_service::validate_transfer(
        compliance_config, 
        investors, 
        &request, 
        clock.timestamp_ms(), 
        version
    );
    if (investors.is_wallet(to_address)) {
        let id = investors.get_investor_id_by_wallet(to_address);
        let total_balance = investors.investor_wallet_balance_total(id);
        investors.update_investor_total_balance(id, total_balance + value);
    };
    if (investors.is_wallet(from_address)) {
        let id = investors.get_investor_id_by_wallet(from_address);
        let total_balance = investors.investor_wallet_balance_total(id);
        investors.update_investor_total_balance(id, total_balance - value);
    };
    // Resolve the request
    rule::resolve_transfer(rwa_rule, request, DsProtocol());
    event::emit(
        Transfer<T> {
            from: from_address,
            to: to_address,
            value,
        }
    );
}

/// Updates the token's metadata (name, description, and/or icon URL).
/// Only authorized addresses with the MetadataUpdate ability can call this function.
/// Each metadata field is optional - only provided values will be updated.
///
/// # Aborts
/// * `ENotAuthorized` - If the sender does not have the MetadataUpdate ability
public fun set_metadata<T>(
    treasury: &Treasury<T>,
    auth: &Auth<T>,
    currency: &mut Currency<T>,
    name: Option<String>,
    description: Option<String>,
    icon_url: Option<String>,
    version: &Version,
    ctx: &mut TxContext,
) {
    version.check_is_valid();
    assert!(auth.owner_has_ability<T, MetadataUpdate>(ctx.sender()), ENotAuthorized);
    let metadata_cap = &treasury.metadata_cap;
    name.do!(|n| {currency.set_name<T>(metadata_cap, n);});
    description.do!(|d| {currency.set_description<T>(metadata_cap, d);});
    icon_url.do!(|i| {currency.set_icon_url<T>(metadata_cap, i);});
}

/// Pauses the treasury, preventing token operations.
/// Only authorized addresses should be able to call this function.
///
/// # Aborts
/// * `ETreasuryAlreadyPaused` - If the treasury is already paused
public fun pause<T>(
    treasury: &mut Treasury<T>,
    auth: &Auth<T>,
    version: &Version,
    ctx: &mut TxContext,
) {
    version.check_is_valid();
    assert!(auth.owner_has_ability<T, Pauser>(ctx.sender()), ENotAuthorized);
    assert!(!treasury.is_paused(), ETreasuryAlreadyPaused);
    treasury.paused = true;
    event::emit( 
        Pause<T> {
            pauser: ctx.sender(),
            is_paused: true,
        } 
    );
}

/// Unpauses the treasury, allowing token operations to resume.
/// Only authorized addresses should be able to call this function.
///
/// # Aborts
/// * `ETreasuryNotPaused` - If the treasury is not currently paused
public fun unpause<T>(
    treasury: &mut Treasury<T>,
    auth: &Auth<T>,
    version: &Version,
    ctx: &mut TxContext,
) {
    version.check_is_valid();
    assert!(auth.owner_has_ability<T, Pauser>(ctx.sender()), ENotAuthorized);
    assert!(treasury.is_paused(), ETreasuryNotPaused);
    treasury.paused = false;
    event::emit( 
        Pause<T> {
            pauser: ctx.sender(),
            is_paused: false,
        } 
    );
}

// ==== View Functions ====

/// Returns whether the treasury is currently paused.
public fun is_paused<T>(treasury: &Treasury<T>): bool {
    treasury.paused
}
