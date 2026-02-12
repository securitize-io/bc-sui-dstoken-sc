/// Module: registry_service
///
/// Manages investor registration and their associated wallets.
/// Stores investor attributes, country information, and tracks wallet-to-investor mappings
/// for compliance verification during token transfers.
module securitize::registry_service;

use pas::{namespace::Namespace, vault};
use securitize::{
    abilities::{
        RegisterInvestor,
        RemoveInvestor,
        UpdateInvestor,
        SetCountry,
        SetAttribute,
        AddWallet,
        RemoveWallet
    },
    events::{
        emit_investor_added_event,
        emit_investor_removed_event,
        emit_investor_country_changed_event,
        emit_investor_attribute_changed_event,
        emit_wallet_added_event,
        emit_wallet_removed_event
    },
    trust_service::{Auth, Master, Issuer, TransferAgent, Exchange},
    version::Version
};
use std::string::{Self, String};
use sui::{derived_object, table::{Self, Table}};

// ==== Error Codes ====

#[error(code = 0)]
const ENotAuthorized: vector<u8> = b"Caller is not authorized to perform this action";
#[error(code = 1)]
const EInvestorExists: vector<u8> = b"Investor already exists in the registry";
#[error(code = 2)]
const EEmptyId: vector<u8> = b"Investor ID cannot be empty";
#[error(code = 3)]
const EInvestorNotFound: vector<u8> = b"Investor not found in the registry";
#[error(code = 4)]
const EInvestorHasWallets: vector<u8> = b"Cannot remove investor that still has wallets";
#[error(code = 5)]
const EWrongVectorLength: vector<u8> = b"Attribute vectors have mismatched lengths";
#[error(code = 6)]
const ESpecialWallet: vector<u8> = b"Cannot add special wallet as a regular investor wallet";
#[error(code = 7)]
const EWalletAlreadyExists: vector<u8> = b"Wallet is already registered";
#[error(code = 8)]
const EWalletNotFound: vector<u8> = b"Wallet not found in the registry";
#[error(code = 9)]
const EWalletDoesNotBelongToInvestor: vector<u8> =
    b"Wallet does not belong to the specified investor";
#[error(code = 10)]
const EUnknownAttribute: vector<u8> = b"Unknown attribute ID provided";
#[error(code = 11)]
const EWrongInvestor: vector<u8> = b"Wallet belongs to a different investor";
#[error(code = 12)]
const EComplianceUnchanged: vector<u8> = b"Compliance region is already set to this value";
#[error(code = 13)]
const EWalletNotEmpty: vector<u8> = b"Cannot add or remove wallet with non-zero balance";

// ==== Attribute Constants ====

const NONE: u64 = 0;
#[allow(unused_const)]
const KYC_APPROVED: u64 = 1;
const ACCREDITED: u64 = 2;
const QUALIFIED: u64 = 4;
#[allow(unused_const)]
const PROFESSIONAL: u64 = 8;

// ==== Attribute Status Constants ====

#[allow(unused_const)]
const PENDING: u64 = 0;
#[allow(unused_const)]
const APPROVED: u64 = 1;
#[allow(unused_const)]
const REJECTED: u64 = 2;

// ==== TEMP Compliance Region Constants ====
const US: u64 = 1;
const EU: u64 = 2;
#[allow(unused_const)]
const FORBIDDEN: u64 = 4;
const JP: u64 = 8;

public struct RegistryServiceKey<phantom T>() has copy, drop, store;

// ==== Structs ====

/// Shared object containing all investor information for a token type T.
/// This is the main registry that tracks investors, their wallets, and compliance statistics.
public struct InvestorInfo<phantom T> has key {
    id: UID,
    /// Mapping of investor IDs to their investor data
    investors: Table<String, Investor>,
    /// Mapping of wallet addresses to their wallet data
    investor_wallets: Table<address, Wallet>,
    /// Mapping of special wallet addresses (e.g., treasury, reserve)
    special_wallets: Table<address, u64>,
    /// Mapping of special wallet addresses to balances
    special_wallets_balance: Table<address, u64>,
    /// Total number of registered investors
    total_investors_count: u64,
    /// Count of accredited investors across all regions
    accredited_investors_count: u64,
    /// Count of accredited investors in the United States
    us_accredited_investors_count: u64,
    /// Count of all investors in the United States
    us_investors_count: u64,
    /// Count of all investors in Japan
    jp_investors_count: u64,
    /// Count of retail (non-qualified) investors per EU country
    eu_retail_investors_count: Table<String, u64>,
    /// Mapping of country codes to their compliance region
    countries_compliances: Table<String, u64>,
    /// Investor locks data
    investor_locks: Table<String, InvestorLockState>,
    /// Investor issuances data
    investor_issuances: Table<String, vector<Issuance>>,
}

