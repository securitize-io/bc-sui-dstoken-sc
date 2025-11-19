module securitize::setup;

use sui::coin_registry::{CurrencyInitializer};
use sui::coin::{TreasuryCap};
use sui::vec_set::{Self, VecSet};

/// Error code when the caller is not a registered deployer
const ENotDeployer: u64 = 0;
/// Error code when the caller is not the admin
const ENotAdmin: u64 = 1;

/// Registry that tracks authorized deployers and the admin for new ds token deployments.
public struct SetupAuth has key {
    id: UID,
    /// Set of addresses authorized to deploy tokens
    deployers: VecSet<address>,
    /// Admin address with permission to add/remove deployers
    /// TODO: consider making this a vector for multi-admin support (need to ask Securitize)
    admin: address,
}

/// Initializes the SetupAuth on module publish.
/// The deployer of this module becomes both the first deployer and the admin.
fun init(ctx: &mut TxContext) {
    let registry = SetupAuth {
        id: object::new(ctx),
        deployers: vec_set::singleton(ctx.sender()),
        admin: ctx.sender(),
    };
    transfer::share_object(registry);
}

/// Sets up a new securitized token system for the given coin type T.
/// This function validates that the caller is an authorized deployer and initializes
/// the treasury, investor registry, and compliance modules for the token.
///
/// # Aborts
/// * `ENotDeployer` - If the caller is not in the authorized deployers list
public fun setup<T: key>(
    registry: &SetupAuth,
    currency: CurrencyInitializer<T>,
    _treasury_cap: TreasuryCap<T>,
    ctx: &mut TxContext,
) {
    assert!(registry.deployers.contains(&ctx.sender()), ENotDeployer);
    let _metadata_cap = currency.finalize(ctx);
    // TODO: enable once modules are ready
    // treasury::new<T>(treasury_cap, metadata_cap, ctx);
    // investors::new<T>(ctx);
    // compliance::new<T>(ctx);
    abort
}

/// Adds a new address to the list of authorized deployers.
/// Only the admin can call this function.
///
/// # Aborts
/// * `ENotAdmin` - If the caller is not the admin
public fun add_deployer(
    registry: &mut SetupAuth,
    new_deployer: address,
    ctx: &mut TxContext,
) {
    assert!(registry.admin == ctx.sender(), ENotAdmin);
    registry.deployers.insert(new_deployer);
}

/// Removes an address from the list of authorized deployers.
/// Only the admin can call this function.
///
/// # Aborts
/// * `ENotAdmin` - If the caller is not the admin
public fun remove_deployer(
    registry: &mut SetupAuth,
    deployer: address,
    ctx: &mut TxContext,
) {
    assert!(registry.admin == ctx.sender(), ENotAdmin);
    registry.deployers.remove(&deployer);
}

/// Switches the admin to a new address.
/// Only the current admin can call this function.
/// 
/// # Aborts
/// * `ENotAdmin` - If the caller is not the admin
public fun switch_admin(
    registry: &mut SetupAuth,
    new_admin: address,
    ctx: &mut TxContext,
) {
    assert!(registry.admin == ctx.sender(), ENotAdmin);
    registry.admin = new_admin;
}

/// Checks if the given address is an authorized deployer.
public fun is_deployer(
    registry: &SetupAuth,
    addr: address,
): bool {
    registry.deployers.contains(&addr)
}

/// Test-only function to initialize the SetupAuth in test environments.
#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx);
}