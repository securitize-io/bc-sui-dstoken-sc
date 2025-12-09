/// Module: registry_service
///
/// This module manages the investor registry for security tokens.
/// It provides functionality to register, remove, and update investors,
/// manage their wallets, and track compliance-related attributes such as
/// country, accreditation status, and qualification status.
module securitize::registry_service;

use std::string::{Self, String};
use sui::table::{Self, Table};
use sui::event;
use securitize::{version::Version, trust_service::{Auth, Master, Issuer}};

// ==== Error Codes ====

/// Error code when the caller is not authorized to perform the action
const ENotAuthorized: u64 = 0;
/// Error code when attempting to register an investor that already exists
const EInvestorExists: u64 = 1;
/// Error code when an empty investor ID is provided
const EEmptyId: u64 = 2;
/// Error code when the specified investor does not exist in the registry
const EInvestorNotFound: u64 = 3;
/// Error code when attempting to remove an investor that still has wallets
const EInvestorHasWallets: u64 = 4;
/// Error code when attribute vectors have mismatched lengths
const EWrongVectorLength: u64 = 5;
/// Error code when attempting to add a special wallet as a regular investor wallet
const ESpecialWallet: u64 = 6;
/// Error code when attempting to add a wallet that is already registered
const EWalletAlreadyExists: u64 = 7;
/// Error code when the specified wallet does not exist in the registry
const EWalletNotFound: u64 = 8;
/// Error code when wallet does not belong to the specified investor
const EWalletDoesNotBelongToInvestor: u64 = 9;
/// Error code when an unknown attribute ID is provided
const EUnknownAttribute: u64 = 10;
/// Error code when wallet belongs to a different investor than expected
const EWrongInvestor: u64 = 11;

// ==== Attribute Constants ====

// TODO: Think about making these Enums
const NONE: u64 = 0;
const KYC_APPROVED: u64 = 1;
const ACCREDITED: u64 = 2;
const QUALIFIED: u64 = 4;
const PROFESSIONAL: u64 = 8;

// ==== Attribute Status Constants ====

const PENDING: u64 = 0;
const APPROVED: u64 = 1;
const REJECTED: u64 = 2;

// ==== TEMP Compliance Region Constants ====
const US: u64 = 1;
const EU: u64 = 2;
const FORBIDDEN: u64 = 4;
const JP: u64 = 8;

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
    countries_compliances: Table<String, u64>
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
public struct Wallet has store, drop {
    /// Investor ID that owns this wallet
    owner: String,
    /// Address that linked this wallet to the investor
    creator: address,
}

/// Represents a compliance attribute with value and expiration.
public struct Attribute has store, copy, drop {
    /// The attribute value (e.g., APPROVED, REJECTED)
    value: u64,
    /// Unix timestamp when this attribute expires
    expiration: u64,
}

// ==== Registry Service Abilities ====

/// Ability to register new investors
public struct RegisterInvestor() has drop;

/// Ability to remove investors from the registry
public struct RemoveInvestor() has drop;

/// Ability to update investor information
public struct UpdateInvestor() has drop;

/// Ability to set investor country
public struct SetCountry() has drop;

/// Ability to set investor attributes
public struct SetAttribute() has drop;

/// Ability to add wallets to investors
public struct AddWallet() has drop;

/// Ability to remove wallets from investors
public struct RemoveWallet() has drop;

// ==== Events ====

/// Emitted when a new investor is registered
public struct InvestorRegistered<phantom T> has copy, drop {
    investor_id: String,
    sender: address,
}

/// Emitted when an investor is removed from the registry
public struct InvestorRemoved<phantom T> has copy, drop {
    investor_id: String,
    sender: address,
}

/// Emitted when an investor's country is changed
public struct InvestorCountryChanged<phantom T> has copy, drop {
    investor_id: String,
    country: String,
    sender: address,
}

/// Emitted when a wallet is added to an investor
public struct WalletAdded<phantom T> has copy, drop {
    wallet: address,
    investor_id: String,
    sender: address,
}

/// Emitted when a wallet is removed from an investor
public struct WalletRemoved<phantom T> has copy, drop {
    wallet: address,
    investor_id: String,
    sender: address,
}

/// Emitted when an investor's attribute is changed
public struct AttributeChanged<phantom T> has copy, drop {
    investor_id: String,
    attribute_id: u64,
    value: u64,
    expiry: u64,
    sender: address,
}

