/// Module: ds_token
///
/// The main security token module that implements the DS Token standard.
/// Provides treasury management, token issuance, burning, seizing, and transfers
/// with integrated compliance validation through the compliance service.
module securitize::ds_token;

use pas::{
    account::Account,
    clawback_funds::ClawbackFunds,
    keys::{send_funds_action, clawback_funds_action},
    namespace::Namespace,
    policy::{Self, Policy, PolicyCap},
    request::Request,
    send_funds::SendFunds,
    templates::Templates
};
use ptb::ptb::Command;
use securitize::{
    abilities::{
        IssueTokens,
        MetadataUpdate,
        BurnTokens,
        SeizeTokens,
        SetTemplateCommand,
        AccessPolicyCap,
        Pauser
    },
    compliance_service::{Self, ComplianceConfig},
    events::{
        emit_issue_event,
        emit_burn_event,
        emit_seize_event,
        emit_transfer_event,
        emit_pause_event,
        emit_unpause_event,
        emit_name_updated_event,
        emit_description_updated_event,
        emit_icon_uri_updated_event
    },
    lock_manager,
    registry_service::InvestorInfo,
    trust_service::{Auth, Master, Issuer, TransferAgent},
    version::Version
};
use std::string::String;
use sui::{
    balance::Balance,
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
const EAccountOwnerMismatch: vector<u8> = b"Account owner does not match the expected address";
#[error(code = 5)]
const EValueZero: vector<u8> = b"Value to issue or transfer cannot be zero";
#[error(code = 6)]
const EInvalidLengthOfParameters: vector<u8> =
    b"Locked values and release times arrays must have the same length";
#[error(code = 7)]
const EValueLockedLargerThanValue: vector<u8> = b"Total locked value exceeds the issued value";
#[error(code = 9)]
const ENotEnoughBalance: vector<u8> = b"Not enough balance to perform the operation";
#[error(code = 10)]
const EArithmeticOverflow: vector<u8> = b"Arithmetic overflow occurred";

/// Witness struct for the Transfer Approve Action.
/// To be used inside the Permissioned Token Standard.
public struct TransferApproval<phantom T>() has drop;
/// Witness struct for the Clawback Approve Action.
/// To be used inside the Permissioned Token Standard.
public struct ClawbackApproval<phantom T>() has drop;

public struct DsTokenKey<phantom T>() has copy, drop, store;

// ==== Structs ====

/// Treasury for managing a ds token.
public struct Treasury<phantom T> has key {
    id: UID,
    /// Capability to manage token metadata (name, description, icon)
    metadata_cap: MetadataCap<T>,
    paused: bool,
}

/// Key used to store the TreasuryCap<T> in the Treasury<T>.
public struct TreasuryCapKey() has copy, drop, store;

/// Key used to store the PolicyCap<T> in the Treasury<T>.
public struct PolicyCapKey() has copy, drop, store;

/// Initializes a new Treasury for the given token type T.
///
/// Called by the setup module during token deployment.
public(package) fun new<T: key>(
    uid: &mut UID,
    auth: &mut Auth<T>,
    namespace: &mut Namespace,
    mut treasury_cap: TreasuryCap<T>,
    metadata_cap: MetadataCap<T>,
    version: &Version,
    ctx: &TxContext,
): Treasury<T> {
    // Assign abilities to roles
    auth.add_role_ability<T, Master, IssueTokens>(version, ctx);
    auth.add_role_ability<T, Master, BurnTokens>(version, ctx);
    auth.add_role_ability<T, Master, SeizeTokens>(version, ctx);
    auth.add_role_ability<T, Master, MetadataUpdate>(version, ctx);
    auth.add_role_ability<T, Master, SetTemplateCommand>(version, ctx);
    auth.add_role_ability<T, Master, AccessPolicyCap>(version, ctx);
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
    // Register PAS policy
    let clawback = true;
    let (mut policy, policy_cap) = policy::new_for_currency(namespace, &mut treasury_cap, clawback);
    policy.set_required_approval<_, TransferApproval<T>>(&policy_cap, send_funds_action());
    policy.set_required_approval<_, ClawbackApproval<T>>(&policy_cap, clawback_funds_action());
    policy.share();
    dof::add(&mut treasury.id, TreasuryCapKey(), treasury_cap);
    dof::add(&mut treasury.id, PolicyCapKey(), policy_cap);
    treasury
}

/// Makes the Treasury a shared object for public access
public(package) fun share<T>(treasury: Treasury<T>) {
    transfer::share_object(treasury);
}

// ==== Public Functions ====

/// Issues new tokens and deposits them into the specified account.
/// Only authorized addresses with the IssueTokens ability can call this function.
///
/// # Aborts
/// * `ENotAuthorized` - If the sender does not have the IssueTokens ability
/// * `EAccountOwnerMismatch` - If the account owner does not match to_address
public fun issue_tokens<T>(
    treasury: &mut Treasury<T>,
    auth: &Auth<T>,
    investors: &mut InvestorInfo<T>,
    compliance_config: &mut ComplianceConfig<T>,
    to: &Account,
    to_address: address,
    value: u64,
    reason_code: u64,
    reason_string: String,
    version: &Version,
    values_locked: vector<u64>,
    release_times: vector<u64>,
    issuance_time_ms: u64,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    version.check_is_valid();
    assert!(auth.owner_has_ability<T, IssueTokens>(ctx.sender()), ENotAuthorized);
    assert!(to.owner() == to_address, EAccountOwnerMismatch);
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
        reason_code,
        reason_string,
        version,
        values_locked,
        release_times,
        issuance_time_ms,
        clock,
    );
    let balance = treasury_cap.mint_balance(value);
    // Deposit to the investor's account
    to.deposit_balance(
        balance,
    );
}

