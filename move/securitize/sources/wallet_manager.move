/// Module: wallet_manager
///
/// This module manages special wallets for security tokens.
/// Special wallets are designated addresses Issuer, Platform that have
/// special privileges in the token ecosystem and are not associated with regular investors.
module securitize::wallet_manager;

use pas::{namespace::Namespace, vault};
use securitize::{
    abilities::{SetIssuerWallet, SetPlatformWallet, RemoveSpecialWallet},
    registry_service::InvestorInfo,
    trust_service::{Auth, Master, Issuer},
    version::Version
};
use sui::event;

// ==== Constants ====

/// Wallet type identifier for issuer wallets
const ISSUER: u64 = 1;
/// Wallet type identifier for platform wallets
const PLATFORM: u64 = 2;

// ==== Error Codes ====

/// The input wallet address belongs to an investor
const EWalletBelongsToInvestor: u64 = 0;
/// Direct wallet type change is not allowed
const EDirectWalletChange: u64 = 1;
/// The input wallet is not a special wallet
const ENotSpecialWallet: u64 = 2;
/// The caller is not authorized to perform this action
const ENotAuthorized: u64 = 3;

// ==== Events ====

/// Emitted when a special wallet is added to the registry
public struct DSWalletManagerSpecialWalletAdded<phantom T> has copy, drop {
    wallet: address,
    wallet_type: u64,
    caller: address,
}

/// Emitted when a special wallet is removed from the registry
public struct DSWalletManagerSpecialWalletRemoved<phantom T> has copy, drop {
    wallet: address,
    old_type: u64,
    caller: address,
}

/// Initializes the Wallet Manager abilities for the given token type T.
/// Called by the setup module during token deployment.
public(package) fun new<T: key>(auth: &mut Auth<T>, version: &Version, ctx: &TxContext) {
    // Assign abilities to roles
    auth.add_role_ability<T, Master, SetIssuerWallet>(version, ctx);
    auth.add_role_ability<T, Master, SetPlatformWallet>(version, ctx);
    auth.add_role_ability<T, Master, RemoveSpecialWallet>(version, ctx);

    auth.add_role_ability<T, Issuer, SetIssuerWallet>(version, ctx);
    auth.add_role_ability<T, Issuer, SetPlatformWallet>(version, ctx);
    auth.add_role_ability<T, Issuer, RemoveSpecialWallet>(version, ctx);
}

/// Adds a wallet address as an issuer wallet.
/// Only authorized addresses with the SetIssuerWallet ability can call this function.
///
/// # Aborts
/// * `ENotAuthorized` - If caller lacks SetIssuerWallet ability
/// * `EWalletBelongsToInvestor` - If the wallet belongs to an investor
/// * `EDirectWalletChange` - If the wallet is already a special wallet
public fun add_issuer_wallet<T>(
    investor_info: &mut InvestorInfo<T>,
    auth: &Auth<T>,
    namespace: &mut Namespace,
    wallet: address,
    version: &Version,
    ctx: &mut TxContext,
) {
    version.check_is_valid();
    assert!(auth.owner_has_ability<T, SetIssuerWallet>(ctx.sender()), ENotAuthorized);
    set_special_wallet(investor_info, namespace, wallet, ISSUER, ctx);
}

/// Adds a wallet address as a platform wallet.
/// Only authorized addresses with the SetPlatformWallet ability can call this function.
///
/// # Aborts
/// * `ENotAuthorized` - If caller lacks SetPlatformWallet ability
/// * `EWalletBelongsToInvestor` - If the wallet belongs to an investor
/// * `EDirectWalletChange` - If the wallet is already a special wallet
public fun add_platform_wallet<T>(
    investor_info: &mut InvestorInfo<T>,
    auth: &Auth<T>,
    namespace: &mut Namespace,
    wallet: address,
    version: &Version,
    ctx: &mut TxContext,
) {
    version.check_is_valid();
    assert!(auth.owner_has_ability<T, SetPlatformWallet>(ctx.sender()), ENotAuthorized);
    set_special_wallet(investor_info, namespace, wallet, PLATFORM, ctx);
}

/// Removes a special wallet from the registry.
/// Only authorized addresses with the RemoveSpecialWallet ability can call this function.
///
/// # Aborts
/// * `ENotAuthorized` - If caller lacks RemoveSpecialWallet ability
/// * `ENotSpecialWallet` - If the wallet is not a special wallet
public fun remove_special_wallet<T>(
    investor_info: &mut InvestorInfo<T>,
    auth: &Auth<T>,
    wallet: address,
    version: &Version,
    ctx: &mut TxContext,
) {
    version.check_is_valid();
    assert!(auth.owner_has_ability<T, RemoveSpecialWallet>(ctx.sender()), ENotAuthorized);
    assert!(investor_info.is_special_wallet(wallet), ENotSpecialWallet);
    let old_type = investor_info.remove_special_wallet(wallet);
    event::emit(DSWalletManagerSpecialWalletRemoved<T> {
        wallet,
        old_type,
        caller: ctx.sender(),
    });
}

/// Internal function to set a special wallet with the given type.
/// Validates that the wallet is not already an investor wallet or special wallet.
fun set_special_wallet<T>(
    investor_info: &mut InvestorInfo<T>,
    namespace: &mut Namespace,
    wallet: address,
    wallet_type: u64,
    ctx: &TxContext,
) {
    assert!(!investor_info.is_wallet(wallet), EWalletBelongsToInvestor);
    assert!(!investor_info.is_special_wallet(wallet), EDirectWalletChange);
    if (!vault::exists(namespace, wallet)) {
        vault::create_and_share(namespace, wallet);
    };
    investor_info.set_special_wallet(wallet, wallet_type);
    event::emit(DSWalletManagerSpecialWalletAdded<T> {
        wallet,
        wallet_type,
        caller: ctx.sender(),
    });
}

// ==== View Functions ====

/// Returns whether the given wallet is a platform wallet.
public fun is_platform_wallet<T>(investor_info: &InvestorInfo<T>, wallet: address): bool {
    investor_info.get_special_wallet_type(wallet) == PLATFORM
}

/// Returns whether the given wallet is an issuer wallet.
public fun is_issuer_wallet<T>(investor_info: &InvestorInfo<T>, wallet: address): bool {
    investor_info.get_special_wallet_type(wallet) == ISSUER
}
