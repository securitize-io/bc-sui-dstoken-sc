module securitize::ds_token;

use sui::{coin::TreasuryCap, coin_registry::MetadataCap, dynamic_object_field as dof};
use securitize::version::Version;

// ==== Error Codes ====

/// Error code when attempting to pause an already paused treasury
const ETreasuryAlreadyPaused: u64 = 0;
/// Error code when attempting to unpause a treasury that is not paused
const ETreasuryNotPaused: u64 = 1;

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
    treasury_cap: TreasuryCap<T>,
    metadata_cap: MetadataCap<T>,
    ctx: &mut TxContext,
) {
    let mut treasury = Treasury {
        id: object::new(ctx),
        metadata_cap,
        paused: false,
    };
    dof::add(&mut treasury.id, TreasuryCapKey(), treasury_cap);
    transfer::share_object(treasury);
}

// ==== Public Functions ====

/// Returns a reference to the MetadataCap for the treasury.
/// This allows authorized parties to update the token's metadata
/// (name, description, icon_url) in a PTB.
///
/// TODO: Decide if we want to return the metadata so that it can be used in a PTB to
///       update name, description and icon_url or if we want to call the update functions here directly
///       with event emitting
public fun metadata_cap<T: key>(
    treasury: &Treasury<T>,
    version: &Version,
    // auth: &Auth,
    ctx: &mut TxContext,
): &MetadataCap<T> {
    version.check_is_valid();
    // assert that caller has the right auth if needed
    &treasury.metadata_cap
}

/// Pauses the treasury, preventing token operations.
/// Only authorized addresses should be able to call this function.
///
/// # Aborts
/// * `ETreasuryAlreadyPaused` - If the treasury is already paused
public fun pause<T: key>(
    treasury: &mut Treasury<T>,
    version: &Version,
    // auth: &Auth,
    ctx: &mut TxContext,
) {
    version.check_is_valid();
    assert!(!treasury.is_paused(), ETreasuryAlreadyPaused);
    treasury.paused = true;
}

/// Unpauses the treasury, allowing token operations to resume.
/// Only authorized addresses should be able to call this function.
///
/// # Aborts
/// * `ETreasuryNotPaused` - If the treasury is not currently paused
public fun unpause<T: key>(
    treasury: &mut Treasury<T>,
    version: &Version,
    // auth: &Auth,
    ctx: &mut TxContext,
) {
    version.check_is_valid();
    assert!(treasury.is_paused(), ETreasuryNotPaused);
    treasury.paused = false;
}

// ==== View Functions ====

/// Returns whether the treasury is currently paused.
public fun is_paused<T: key>(treasury: &Treasury<T>): bool {
    treasury.paused
}
