module securitize::ds_token;

use sui::coin::{TreasuryCap};
use sui::coin_registry::{MetadataCap};

const ETreasuryAlreadyPaused: u64 = 0;
const ETreasuryNotPaused: u64 = 1;

public struct Treasury<phantom T> has key {
    id: UID,
    metadata_cap: MetadataCap<T>,
    paused: bool,
}

/// Key used to store the TreasuryCap<T> in the RwaRule<T>.
public struct TreasuryCapKey() has copy, drop, store;

public(package) fun new<T: key>(
    treasury_cap: TreasuryCap<T>,
    metadata_cap: MetadataCap<T>,
    ctx: &mut TxContext,
) {
    let treasury = Treasury {
        id: object::new(ctx),
        metadata_cap,
        paused: false,
    };
    dof::add(&mut treasury.id, TreasuryCapKey(), treasury);
    transfer::share_object(treasury);
}

// TODO: Decide if we want to return the metadata so that it can be used in a PTB to 
//       update name, description and icon_url or if we want to call the update functions here directly
//       with event emitting
public fun metadata_cap<T: key>(
    treasury: &Treasury<T>,
    // auth: &Auth,
    ctx: &mut TxContext,
): &MetadataCap<T> {
    // assert that caller has the right auth if needed
    &treasury.metadata_cap
}

public fun pause<T: key>(
    treasury: &mut Treasury<T>,
    // auth: &Auth,
    ctx: &mut TxContext,
) {
    assert!(!treasury.is_paused(), ETreasuryAlreadyPaused);
    treasury.paused = true;
}

public fun unpause<T: key>(
    treasury: &mut Treasury<T>,
    // auth: &Auth,
    ctx: &mut TxContext,
) {
    assert!(treasury.is_paused(), ETreasuryNotPaused);
    treasury.paused = false;
}

public fun is_paused<T: key>(treasury: &Treasury<T>): bool {
    treasury.paused
}