/// Issues new tokens and deposits them to the account derived by the provided address.
/// Meant to be used in combination with the investor registration when investors' account is not yet created.
/// Only authorized addresses with the IssueTokens ability can call this function.
///
/// # Aborts
/// * `ENotAuthorized` - If the sender does not have the IssueTokens ability
public fun issue_tokens_no_account<T>(
    treasury: &mut Treasury<T>,
    auth: &Auth<T>,
    investors: &mut InvestorInfo<T>,
    compliance_config: &mut ComplianceConfig<T>,
    namespace: &Namespace,
    to: address,
    value: u64,
    reason_code: u64,
    reason_string: String,
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
        reason_code,
        reason_string,
        version,
        values_locked,
        release_times,
        issuance_time_ms,
        clock,
    );
    let balance = treasury_cap.mint_balance(value);
    balance.send_funds(namespace.account_address(to));
}

fun issue_tokens_internal<T>(
    investors: &mut InvestorInfo<T>,
    compliance_config: &ComplianceConfig<T>,
    to: address,
    value: u64,
    total_supply: u64,
    reason_code: u64,
    reason_string: String,
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
    let mut total_locked = 0;
    if (investors.is_wallet(to)) {
        let id = investors.get_investor_id_by_wallet(to);
        let total_balance = investors.investor_wallet_balance_total(id);
        investors.update_investor_total_balance(
            id,
            try_from_u256_to_u64!((total_balance as u256) + (value as u256)),
        );

        let wallet_balance = investors.investor_wallet_balance(to);
        investors.update_wallet_balance(
            to,
            try_from_u256_to_u64!((wallet_balance as u256) + (value as u256)),
        );

        let mut i = 0;
        while (i < values_locked.length()) {
            let value_locked = values_locked[i];
            total_locked = try_from_u256_to_u64!((total_locked as u256) + (value_locked as u256));
            lock_manager::add_lock_internal<T>(
                investors,
                id,
                value_locked,
                reason_code, // reason_code
                reason_string,
                release_times[i],
                current_time_ms,
            );
            i = i + 1;
        };
    } else if (investors.is_special_wallet(to)) {
        let wallet_balance = investors.special_wallet_balance(to);
        investors.update_special_wallet_total_balance(
            to,
            try_from_u256_to_u64!((wallet_balance as u256) + (value as u256)),
        );
    };
    assert!(total_locked <= value, EValueLockedLargerThanValue);
    emit_issue_event<T>(to, value, total_locked);
    emit_transfer_event<T>(@0x0, to, value);
}