// ==== Structs ====

public struct Lock has drop, store {
    value: u64,
    reason_code: u64,
    reason_string: String,
    release_time_ms: u64,
}

public struct InvestorLockState has drop, store {
    fully_locked: bool,
    liquidate_only: bool,
    locks: vector<Lock>,
}

/// Individual issuance record tracking the amount and timestamp for lockup validation
public struct Issuance has copy, drop, store {
    /// Amount of tokens issued
    amount: u64,
    /// Timestamp when tokens were issued (in milliseconds)
    issuance_time_ms: u64,
}

/// Represents an investor in the registry with their compliance data.
public struct Investor has store {
    /// Address that created this investor record
    creator: address,
    /// Country code of the investor
    country: String,
    /// List of wallet addresses owned by this investor
    wallets: vector<address>,
    /// Compliance attributes (KYC, accreditation, etc.)
    attributes: Table<u64, Attribute>,
    /// Total token balance across all wallets
    total_balance: u64,
}

/// Represents a wallet linked to an investor.
public struct Wallet has drop, store {
    /// Investor ID that owns this wallet
    owner: String,
    /// Address that linked this wallet to the investor
    creator: address,
    /// Wallet token balance
    wallet_balance: u64,
}

/// Represents a compliance attribute with value and expiration.
public struct Attribute has copy, drop, store {
    /// The attribute value (e.g., APPROVED, REJECTED)
    value: u64,
    /// Unix timestamp when this attribute expires
    expiration: u64,
}

/// Initializes a new InvestorInfo for the given token type T.
///
/// Called by the setup module during token deployment.
public(package) fun new<T: key>(
    uid: &mut UID,
    auth: &mut Auth<T>,
    version: &Version,
    ctx: &mut TxContext,
): InvestorInfo<T> {
    // Assign abilities to roles
    auth.add_role_ability<T, Master, RegisterInvestor>(version, ctx);
    auth.add_role_ability<T, Master, RemoveInvestor>(version, ctx);
    auth.add_role_ability<T, Master, UpdateInvestor>(version, ctx);
    auth.add_role_ability<T, Master, SetCountry>(version, ctx);
    auth.add_role_ability<T, Master, SetAttribute>(version, ctx);
    auth.add_role_ability<T, Master, AddWallet>(version, ctx);
    auth.add_role_ability<T, Master, RemoveWallet>(version, ctx);

    auth.add_role_ability<T, Issuer, RegisterInvestor>(version, ctx);
    auth.add_role_ability<T, Issuer, RemoveInvestor>(version, ctx);
    auth.add_role_ability<T, Issuer, UpdateInvestor>(version, ctx);
    auth.add_role_ability<T, Issuer, SetCountry>(version, ctx);
    auth.add_role_ability<T, Issuer, SetAttribute>(version, ctx);
    auth.add_role_ability<T, Issuer, AddWallet>(version, ctx);
    auth.add_role_ability<T, Issuer, RemoveWallet>(version, ctx);

    auth.add_role_ability<T, Exchange, RegisterInvestor>(version, ctx);
    auth.add_role_ability<T, Exchange, RemoveInvestor>(version, ctx);
    auth.add_role_ability<T, Exchange, SetCountry>(version, ctx);
    auth.add_role_ability<T, Exchange, SetAttribute>(version, ctx);
    auth.add_role_ability<T, Exchange, AddWallet>(version, ctx);
    auth.add_role_ability<T, Exchange, RemoveWallet>(version, ctx);

    auth.add_role_ability<T, TransferAgent, RegisterInvestor>(version, ctx);
    auth.add_role_ability<T, TransferAgent, RemoveInvestor>(version, ctx);
    auth.add_role_ability<T, TransferAgent, UpdateInvestor>(version, ctx);
    auth.add_role_ability<T, TransferAgent, SetCountry>(version, ctx);
    auth.add_role_ability<T, TransferAgent, SetAttribute>(version, ctx);
    auth.add_role_ability<T, TransferAgent, AddWallet>(version, ctx);
    auth.add_role_ability<T, TransferAgent, RemoveWallet>(version, ctx);

    let investor_info = InvestorInfo<T> {
        id: derived_object::claim(uid, RegistryServiceKey<T>()),
        investors: table::new(ctx),
        investor_wallets: table::new(ctx),
        special_wallets: table::new(ctx),
        special_wallets_balance: table::new(ctx),
        total_investors_count: 0,
        accredited_investors_count: 0,
        us_accredited_investors_count: 0,
        us_investors_count: 0,
        jp_investors_count: 0,
        eu_retail_investors_count: table::new(ctx),
        countries_compliances: table::new(ctx),
        investor_locks: table::new(ctx),
        investor_issuances: table::new(ctx),
    };
    investor_info
}