/// Initializes a new InvestorInfo for the given token type T.
///
/// Called by the setup module during token deployment.
public(package) fun new<T: key>(
    auth: &mut Auth<T>,
    version: &Version,
    ctx: &mut TxContext,
): InvestorInfo<T> {
    // Assign abilities to roles
    auth.add_role_ability<T, Master, RegisterInvestor>(version,ctx);
    auth.add_role_ability<T, Master, RemoveInvestor>(version,ctx);
    auth.add_role_ability<T, Master, UpdateInvestor>(version,ctx);
    auth.add_role_ability<T, Master, SetCountry>(version,ctx);
    auth.add_role_ability<T, Master, SetAttribute>(version,ctx);
    auth.add_role_ability<T, Master, AddWallet>(version,ctx);
    auth.add_role_ability<T, Master, RemoveWallet>(version,ctx);

    auth.add_role_ability<T, Issuer, RegisterInvestor>(version,ctx);
    auth.add_role_ability<T, Issuer, RemoveInvestor>(version,ctx);
    auth.add_role_ability<T, Issuer, UpdateInvestor>(version,ctx);
    auth.add_role_ability<T, Issuer, SetCountry>(version,ctx);
    auth.add_role_ability<T, Issuer, SetAttribute>(version,ctx);
    auth.add_role_ability<T, Issuer, AddWallet>(version,ctx);
    auth.add_role_ability<T, Issuer, RemoveWallet>(version,ctx);

    let investor_info = InvestorInfo<T> {
        id: object::new(ctx),
        investors: table::new(ctx),
        investor_wallets: table::new(ctx),
        special_wallets: table::new(ctx),
        total_investors_count: 0,
        accredited_investors_count: 0,
        us_accredited_investors_count: 0,
        us_investors_count: 0,
        jp_investors_count: 0,
        eu_retail_investors_count: table::new(ctx),
        countries_compliances: table::new(ctx),
    };
    investor_info
}

/// Makes the InvestorInfo a shared object for public access
#[lint_allow(share_owned)]
public(package) fun share<T>(investor_info: InvestorInfo<T>) {
    transfer::share_object(investor_info);
}

// ==== Public Functions ====