/// Burns tokens from the specified account, reducing the total supply.
/// Only authorized addresses with the BurnTokens ability can call this function.
///
/// # Aborts
/// * `ENotAuthorized` - If the sender does not have the BurnTokens ability
/// * `EAccountOwnerMismatch` - If the account owner does not match from_address
public fun burn<T>(
    treasury: &mut Treasury<T>,
    auth: &Auth<T>,
    investors: &mut InvestorInfo<T>,
    policy: &Policy<Balance<T>>,
    mut request: Request<ClawbackFunds<Balance<T>>>,
    reason: String,
    version: &Version,
    ctx: &mut TxContext,
) {
    version.check_is_valid();

    let from_address = request.data().owner();
    let value = request.data().funds().value();

    assert!(auth.owner_has_ability<T, BurnTokens>(ctx.sender()), ENotAuthorized);
    compliance_service::validate_burn(investors, from_address, value);
    request.approve(ClawbackApproval<T>());
    let balance = pas::clawback_funds::resolve(request, policy);
    // Burn the balance
    dof::borrow_mut<TreasuryCapKey, TreasuryCap<T>>(
        &mut treasury.id,
        TreasuryCapKey(),
    ).burn(balance.into_coin(ctx));
    if (investors.is_wallet(from_address)) {
        let id = investors.get_investor_id_by_wallet(from_address);
        let total_balance = investors.investor_wallet_balance_total(id);
        assert!(total_balance >= value, ENotEnoughBalance);
        investors.update_investor_total_balance(
            id,
            total_balance - value,
        );
        let wallet_balance = investors.investor_wallet_balance(from_address);
        assert!(wallet_balance >= value, ENotEnoughBalance);
        investors.update_wallet_balance(
            from_address,
            wallet_balance - value,
        );
    } else if (investors.is_special_wallet(from_address)) {
        let wallet_balance = investors.special_wallet_balance(from_address);
        assert!(wallet_balance >= value, ENotEnoughBalance);
        investors.update_special_wallet_total_balance(
            from_address,
            wallet_balance - value,
        );
    };
    emit_burn_event<T>(from_address, value, reason);
    emit_transfer_event<T>(from_address, @0x0, value);
}

/// Seizes tokens from one account and transfers them to another account.
/// Only authorized addresses with the SeizeTokens ability can call this function.
///
/// # Aborts
/// * `ENotAuthorized` - If the sender does not have the SeizeTokens ability
/// * `EAccountOwnerMismatch` - If the account owner does not match the expected address
public fun seize<T>(
    auth: &Auth<T>,
    investors: &mut InvestorInfo<T>,
    policy: &Policy<Balance<T>>,
    mut request: Request<ClawbackFunds<Balance<T>>>,
    to: &Account,
    to_address: address,
    reason: String,
    version: &Version,
    ctx: &mut TxContext,
) {
    version.check_is_valid();

    let from_address = request.data().owner();
    let value = request.data().funds().value();

    assert!(auth.owner_has_ability<T, SeizeTokens>(ctx.sender()), ENotAuthorized);
    assert!(to.owner() == to_address, EAccountOwnerMismatch);

    compliance_service::validate_seize(investors, from_address, to_address, value);
    // Withdraw from the investor's account and deposit to the treasury's account
    request.approve(ClawbackApproval<T>());
    let balance = pas::clawback_funds::resolve(request, policy);
    to.deposit_balance(balance);

    if (investors.is_wallet(to_address)) {
        let id = investors.get_investor_id_by_wallet(to_address);
        let total_balance = investors.investor_wallet_balance_total(id);
        investors.update_investor_total_balance(
            id,
            try_from_u256_to_u64!((total_balance as u256) + (value as u256)),
        );

        let wallet_balance = investors.investor_wallet_balance(to_address);
        investors.update_wallet_balance(
            to_address,
            try_from_u256_to_u64!((wallet_balance as u256) + (value as u256)),
        );
    } else if (investors.is_special_wallet(to_address)) {
        let wallet_balance = investors.special_wallet_balance(to_address);
        investors.update_special_wallet_total_balance(
            to_address,
            try_from_u256_to_u64!((wallet_balance as u256) + (value as u256)),
        );
    };
    if (investors.is_wallet(from_address)) {
        let id = investors.get_investor_id_by_wallet(from_address);
        let total_balance = investors.investor_wallet_balance_total(id);
        assert!(total_balance >= value, ENotEnoughBalance);
        investors.update_investor_total_balance(id, (total_balance - value));

        let wallet_balance = investors.investor_wallet_balance(from_address);
        assert!(wallet_balance >= value, ENotEnoughBalance);
        investors.update_wallet_balance(from_address, wallet_balance - value);
    } else if (investors.is_special_wallet(from_address)) {
        let wallet_balance = investors.special_wallet_balance(from_address);
        assert!(wallet_balance >= value, ENotEnoughBalance);
        investors.update_special_wallet_total_balance(
            from_address,
            wallet_balance - value,
        );
    };
    emit_seize_event<T>(from_address, to_address, value, reason);
    emit_transfer_event<T>(from_address, to_address, value);
}