/// Makes the InvestorInfo a shared object for public access
public(package) fun share<T>(investor_info: InvestorInfo<T>) {
    transfer::share_object(investor_info);
}

// ==== Public Functions ====

/// Registers a new investor in the registry.
/// Only authorized addresses with the RegisterInvestor ability can call this function.
///
/// # Aborts
/// * `ENotAuthorized` - If the sender does not have the RegisterInvestor ability
/// * `EInvestorExists` - If the investor already exists
public fun register_investor<T: key>(
    investor_info: &mut InvestorInfo<T>,
    auth: &Auth<T>,
    investor_id: String,
    version: &Version,
    ctx: &mut TxContext,
) {
    version.check_is_valid();
    assert!(auth.owner_has_ability<T, RegisterInvestor>(ctx.sender()), ENotAuthorized);
    assert!(!investor_info.is_investor(investor_id), EInvestorExists);
    register_investor_internal(investor_info, investor_id, ctx);
}

/// Registers a new investor if they don't already exist.
/// Does nothing if the investor already exists.
/// Only authorized addresses with the RegisterInvestor ability can call this function.
///
/// # Aborts
/// * `ENotAuthorized` - If the sender does not have the RegisterInvestor ability
public fun register_investor_if_not_exists<T: key>(
    investor_info: &mut InvestorInfo<T>,
    auth: &Auth<T>,
    investor_id: String,
    version: &Version,
    ctx: &mut TxContext,
) {
    version.check_is_valid();
    assert!(auth.owner_has_ability<T, RegisterInvestor>(ctx.sender()), ENotAuthorized);
    if (investor_info.is_investor(investor_id)) {
        return
    };
    register_investor_internal(investor_info, investor_id, ctx);
}

/// Removes an investor from the registry.
/// The investor must have no wallets associated before removal.
/// Only authorized addresses with the RemoveInvestor ability can call this function.
///
/// # Aborts
/// * `ENotAuthorized` - If the sender does not have the RemoveInvestor ability
/// * `EInvestorNotFound` - If the investor does not exist
/// * `EInvestorHasWallets` - If the investor still has wallets associated
public fun remove_investor<T: key>(
    investor_info: &mut InvestorInfo<T>,
    auth: &Auth<T>,
    investor_id: String,
    version: &Version,
    ctx: &mut TxContext,
) {
    version.check_is_valid();
    assert!(auth.owner_has_ability<T, RemoveInvestor>(ctx.sender()), ENotAuthorized);
    assert!(investor_info.is_investor(investor_id), EInvestorNotFound);
    assert!(investor_info.investors.borrow(investor_id).wallets.length() == 0, EInvestorHasWallets);

    let Investor {
        creator: _,
        country: _,
        wallets: _,
        attributes,
        total_balance: _,
    } = investor_info.investors.remove(investor_id);
    attributes.drop();
    // Clean up issuances and locks
    let _issuances: vector<Issuance> = investor_info.investor_issuances.remove(investor_id);
    let _locks: InvestorLockState = investor_info.investor_locks.remove(investor_id);
    emit_investor_removed_event<T>(investor_id, ctx.sender());
}

/// Updates an investor's information including country, wallets, and attributes.
/// If the investor does not exist, it will be registered first.
/// Only authorized addresses with the UpdateInvestor ability can call this function.
///
/// # Aborts
/// * `ENotAuthorized` - If the sender does not have the UpdateInvestor ability
/// * `EWrongVectorLength` - If attribute vectors have mismatched lengths
/// * `EWrongInvestor` - If a wallet already belongs to a different investor
public fun update_investor<T: key>(
    investor_info: &mut InvestorInfo<T>,
    auth: &Auth<T>,
    namespace: &mut Namespace,
    investor_id: String,
    country: String,
    wallets: vector<address>,
    attribute_ids: vector<u64>,
    attribute_values: vector<u64>,
    attribute_expirations: vector<u64>,
    version: &Version,
    ctx: &mut TxContext,
) {
    version.check_is_valid();
    assert!(auth.owner_has_ability<T, UpdateInvestor>(ctx.sender()), ENotAuthorized);
    assert!(attribute_values.length() == attribute_ids.length(), EWrongVectorLength);
    assert!(attribute_expirations.length() == attribute_ids.length(), EWrongVectorLength);

    if (!investor_info.is_investor(investor_id)) {
        register_investor<T>(investor_info, auth, investor_id, version, ctx);
    };

    if (country.length() > 0) {
        set_country<T>(investor_info, auth, investor_id, country, version, ctx);
    };
    wallets.do!(|wallet| {
        if (investor_info.is_wallet(wallet)) {
            assert!(
                investor_info.investor_wallets.borrow(wallet).owner == investor_id,
                EWrongInvestor,
            );
        } else {
            investor_info.add_wallet<T>(
                auth,
                namespace,
                investor_id,
                wallet,
                version,
                ctx,
            );
        };
    });
    let mut i = 0;
    while (i < attribute_ids.length()) {
        investor_info.set_attribute<T>(
            auth,
            investor_id,
            attribute_ids[i],
            attribute_values[i],
            attribute_expirations[i],
            version,
            ctx,
        );
        i = i + 1;
    }
}

