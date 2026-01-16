/// Module: ds_token
///
/// The main security token module that implements the DS Token standard.
/// Provides treasury management, token issuance, burning, seizing, and transfers
/// with integrated compliance validation through the compliance service.
module securitize::ds_token;

use pas::{
    namespace::Namespace,
    rule::{Self, Rule},
    transfer_funds_request::TransferFundsRequest,
    vault::Vault
};
use securitize::{
    abilities::{IssueTokens, MetadataUpdate, BurnTokens, SeizeTokens, Pauser},
    compliance_service::{Self, ComplianceConfig},
    events::{
        emit_issue_event,
        emit_burn_event,
        emit_seize_event,
        emit_transfer_event,
        emit_pause_event,
        emit_unpause_event
    },
    registry_service::InvestorInfo,
    trust_service::{Auth, Master, Issuer, TransferAgent},
    version::Version
};
use std::string::String;
use sui::{
    clock::Clock,
    coin::TreasuryCap,
    coin_registry::{Currency, MetadataCap},
    derived_object,
    dynamic_object_field as dof
};

// ==== Error Codes ====

#[error(code = 0)]
const ETreasuryAlreadyPaused: vector<u8> = b"Treasury is already paused";
#[error(code = 1)]
const ETreasuryNotPaused: vector<u8> = b"Treasury is not paused";
#[error(code = 2)]
const ENotAuthorized: vector<u8> = b"Caller is not authorized to perform this action";
#[error(code = 3)]
const ETreasuryPaused: vector<u8> = b"Token transfers are paused";
#[error(code = 4)]
const EVaultOwnerMismatch: vector<u8> = b"Vault owner does not match the expected address";
#[error(code = 5)]
const EValueZero: vector<u8> = b"Value to issue or transfer cannot be zero";
#[error(code = 6)]
const EInvalidLengthOfParameters: vector<u8> = b"Locked values and release times arrays must have the same length";
#[error(code = 7)]
const EValueLockedLargerThanValue: vector<u8> = b"Total locked value exceeds the issued value";
#[error(code = 9)]
const ENotEnoughBalance: vector<u8> = b"Not enough balance to perform the operation";
#[error(code = 10)]
const EArithmeticOverflow: vector<u8> = b"Arithmetic overflow occurred";

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

