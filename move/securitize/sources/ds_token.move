module securitize::ds_token;

use sui::{coin::TreasuryCap, coin_registry::MetadataCap, dynamic_object_field as dof, event, derived_object};
use std::string::{Self, String};
use securitize::{version::Version, trust_service::{Auth, Master, Issuer, TransferAgent}};
use rwa::vault::{RwaVault, RwaTransferRequest, VaultOwnerProof};
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
    ctx: &mut TxContext,
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
    // investors: &InvestorRegistry,
    rwa_rule: &RwaRule<T>,
    to: &mut RwaVault,
    to_address: address,
    amount: u64,
    version: &Version,
    ctx: &mut TxContext,
) {
    version.check_is_valid();
    assert!(auth.owner_has_ability<T, IssueTokens>(ctx.sender()), ENotAuthorized);
    assert!(to.owner_address() == to_address, EVaultOwnerMismatch);
    // TODO: Call the validation from compliance
    let balance = dof::borrow_mut<TreasuryCapKey, TreasuryCap<T>>(
        &mut treasury.id,
        TreasuryCapKey(),
    ).mint_balance(amount);
    // Deposit to the investor's vault
    rule::deposit_to_vault(
        rwa_rule,
        to,
        balance,
        DsProtocol(),
    );
    event::emit(
        Issue<T> {
            to: to_address,
            value: amount,
            value_locked: 0, //placeholder
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
    // investors: &InvestorRegistry,
    rwa_rule: &RwaRule<T>,
    owner_proof: &VaultOwnerProof,
    from: &mut RwaVault,
    from_address: address,
    amount: u64,
    version: &Version,
    ctx: &mut TxContext,
) {
    version.check_is_valid();
    assert!(auth.owner_has_ability<T, BurnTokens>(ctx.sender()), ENotAuthorized);
    assert!(from.owner_address() == from_address, EVaultOwnerMismatch);
    // TODO: Call the validation from compliance
    let balance = rule::unlock_from_vault(
        rwa_rule,
        from,
        owner_proof,
        amount,
        DsProtocol(),
    );
    // Burn the balance
    dof::borrow_mut<TreasuryCapKey, TreasuryCap<T>>(
        &mut treasury.id,
        TreasuryCapKey(),
    ).burn(balance.into_coin(ctx));
    event::emit(
        Burn<T> {
            burner: ctx.sender(),
            value: amount,
            reason: string::utf8(b""), // Placeholder
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
    // investors: &InvestorRegistry,
    rwa_rule: &RwaRule<T>,
    from: &mut RwaVault,
    from_address: address,
    to: &mut RwaVault, // TODO: determine if we want to store the address in the treasury
    amount: u64,
    version: &Version,
    ctx: &mut TxContext,
) {
    version.check_is_valid();
    assert!(auth.owner_has_ability<T, SeizeTokens>(ctx.sender()), ENotAuthorized);
    assert!(from.owner_address() == from_address, EVaultOwnerMismatch);
    // TODO: Call the validation from compliance
    // Withdraw from the investor's vault and deposit to the treasury's vault
    rule::clawback_to_vault(
        rwa_rule,
        from,
        to,
        amount,
        DsProtocol(),
    );
    event::emit(
        Seize<T> {
            from: from_address,
            to: @0x0, // Placeholder
            value: amount,
            reason: string::utf8(b""), // Placeholder
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
    // investors: &InvestorRegistry,
    rwa_rule: &RwaRule<T>,
    request: RwaTransferRequest<T>,
    version: &Version,
    ctx: &mut TxContext,
) {
    version.check_is_valid();
    assert!(!treasury.is_paused(), ETreasuryPaused);
    // TODO: Call the validation from compliance
    // Resolve the request
    rule::resolve_transfer(rwa_rule, request, DsProtocol());
    event::emit(
        Transfer<T> {
            from: /* request.from_address */ ctx.sender(), // Placeholder
            to: /* request.to_address */ ctx.sender(), // Placeholder
            value: /* request.amount */ 0, // Placeholder
        }
    );
}

/// Returns a reference to the MetadataCap for the treasury.
/// This allows authorized parties to update the token's metadata
/// (name, description, icon_url) in a PTB.
///
/// TODO: Decide if we want to return the metadata so that it can be used in a PTB to
///       update name, description and icon_url or if we want to call the update functions here directly
///       with event emitting
public fun metadata_cap<T>(
    treasury: &Treasury<T>,
    auth: &Auth<T>,
    version: &Version,
    ctx: &mut TxContext,
): &MetadataCap<T> {
    version.check_is_valid();
    assert!(auth.owner_has_ability<T, MetadataUpdate>(ctx.sender()), ENotAuthorized);
    &treasury.metadata_cap
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