// ==== Wallet Configuration ====

/// Adds a wallet address to an investor's list of wallets.
/// Only authorized addresses with the AddWallet ability can call this function.
///
/// # Aborts
/// * `ENotAuthorized` - If the sender does not have the AddWallet ability
/// * `ESpecialWallet` - If the wallet is a special wallet (e.g., treasury)
/// * `EInvestorNotFound` - If the investor does not exist
/// * `EWalletAlreadyExists` - If the wallet is already registered
public fun add_wallet<T>(
    investor_info: &mut InvestorInfo<T>,
    auth: &Auth<T>,
    namespace: &mut Namespace,
    investor_id: String,
    wallet_addr: address,
    version: &Version,
    ctx: &mut TxContext,
) {
    version.check_is_valid();
    assert!(auth.owner_has_ability<T, AddWallet>(ctx.sender()), ENotAuthorized);
    assert!(!investor_info.is_special_wallet(wallet_addr), ESpecialWallet);
    assert!(investor_info.is_investor(investor_id), EInvestorNotFound);
    assert!(!investor_info.is_wallet(wallet_addr), EWalletAlreadyExists);
    if (!namespace.vault_exists(wallet_addr)) {
        vault::create_and_share(namespace, wallet_addr);
    };

    let wallet = Wallet {
        owner: investor_id,
        creator: ctx.sender(),
        wallet_balance: 0,
    };
    investor_info.investor_wallets.add(wallet_addr, wallet);
    investor_info.investors.borrow_mut(investor_id).wallets.push_back(wallet_addr);
    emit_wallet_added_event<T>(wallet_addr, investor_id, ctx.sender());
}

/// Removes a wallet address from an investor's list of wallets.
/// Only authorized addresses with the RemoveWallet ability can call this function.
///
/// # Aborts
/// * `ENotAuthorized` - If the sender does not have the RemoveWallet ability
/// * `EWalletNotFound` - If the wallet does not exist
/// * `EWalletDoesNotBelongToInvestor` - If the wallet does not belong to the specified investor
public fun remove_wallet<T>(
    investor_info: &mut InvestorInfo<T>,
    auth: &Auth<T>,
    investor_id: String,
    wallet_addr: address,
    version: &Version,
    ctx: &mut TxContext,
) {
    version.check_is_valid();
    assert!(auth.owner_has_ability<T, RemoveWallet>(ctx.sender()), ENotAuthorized);
    assert!(investor_info.is_wallet(wallet_addr), EWalletNotFound);
    let wallet = investor_info.investor_wallets.borrow(wallet_addr);
    assert!(wallet.owner == investor_id, EWalletDoesNotBelongToInvestor);
    assert!(wallet.wallet_balance == 0, EWalletNotEmpty);
    investor_info.investor_wallets.remove(wallet_addr);
    let wallets = investor_info.investors.borrow_mut(investor_id).wallets;
    let idx = wallets.find_index!(|k| k == wallet_addr).destroy_or!(abort EWalletNotFound);
    investor_info.investors.borrow_mut(investor_id).wallets.remove(idx);
    emit_wallet_removed_event<T>(wallet_addr, investor_id, ctx.sender());
}

// ==== Country and Attribute Configuration ====

/// Sets the country for an investor and updates compliance statistics.
/// Only authorized addresses with the SetCountry ability can call this function.
///
/// # Aborts
/// * `ENotAuthorized` - If the sender does not have the SetCountry ability
/// * `EInvestorNotFound` - If the investor does not exist
public fun set_country<T: key>(
    investor_info: &mut InvestorInfo<T>,
    auth: &Auth<T>,
    investor_id: String,
    country: String,
    version: &Version,
    ctx: &mut TxContext,
) {
    version.check_is_valid();
    assert!(auth.owner_has_ability<T, SetCountry>(ctx.sender()), ENotAuthorized);
    assert!(investor_info.is_investor(investor_id), EInvestorNotFound);

    let prev_country = investor_info.investors.borrow(investor_id).country;
    adjust_investor_counts_after_country_change(investor_info, investor_id, country, prev_country);
    let investor = investor_info.investors.borrow_mut(investor_id);
    investor.country = country;
    emit_investor_country_changed_event<T>(investor_id, country, ctx.sender());
}