/// Registers a new investor in the registry.
/// Only authorized addresses with the RegisterInvestor ability can call this function.
///
/// # Aborts
/// * `ENotAuthorized` - If the sender does not have the RegisterInvestor ability
/// * `EInvestorNotFound` - If the investor already exists
/// * `EEmptyId` - If the investor_id is empty
public fun register_investor<T: key>(
    investor_info: &mut InvestorInfo<T>,
    auth: &Auth<T>,
    investor_id: String,
    version: &Version,
    ctx: &mut TxContext,
) {
    version.check_is_valid();
    assert!(auth.owner_has_ability<T, RegisterInvestor>(ctx.sender()), ENotAuthorized);
    assert!(!investor_info.is_investor(investor_id), EInvestorNotFound);
    assert!(investor_id.length() > 0, EEmptyId);

    let investor = Investor {
        creator: ctx.sender(),
        country: string::utf8(b""),
        wallets: vector[],
        attributes: table::new(ctx),
        total_balance: 0,
    };
    investor_info.investors.add(investor_id, investor);
    event::emit(InvestorRegistered<T> { investor_id, sender: ctx.sender() });
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

    let Investor { creator:_, country:_, wallets:_, attributes, total_balance:_ } = investor_info.investors.remove(investor_id);
    attributes.drop();
    event::emit(InvestorRemoved<T> { investor_id, sender: ctx.sender() });
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
            assert!(investor_info.investor_wallets.borrow(wallet).owner == investor_id, EWrongInvestor);
        } else {
            investor_info.add_wallet<T>(
                auth,
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

    let wallet = Wallet {
        owner: investor_id,
        creator: ctx.sender(),
    };
    investor_info.investor_wallets.add(wallet_addr, wallet);
    investor_info.investors.borrow_mut(investor_id).wallets.push_back(wallet_addr);
    event::emit( WalletAdded<T> {
        wallet: wallet_addr,
        investor_id,
        sender: ctx.sender()
    });
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
    assert!(investor_info.investor_wallets.borrow(wallet_addr).owner == investor_id, EWalletDoesNotBelongToInvestor);

    investor_info.investor_wallets.remove(wallet_addr);
    let mut wallets = investor_info.investors.borrow_mut(investor_id).wallets;
    let idx = wallets.find_index!(|k| k == wallet_addr).destroy_or!(abort EWalletNotFound);
    wallets.remove(idx);
    event::emit( WalletRemoved<T> {
        wallet: wallet_addr,
        investor_id,
        sender: ctx.sender()
    });
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
    event::emit(InvestorCountryChanged<T> {
        investor_id,
        country,
        sender: ctx.sender(),
    });
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
    event::emit(
        AttributeChanged<T> {
            investor_id,
            attribute_id,
            value: attribute_value,
            expiry: attribute_expiration,
            sender: ctx.sender(),
        }
    )
}

// ==== View Functions ====

/// Returns whether an investor exists in the registry.
public fun is_investor<T>(
    investor_info: &InvestorInfo<T>,
    investor_id: String,
): bool {
    investor_info.investors.contains(investor_id)
}

/// Returns whether a wallet is registered in the registry.
public fun is_wallet<T>(
    investor_info: &InvestorInfo<T>,
    wallet: address,
): bool {
    investor_info.investor_wallets.contains(wallet)
}

/// Returns whether a wallet is a special wallet (e.g., treasury, reserve).
public fun is_special_wallet<T>(
    investor_info: &InvestorInfo<T>,
    wallet: address
): bool {
    investor_info.special_wallets.contains(wallet)
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

/// Returns whether an investor has accredited status.
public fun is_accredited_investor_by_id<T>(
    investor_info: &InvestorInfo<T>,
    investor_id: String,
): bool {
    investor_info.get_attribute_value(investor_id, ACCREDITED) == APPROVED
}

/// Returns whether an investor has qualified status.
public fun is_qualified_investor_by_id<T>(
    investor_info: &InvestorInfo<T>,
    investor_id: String,
): bool {
    investor_info.get_attribute_value(investor_id, QUALIFIED) == APPROVED
}

/// Returns the compliance region for a given country code.
public fun get_country_compliance<T>(
    investor_info: &InvestorInfo<T>,
    country: String,
): u64 {
    *investor_info.countries_compliances.borrow(country)
}

/// Returns the value of a specific attribute for an investor.
/// Returns 0 if the investor or attribute does not exist.
public fun get_attribute_value<T>(
    investor_info: &InvestorInfo<T>,
    investor_id: String,
    attribute_id: u64,
): u64 {
    if (!investor_info.is_investor(investor_id)) {
        return 0
    };
    let investor = investor_info.investors.borrow(investor_id);
    if (!investor.attributes.contains(attribute_id)) {
        return 0
    };
    investor.attributes.borrow(attribute_id).value
}

// ==== Internal Functions ====

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

// Adjusts compliance counters for a specific country.
// Updates accredited, US, EU retail, and JP investor counts based on
// the investor's accreditation/qualification status and country compliance region.
fun adjust_investors_counts_by_country<T>(
    investor_info: &mut InvestorInfo<T>,
    investor_id: String,
    country: String,
    increase: bool,
) {
    let country_compliance = investor_info.get_country_compliance(country);
    if (investor_info.is_accredited_investor_by_id(investor_id)) {
        if (increase) {
            investor_info.accredited_investors_count = investor_info.accredited_investors_count + 1;
        } else {
            investor_info.accredited_investors_count = investor_info.accredited_investors_count - 1;
        };
        if (country_compliance == US) {
            if (increase) {
                investor_info.us_accredited_investors_count = investor_info.us_accredited_investors_count + 1;
            } else {
                investor_info.us_accredited_investors_count = investor_info.us_accredited_investors_count - 1;
            };
        };
    };
    if (country_compliance == US) {
        if (increase) {
            investor_info.us_investors_count = investor_info.us_investors_count + 1;
        } else {
            investor_info.us_investors_count = investor_info.us_investors_count - 1;
        };
    } else if (country_compliance == EU && !investor_info.is_qualified_investor_by_id(investor_id)) {
        let count = investor_info.eu_retail_investors_count.borrow_mut(country);
        if (increase) {
            *count = *count + 1;
        } else {
            *count = *count - 1;
        };
    } else if (country_compliance == JP) {
        if (increase) {
            investor_info.jp_investors_count = investor_info.jp_investors_count + 1;
        } else {
            investor_info.jp_investors_count = investor_info.jp_investors_count - 1;
        };
    };
}