/// Module: wallet_manager
///
/// This module manages special wallets for security tokens.
/// Special wallets are designated addresses Issuer, Platform that have
/// special privileges in the token ecosystem and are not associated with regular investors.
module securitize::wallet_manager;

use pas::{namespace::Namespace, vault};
use securitize::{
    abilities::{SetIssuerWallet, SetPlatformWallet, RemoveSpecialWallet},
    events::{emit_special_wallet_added_event, emit_special_wallet_removed_event},
    registry_service::InvestorInfo,
    trust_service::{Auth, Master, Issuer},
    version::Version
};

// ==== Constants ====

/// Wallet type identifier for issuer wallets
const ISSUER: u64 = 1;
/// Wallet type identifier for platform wallets
const PLATFORM: u64 = 2;

// ==== Error Codes ====

#[error(code = 0)]
const EWalletBelongsToInvestor: vector<u8> = b"Wallet address belongs to an investor";
#[error(code = 1)]
const EDirectWalletChange: vector<u8> = b"Direct wallet type change is not allowed";
#[error(code = 2)]
const ENotSpecialWallet: vector<u8> = b"Wallet is not a special wallet";
#[error(code = 3)]
const ENotAuthorized: vector<u8> = b"Caller is not authorized to perform this action";

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
    emit_special_wallet_removed_event<T>(wallet, old_type, ctx.sender());
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
    if (!namespace.vault_exists(wallet)) {
        vault::create_and_share(namespace, wallet);
    };
    investor_info.set_special_wallet(wallet, wallet_type);
    emit_special_wallet_added_event<T>(wallet, wallet_type, ctx.sender());
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