/// Sets or updates a compliance attribute for an investor.
/// If the attribute already exists, it will be updated; otherwise, it will be created.
/// Only authorized addresses with the SetAttribute ability can call this function.
///
/// # Aborts
/// * `ENotAuthorized` - If the sender does not have the SetAttribute ability
/// * `EInvestorNotFound` - If the investor does not exist
/// * `EUnknownAttribute` - If the attribute_id is >= 16
public fun set_attribute<T>(
    investor_info: &mut InvestorInfo<T>,
    auth: &Auth<T>,
    investor_id: String,
    attribute_id: u64,
    attribute_value: u64,
    attribute_expiration: u64,
    version: &Version,
    ctx: &mut TxContext,
) {
    version.check_is_valid();
    assert!(auth.owner_has_ability<T, SetAttribute>(ctx.sender()), ENotAuthorized);
    assert!(investor_info.is_investor(investor_id), EInvestorNotFound);
    assert!(attribute_id < 16, EUnknownAttribute);

    let investor = investor_info.investors.borrow_mut(investor_id);
    if (investor.attributes.contains(attribute_id)) {
        let attribute = investor.attributes.borrow_mut(attribute_id);
        attribute.value = attribute_value;
        attribute.expiration = attribute_expiration;
    } else {
        let attribute = Attribute {
            value: attribute_value,
            expiration: attribute_expiration,
        };
        investor.attributes.add(attribute_id, attribute);
    };
    emit_investor_attribute_changed_event<T>(
        investor_id,
        attribute_id,
        attribute_value,
        attribute_expiration,
        ctx.sender(),
    );
}

// ==== View Functions ====

/// Returns whether an investor exists in the registry.
public fun is_investor<T>(investor_info: &InvestorInfo<T>, investor_id: String): bool {
    investor_info.investors.contains(investor_id)
}

/// Returns whether an investor exists in the registry.
public fun get_investor_id_by_wallet<T>(investor_info: &InvestorInfo<T>, wallet: address): String {
    assert!(investor_info.is_wallet(wallet), EInvestorNotFound);
    investor_info.investor_wallets.borrow(wallet).owner
}

/// Returns whether a wallet is registered in the registry.
public fun is_wallet<T>(investor_info: &InvestorInfo<T>, wallet: address): bool {
    investor_info.investor_wallets.contains(wallet)
}

/// Returns whether a wallet is a special wallet (e.g., ISSUER, PLATFORM).
public fun is_special_wallet<T>(investor_info: &InvestorInfo<T>, wallet: address): bool {
    let wallet_type = investor_info.get_special_wallet_type(wallet);
    wallet_type != 0
}

/// Retrieves the wallet type for a special wallet address.
public fun get_special_wallet_type<T>(investor_info: &InvestorInfo<T>, wallet: address): u64 {
    if (!investor_info.special_wallets.contains(wallet)) {
        return 0
    };
    *investor_info.special_wallets.borrow(wallet)
}

/// Returns the total token balance across all wallets for an investor.
///
/// # Aborts
/// * `EInvestorNotFound` - If the investor does not exist
public fun investor_wallet_balance_total<T>(
    investor_info: &InvestorInfo<T>,
    investor_id: String,
): u64 {
    assert!(investor_info.is_investor(investor_id), EInvestorNotFound);
    let investor = investor_info.investors.borrow(investor_id);
    investor.total_balance
}

/// Returns the total token balance across all wallets for an investor.
///
/// # Aborts
/// * `EInvestorNotFound` - If the investor does not exist
public fun investor_wallet_balance<T>(investor_info: &InvestorInfo<T>, wallet_addr: address): u64 {
    assert!(investor_info.is_wallet(wallet_addr), EWalletNotFound);
    let wallet = investor_info.investor_wallets.borrow(wallet_addr);
    wallet.wallet_balance
}

/// Returns whether an investor has accredited status.
public fun is_accredited_investor_by_id<T>(
    investor_info: &InvestorInfo<T>,
    investor_id: String,
): bool {
    investor_info.get_attribute_value(investor_id, ACCREDITED) == APPROVED
}

/// Returns whether an investor has accredited status based on their wallet address.
public fun is_accredited_investor<T>(investor_info: &InvestorInfo<T>, wallet: address): bool {
    let id = investor_info.investor_wallets.borrow(wallet).owner;
    investor_info.is_accredited_investor_by_id(id)
}