/// Initializes a new Treasury for the given token type T.
///
/// Called by the setup module during token deployment.
public(package) fun new<T: key>(
    uid: &mut UID,
    auth: &mut Auth<T>,
    namespace: &mut Namespace,
    treasury_cap: TreasuryCap<T>,
    metadata_cap: MetadataCap<T>,
    version: &Version,
    ctx: &TxContext,
): Treasury<T> {
    // Assign abilities to roles
    auth.add_role_ability<T, Master, IssueTokens>(version, ctx);
    auth.add_role_ability<T, Master, BurnTokens>(version, ctx);
    auth.add_role_ability<T, Master, SeizeTokens>(version, ctx);
    auth.add_role_ability<T, Master, MetadataUpdate>(version, ctx);
    auth.add_role_ability<T, Master, Pauser>(version, ctx);

    auth.add_role_ability<T, Issuer, IssueTokens>(version, ctx);
    auth.add_role_ability<T, Issuer, BurnTokens>(version, ctx);

    auth.add_role_ability<T, TransferAgent, BurnTokens>(version, ctx);
    auth.add_role_ability<T, TransferAgent, SeizeTokens>(version, ctx);
    auth.add_role_ability<T, TransferAgent, Pauser>(version, ctx);
    // Initialize the Treasury
    let mut treasury = Treasury {
        id: derived_object::claim(uid, DsTokenKey<T>()),
        metadata_cap,
        paused: false,
    };
    // Register the RwaRule
    let clawback_allowed = true;
    rule::new(namespace, &treasury_cap, clawback_allowed, DsProtocol());
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
/// * `EVaultOwnerMismatch` - If the vault owner does not match to_address
public fun issue_tokens<T>(
    treasury: &mut Treasury<T>,
    auth: &Auth<T>,
    investors: &mut InvestorInfo<T>,
    compliance_config: &mut ComplianceConfig<T>,
    rule: &Rule<T>,
    to: &Vault,
    to_address: address,
    value: u64,
    version: &Version,
    values_locked: vector<u64>,
    release_times: vector<u64>,
    issuance_time_ms: u64,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    version.check_is_valid();
    assert!(auth.owner_has_ability<T, IssueTokens>(ctx.sender()), ENotAuthorized);
    assert!(to.owner() == to_address, EVaultOwnerMismatch);
    let treasury_cap = dof::borrow_mut<TreasuryCapKey, TreasuryCap<T>>(
        &mut treasury.id,
        TreasuryCapKey(),
    );
    let total_supply = treasury_cap.total_supply();
    issue_tokens_internal(
        investors,
        compliance_config,
        to_address,
        value,
        total_supply,
        version,
        values_locked,
        release_times,
        issuance_time_ms,
        clock,
    );
    let balance = treasury_cap.mint_balance(value);
    // Deposit to the investor's vault
    rule.deposit(
        to,
        balance,
        DsProtocol(),
    );
}

/// Issues new tokens and deposits them to the vault derived by the provided address.
/// Meant to be used in combination with the investor registration when investors' vault is not yet created.
/// Only authorized addresses with the IssueTokens ability can call this function.
///
/// # Aborts
/// * `ENotAuthorized` - If the sender does not have the IssueTokens ability
public fun issue_tokens_no_vault<T>(
    treasury: &mut Treasury<T>,
    auth: &Auth<T>,
    investors: &mut InvestorInfo<T>,
    compliance_config: &mut ComplianceConfig<T>,
    rule: &Rule<T>,
    namespace: &Namespace,
    to: address,
    value: u64,
    version: &Version,
    values_locked: vector<u64>,
    release_times: vector<u64>,
    issuance_time_ms: u64,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    version.check_is_valid();
    assert!(auth.owner_has_ability<T, IssueTokens>(ctx.sender()), ENotAuthorized);
    let treasury_cap = dof::borrow_mut<TreasuryCapKey, TreasuryCap<T>>(
        &mut treasury.id,
        TreasuryCapKey(),
    );
    let total_supply = treasury_cap.total_supply();
    issue_tokens_internal(
        investors,
        compliance_config,
        to,
        value,
        total_supply,
        version,
        values_locked,
        release_times,
        issuance_time_ms,
        clock,
    );
    let balance = treasury_cap.mint_balance(value);
    // Deposit to the investor's vault
    rule.unsafe_deposit(
        namespace,
        balance,
        to,
        DsProtocol(),
        ctx,
    );
}

fun issue_tokens_internal<T>(
    investors: &mut InvestorInfo<T>,
    compliance_config: &ComplianceConfig<T>,
    to: address,
    value: u64,
    total_supply: u64,
    version: &Version,
    values_locked: vector<u64>,
    release_times: vector<u64>,
    issuance_time_ms: u64,
    clock: &Clock,
) {
    assert!(value > 0, EValueZero);
    assert!(values_locked.length() == release_times.length(), EInvalidLengthOfParameters);
    let current_time_ms = clock.timestamp_ms();
    compliance_service::validate_issue(
        compliance_config,
        investors,
        to,
        value,
        total_supply,
        issuance_time_ms,
        current_time_ms,
        version,
    );
    if (investors.is_wallet(to)) {
        let id = investors.get_investor_id_by_wallet(to);
        let total_balance = investors.investor_wallet_balance_total(id);
        let new_total_u256 = (total_balance as u256) + (value as u256);
        let new_total = try_from_u256_to_u64(new_total_u256);
        investors.update_investor_total_balance(id, new_total);
    };
    let mut total_locked = 0;
    let mut i = 0;
    while (i < values_locked.length()) {
        total_locked = total_locked + values_locked[i];
        // lock_manager::add_manual_lock_record();
        i = i + 1;
    };
    assert!(total_locked <= value, EValueLockedLargerThanValue);
    emit_issue_event<T>(to, value, total_locked);
    emit_transfer_event<T>(@0x0, to, value);
}

/// Burns tokens from the specified vault, reducing the total supply.
/// Only authorized addresses with the BurnTokens ability can call this function.
///
/// # Aborts
/// * `ENotAuthorized` - If the sender does not have the BurnTokens ability
/// * `EVaultOwnerMismatch` - If the vault owner does not match from_address
public fun burn<T>(
    treasury: &mut Treasury<T>,
    auth: &Auth<T>,
    investors: &mut InvestorInfo<T>,
    rule: &Rule<T>,
    from: &mut Vault,
    from_address: address,
    value: u64,
    reason: String,
    version: &Version,
    ctx: &mut TxContext,
) {
    version.check_is_valid();
    assert!(auth.owner_has_ability<T, BurnTokens>(ctx.sender()), ENotAuthorized);
    assert!(from.owner() == from_address, EVaultOwnerMismatch);

    // TODO: Bring back once we have object balance reads.
    // assert!(from.balance<T>() >= value, ENotEnoughBalance);
    compliance_service::validate_burn(investors, from_address, value);
    let balance = rule.unsafe_clawback(
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
        assert!(total_balance >= value, ENotEnoughBalance);
        investors.update_investor_total_balance(id, ((total_balance as u128) - (value as u128)) as u64);
    };
    emit_burn_event<T>(from_address, value, reason);
    emit_transfer_event<T>(from_address, @0x0, value);
}

/// Seizes tokens from one vault and transfers them to another vault.
/// Only authorized addresses with the SeizeTokens ability can call this function.
///
/// # Aborts
/// * `ENotAuthorized` - If the sender does not have the SeizeTokens ability
/// * `EVaultOwnerMismatch` - If the vault owner does not match the expected address
public fun seize<T>(
    auth: &Auth<T>,
    investors: &mut InvestorInfo<T>,
    rule: &Rule<T>,
    from: &mut Vault,
    from_address: address,
    to: &Vault,
    to_address: address,
    value: u64,
    reason: String,
    version: &Version,
    ctx: &mut TxContext,
) {
    version.check_is_valid();
    assert!(auth.owner_has_ability<T, SeizeTokens>(ctx.sender()), ENotAuthorized);
    assert!(from.owner() == from_address, EVaultOwnerMismatch);
    assert!(to.owner() == to_address, EVaultOwnerMismatch);

    // TODO: Bring back once we have object balance reads.
    // assert!(from.balance<T>() >= value, ENotEnoughBalance);
    compliance_service::validate_seize(investors, from_address, to_address, value);
    // Withdraw from the investor's vault and deposit to the treasury's vault
    rule.clawback(
        from,
        to,
        value,
        DsProtocol(),
    );
    if (investors.is_wallet(to_address)) {
        let id = investors.get_investor_id_by_wallet(to_address);
        let total_balance = investors.investor_wallet_balance_total(id);
        let new_total_u256 = (total_balance as u256) + (value as u256);
        let new_total = try_from_u256_to_u64(new_total_u256);
        investors.update_investor_total_balance(id, new_total);
    };
    if (investors.is_wallet(from_address)) {
        let id = investors.get_investor_id_by_wallet(from_address);
        let total_balance = investors.investor_wallet_balance_total(id);
        assert!(total_balance >= value, ENotEnoughBalance);
        investors.update_investor_total_balance(id, (total_balance - value));
    };
    emit_seize_event<T>(from_address, to_address, value, reason);
    emit_transfer_event<T>(from_address, to_address, value);
}

/// Processes a token transfer request between vaults.
/// The treasury must not be paused for the transfer to succeed.
///
/// # Aborts
/// * `EValueZero` - If the transfer value is zero
/// * `ETreasuryPaused` - If the treasury is paused and both parties are investors
public fun transfer<T>(
    treasury: &Treasury<T>,
    investors: &mut InvestorInfo<T>,
    compliance_config: &ComplianceConfig<T>,
    rule: &Rule<T>,
    request: TransferFundsRequest<T>,
    version: &Version,
    clock: &Clock,
) {
    version.check_is_valid();
    let from_address = request.from();
    let to_address = request.to();
    let value = request.amount();
    assert!(value > 0, EValueZero);
    // If the treasury is paused, don't allow investor-to-investor transfers
    assert!(
        !(
            investors.is_wallet(from_address) && 
        investors.is_wallet(to_address) &&
        treasury.is_paused(),
        ),
        ETreasuryPaused,
    );
    compliance_service::validate_transfer(
        compliance_config,
        investors,
        &request,
        clock.timestamp_ms(),
        version,
    );
    if (investors.is_wallet(to_address)) {
        let id = investors.get_investor_id_by_wallet(to_address);
        let total_balance = investors.investor_wallet_balance_total(id);
        let new_total_u256 = (total_balance as u256) + (value as u256);
        let new_total = try_from_u256_to_u64(new_total_u256);
        investors.update_investor_total_balance(id, new_total);
    };
    if (investors.is_wallet(from_address)) {
        let id = investors.get_investor_id_by_wallet(from_address);
        let total_balance = investors.investor_wallet_balance_total(id);
        assert!(total_balance >= value, ENotEnoughBalance);
        investors.update_investor_total_balance(id, ((total_balance as u128) - (value as u128)) as u64);
    };
    // Resolve the request
    rule.resolve_transfer(request, DsProtocol());
    emit_transfer_event<T>(from_address, to_address, value);
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
    name.do!(|n| { currency.set_name<T>(metadata_cap, n); });
    description.do!(|d| { currency.set_description<T>(metadata_cap, d); });
    icon_url.do!(|i| { currency.set_icon_url<T>(metadata_cap, i); });
}

/// Pauses the treasury, preventing token operations.
/// Only authorized addresses should be able to call this function.
///
/// # Aborts
/// * `ENotAuthorized` - If the sender does not have the Pauser ability
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
    emit_pause_event<T>(ctx.sender());
}

/// Unpauses the treasury, allowing token operations to resume.
/// Only authorized addresses should be able to call this function.
///
/// # Aborts
/// * `ENotAuthorized` - If the sender does not have the Pauser ability
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
    emit_unpause_event<T>(ctx.sender());
}

// ==== View Functions ====

/// Returns whether the treasury is currently paused.
public fun is_paused<T>(treasury: &Treasury<T>): bool {
    treasury.paused
}

// ==== Helpers ====

// Try to safely convert u256 to u64
public(package) fun try_from_u256_to_u64(number: u256): u64 {
    let mut number_option = std::u256::try_as_u64(number);
    assert!(number_option.is_some(), EArithmeticOverflow);
    number_option.extract()
}