/// Processes a token transfer request between accounts.
/// The treasury must not be paused for the transfer to succeed.
///
/// # Aborts
/// * `EValueZero` - If the transfer value is zero
/// * `ETreasuryPaused` - If the treasury is paused and both parties are investors
public fun transfer<T>(
    treasury: &Treasury<T>,
    investors: &mut InvestorInfo<T>,
    compliance_config: &ComplianceConfig<T>,
    request: &mut Request<SendFunds<Balance<T>>>,
    version: &Version,
    clock: &Clock,
) {
    version.check_is_valid();
    let from_address = request.data().sender();
    let to_address = request.data().recipient();
    let value = request.data().funds().value();
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
        request,
        clock.timestamp_ms(),
        version,
    );
    if (investors.is_wallet(to_address)) {
        let id = investors.get_investor_id_by_wallet(to_address);
        let total_balance = investors.investor_wallet_balance_total(id);
        investors.update_investor_total_balance(
            id,
            try_from_u256_to_u64!((total_balance as u256) + (value as u256)),
        );

        let wallet_balance = investors.investor_wallet_balance(to_address);
        investors.update_wallet_balance(
            to_address,
            try_from_u256_to_u64!((wallet_balance as u256) + (value as u256)),
        );
    } else if (investors.is_special_wallet(to_address)) {
        let wallet_balance = investors.special_wallet_balance(to_address);
        investors.update_special_wallet_total_balance(
            to_address,
            try_from_u256_to_u64!((wallet_balance as u256) + (value as u256)),
        );
    };
    if (investors.is_wallet(from_address)) {
        let id = investors.get_investor_id_by_wallet(from_address);
        let total_balance = investors.investor_wallet_balance_total(id);
        assert!(total_balance >= value, ENotEnoughBalance);
        investors.update_investor_total_balance(
            id,
            total_balance - value,
        );

        let wallet_balance = investors.investor_wallet_balance(from_address);
        assert!(wallet_balance >= value, ENotEnoughBalance);
        investors.update_wallet_balance(from_address, wallet_balance - value);
    } else if (investors.is_special_wallet(from_address)) {
        let wallet_balance = investors.special_wallet_balance(from_address);
        assert!(wallet_balance >= value, ENotEnoughBalance);
        investors.update_special_wallet_total_balance(from_address, wallet_balance - value);
    };
    // Resolve the request
    request.approve(TransferApproval<T>());
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
    name.do!(|n| {
        let old_name = currency.name();
        currency.set_name<T>(metadata_cap, n);
        emit_name_updated_event<T>(old_name, n);
    });
    description.do!(|d| {
        let old_description = currency.description();
        currency.set_description<T>(metadata_cap, d);
        emit_description_updated_event<T>(old_description, d);
    });
    icon_url.do!(|i| {
        let old_icon_uri = currency.icon_url();
        currency.set_icon_url<T>(metadata_cap, i);
        emit_icon_uri_updated_event<T>(old_icon_uri, i);
    });
}

public fun set_template_command<T>(
    auth: &Auth<T>,
    templates: &mut Templates,
    command: Command,
    version: &Version,
    ctx: &mut TxContext,
) {
    version.check_is_valid();
    assert!(auth.owner_has_ability<T, SetTemplateCommand>(ctx.sender()), ENotAuthorized);
    templates.set_template_command<TransferApproval<T>>(
        internal::permit<TransferApproval<T>>(),
        command,
    );
}

public fun unset_template_command<T>(
    auth: &Auth<T>,
    templates: &mut Templates,
    version: &Version,
    ctx: &mut TxContext,
) {
    version.check_is_valid();
    assert!(auth.owner_has_ability<T, SetTemplateCommand>(ctx.sender()), ENotAuthorized);
    templates.unset_template_command<TransferApproval<T>>(internal::permit<TransferApproval<T>>());
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

/// Returns a reference to the PolicyCap stored in the Treasury.
/// Only authorized addresses with the AccessPolicyCap ability can call this function.
///
/// # Aborts
/// * `ENotAuthorized` - If the sender does not have the AccessPolicyCap ability
public fun policy_cap<T>(
    treasury: &Treasury<T>,
    auth: &Auth<T>,
    version: &Version,
    ctx: &TxContext,
): &PolicyCap<Balance<T>> {
    version.check_is_valid();
    assert!(auth.owner_has_ability<T, AccessPolicyCap>(ctx.sender()), ENotAuthorized);
    dof::borrow<PolicyCapKey, PolicyCap<Balance<T>>>(&treasury.id, PolicyCapKey())
}

// ==== View Functions ====

/// Returns whether the treasury is currently paused.
public fun is_paused<T>(treasury: &Treasury<T>): bool {
    treasury.paused
}

// ==== Macros ====

// Try to safely convert u256 to u64
macro fun try_from_u256_to_u64($number: u256): u64 {
    let mut number_option = std::u256::try_as_u64($number);
    assert!(number_option.is_some(), EArithmeticOverflow);
    number_option.extract()
}