/// Returns whether an investor has qualified status.
public fun is_qualified_investor_by_id<T>(
    investor_info: &InvestorInfo<T>,
    investor_id: String,
): bool {
    investor_info.get_attribute_value(investor_id, QUALIFIED) == APPROVED
}

/// Returns whether an investor has qualified status based on their wallet address.
public fun is_qualified_investor<T>(investor_info: &InvestorInfo<T>, wallet: address): bool {
    let id = investor_info.investor_wallets.borrow(wallet).owner;
    investor_info.is_qualified_investor_by_id(id)
}

/// Returns the compliance region for a given country code.
public fun get_country_compliance<T>(investor_info: &InvestorInfo<T>, country: String): u64 {
    if (!investor_info.countries_compliances.contains(country)) {
        return NONE
    };
    *investor_info.countries_compliances.borrow(country)
}

/// Returns the country of the investor.
public fun get_country<T>(investor_info: &InvestorInfo<T>, investor_id: String): String {
    investor_info.investors.borrow(investor_id).country
}

/// Returns the value of a specific attribute for an investor.
/// Returns 0 if the investor or attribute does not exist.
public fun get_attribute_value<T>(
    investor_info: &InvestorInfo<T>,
    investor_id: String,
    attribute_id: u64,
): u64 {
    let investor = investor_info.investors.borrow(investor_id);
    if (!investor.attributes.contains(attribute_id)) {
        return 0
    };
    investor.attributes.borrow(attribute_id).value
}

/// Returns the expiration timestamp of a specific attribute for an investor.
/// Returns 0 if the investor or attribute does not exist.
public fun get_attribute_expiration<T>(
    investor_info: &InvestorInfo<T>,
    investor_id: String,
    attribute_id: u64,
): u64 {
    let investor = investor_info.investors.borrow(investor_id);
    if (!investor.attributes.contains(attribute_id)) {
        return 0
    };
    investor.attributes.borrow(attribute_id).expiration
}

/// Returns the total number of investors.
public fun get_total_investors_count<T>(investor_info: &InvestorInfo<T>): u64 {
    investor_info.total_investors_count
}

/// Returns the total number of accredited investors.
public fun get_accredited_investor_count<T>(investor_info: &InvestorInfo<T>): u64 {
    investor_info.accredited_investors_count
}

/// Returns the total number of US investors.
public fun get_us_investor_count<T>(investor_info: &InvestorInfo<T>): u64 {
    investor_info.us_investors_count
}

/// Returns the total number of US accredited investors.
public fun get_us_accredited_investor_count<T>(investor_info: &InvestorInfo<T>): u64 {
    investor_info.us_accredited_investors_count
}

/// Returns the total number of JP investors.
public fun get_jp_investor_count<T>(investor_info: &InvestorInfo<T>): u64 {
    investor_info.jp_investors_count
}

/// Returns the total number of EU retail investors for a given country.
public fun get_eu_retail_investor_count<T>(
    investor_info: &InvestorInfo<T>,
    to_country: String,
): Option<u64> {
    if (investor_info.eu_retail_investors_count.contains(to_country)) {
        return option::some(*investor_info.eu_retail_investors_count.borrow(to_country))
    };
    option::none()
}

/// Creates a new Issuance record
public fun new_issuance(amount: u64, issuance_time_ms: u64): Issuance {
    Issuance { amount, issuance_time_ms }
}

/// Get amount from issuance
public fun issuance_amount(issuance: &Issuance): u64 {
    issuance.amount
}

/// Get issuance time from issuance (in milliseconds)
public fun issuance_time_ms(issuance: &Issuance): u64 {
    issuance.issuance_time_ms
}

// ==== Public Package Functions ====

/// Sets the total token balance for an investor.
public(package) fun update_investor_total_balance<T>(
    investor_info: &mut InvestorInfo<T>,
    investor_id: String,
    new_total_balance: u64,
) {
    let investor = investor_info.investors.borrow_mut(investor_id);
    investor.total_balance = new_total_balance;
}

public(package) fun special_wallet_balance<T>(
    investor_info: &InvestorInfo<T>,
    wallet: address,
): u64 {
    *investor_info.special_wallets_balance.borrow(wallet)
}

/// Sets the total token balance for a special wallet.
public(package) fun update_special_wallet_total_balance<T>(
    investor_info: &mut InvestorInfo<T>,
    wallet: address,
    new_total_balance: u64,
) {
    let special_wallet_balance = investor_info.special_wallets_balance.borrow_mut(wallet);
    *special_wallet_balance = new_total_balance;
}

/// Sets the total token balance for an investor.
public(package) fun update_wallet_balance<T>(
    investor_info: &mut InvestorInfo<T>,
    wallet_addr: address,
    new_wallet_balance: u64,
) {
    let wallet = investor_info.investor_wallets.borrow_mut(wallet_addr);
    wallet.wallet_balance = new_wallet_balance;
}

/// Sets the compliance region for a given country code.
/// - If `compliance_region == NONE`, removes the country entry if it exists.
/// - Otherwise, inserts or updates the entry.
/// - No-op if the value is unchanged.
public(package) fun set_country_compliance<T>(
    investor_info: &mut InvestorInfo<T>,
    country: String,
    compliance_region: u64,
) {
    let previous = get_country_compliance(investor_info, country);
    assert!(previous != compliance_region, EComplianceUnchanged);
    if (compliance_region == NONE) {
        investor_info.countries_compliances.remove(country);
        return
    };
    if (compliance_region == EU) {
        investor_info.set_eu_retail_investors_country_if_not_exists(country);
    };
    if (previous == NONE) {
        investor_info.countries_compliances.add(country, compliance_region);
    } else {
        *investor_info.countries_compliances.borrow_mut(country) = compliance_region;
    }
}

/// Sets a special wallet type for a wallet address.
public(package) fun set_special_wallet<T>(
    investor_info: &mut InvestorInfo<T>,
    wallet: address,
    wallet_type: u64,
) {
    investor_info.special_wallets.add(wallet, wallet_type);
    investor_info.special_wallets_balance.add(wallet, 0);
}

/// Removes a special wallet from the registry.
public(package) fun remove_special_wallet<T>(
    investor_info: &mut InvestorInfo<T>,
    wallet: address,
): u64 {
    investor_info.special_wallets_balance.remove(wallet);
    investor_info.special_wallets.remove(wallet)
}

/// Sets the total count of investors.
public(package) fun set_total_investors_count<T>(investor_info: &mut InvestorInfo<T>, count: u64) {
    investor_info.total_investors_count = count;
}

/// Sets the count of US investors.
public(package) fun set_us_investors_count<T>(investor_info: &mut InvestorInfo<T>, count: u64) {
    investor_info.us_investors_count = count;
}

/// Sets the count of US accredited investors.
public(package) fun set_us_accredited_investors_count<T>(
    investor_info: &mut InvestorInfo<T>,
    count: u64,
) {
    investor_info.us_accredited_investors_count = count;
}

/// Sets the count of accredited investors.
public(package) fun set_accredited_investors_count<T>(
    investor_info: &mut InvestorInfo<T>,
    count: u64,
) {
    investor_info.accredited_investors_count = count;
}

/// Sets the count of Japanese investors.
public(package) fun set_jp_investors_count<T>(investor_info: &mut InvestorInfo<T>, count: u64) {
    investor_info.jp_investors_count = count;
}

public(package) fun set_eu_retail_investors_country_if_not_exists<T>(
    investor_info: &mut InvestorInfo<T>,
    country: String,
) {
    if (!investor_info.eu_retail_investors_count.contains(country)) {
        investor_info.eu_retail_investors_count.add(country, 0);
    };
}

/// Returns a reference to the investor issuances for a given investor ID.
public(package) fun get_investor_issuances<T>(
    investor_info: &InvestorInfo<T>,
    investor_id: String,
): &vector<Issuance> {
    investor_info.investor_issuances.borrow(investor_id)
}

/// Returns a mutable reference to the investor issuances for a given investor ID.
public(package) fun get_investor_issuances_mut<T>(
    investor_info: &mut InvestorInfo<T>,
    investor_id: String,
): &mut vector<Issuance> {
    investor_info.investor_issuances.borrow_mut(investor_id)
}

/// Returns a reference to the investor lock state for a given investor ID.
public(package) fun get_investor_locks<T>(
    investor_info: &InvestorInfo<T>,
    investor_id: String,
): &InvestorLockState {
    investor_info.investor_locks.borrow(investor_id)
}

/// Returns a mutable reference to the investor lock state for a given investor ID.
public(package) fun get_investor_locks_mut<T>(
    investor_info: &mut InvestorInfo<T>,
    investor_id: String,
): &mut InvestorLockState {
    investor_info.investor_locks.borrow_mut(investor_id)
}

// ==== InvestorLockState Accessors ====

/// Returns whether the investor is fully locked
public(package) fun is_fully_locked(state: &InvestorLockState): bool {
    state.fully_locked
}

/// Sets the fully locked status
public(package) fun set_fully_locked(state: &mut InvestorLockState, locked: bool) {
    state.fully_locked = locked;
}

/// Returns whether the investor is in liquidate only mode
public(package) fun is_liquidate_only(state: &InvestorLockState): bool {
    state.liquidate_only
}

/// Sets the liquidate only status
public(package) fun set_liquidate_only(state: &mut InvestorLockState, enabled: bool) {
    state.liquidate_only = enabled;
}

/// Returns the number of locks
public(package) fun locks_length(state: &InvestorLockState): u64 {
    state.locks.length()
}

/// Adds a new lock to the lock state
public(package) fun add_lock(
    state: &mut InvestorLockState,
    value: u64,
    reason_code: u64,
    reason_string: String,
    release_time_ms: u64,
) {
    let lock = Lock {
        value,
        reason_code,
        reason_string,
        release_time_ms,
    };
    state.locks.push_back(lock);
}

/// Removes a lock at the given index (swap-remove) and returns it
public(package) fun remove_lock(state: &mut InvestorLockState, index: u64): Lock {
    let len = state.locks.length();
    let last = len - 1;
    if (index != last) {
        state.locks.swap(index, last);
    };
    state.locks.pop_back()
}

// ==== Lock Accessors ====

public(package) fun lock_value(lock: &Lock): u64 {
    lock.value
}

public(package) fun lock_reason_code(lock: &Lock): u64 {
    lock.reason_code
}

public(package) fun lock_reason_string(lock: &Lock): String {
    lock.reason_string
}

public(package) fun lock_release_time_ms(lock: &Lock): u64 {
    lock.release_time_ms
}

/// Computes the total locked amount based on current time
public(package) fun compute_locked_sum(state: &InvestorLockState, now_ms: u64): u64 {
    let mut locked_sum = 0;
    state.locks.do_ref!(|l| {
        if (l.release_time_ms == 0 || l.release_time_ms > now_ms) {
            locked_sum = locked_sum + l.value
        }
    });
    locked_sum
}

// Adjusts compliance counters for a specific country.
// Updates accredited, US, EU retail, and JP investor counts based on
// the investor's accreditation/qualification status and country compliance region.
public(package) fun adjust_investors_counts_by_country<T>(
    investor_info: &mut InvestorInfo<T>,
    investor_id: String,
    country: String,
    increase: bool,
) {
    let country_compliance = investor_info.get_country_compliance(country);
    if (investor_info.is_accredited_investor_by_id(investor_id)) {
        apply_change(&mut investor_info.accredited_investors_count, increase);
        if (country_compliance == US) {
            apply_change(&mut investor_info.us_accredited_investors_count, increase);
        };
    };
    if (country_compliance == US) {
        apply_change(&mut investor_info.us_investors_count, increase);
    } else if (country_compliance == EU && !investor_info.is_qualified_investor_by_id(investor_id)) {
        if (investor_info.get_eu_retail_investor_count(country).is_some()) {
            let count = investor_info.eu_retail_investors_count.borrow_mut(country);
            apply_change(count, increase);
        }
    } else if (country_compliance == JP) {
        apply_change(&mut investor_info.jp_investors_count, increase);
    };
}

/// Increase or decrease a counter by 1
public(package) fun apply_change(counter: &mut u64, increase: bool) {
    if (increase) {
        *counter = *counter + 1;
    } else {
        assert!(*counter > 0, 0);
        *counter = *counter - 1;
    };
}

// ==== Internal Functions ====

fun register_investor_internal<T: key>(
    investor_info: &mut InvestorInfo<T>,
    investor_id: String,
    ctx: &mut TxContext,
) {
    assert!(investor_id.length() > 0, EEmptyId);

    let investor = Investor {
        creator: ctx.sender(),
        country: string::utf8(b""),
        wallets: vector[],
        attributes: table::new(ctx),
        total_balance: 0,
    };
    investor_info.investors.add(investor_id, investor);
    investor_info.investor_issuances.add(investor_id, vector[]);
    investor_info
        .investor_locks
        .add(
            investor_id,
            InvestorLockState {
                fully_locked: false,
                liquidate_only: false,
                locks: vector::empty(),
            },
        );
    emit_investor_added_event<T>(investor_id, ctx.sender());
}

// Adjusts compliance counters when an investor's country changes.
// Only updates counters if the investor has a non-zero balance.
fun adjust_investor_counts_after_country_change<T>(
    investor_info: &mut InvestorInfo<T>,
    investor_id: String,
    new_country: String,
    prev_country: String,
) {
    if (investor_info.investor_wallet_balance_total(investor_id) != 0) {
        adjust_investors_counts_by_country(investor_info, investor_id, prev_country, false);
        adjust_investors_counts_by_country(investor_info, investor_id, new_country, true);
    };
}
