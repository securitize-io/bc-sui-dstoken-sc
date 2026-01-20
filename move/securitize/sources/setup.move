/// Module: setup
///
/// Handles the initialization and deployment of new DS Token instances.
/// Manages authorized deployers and provides the entry point for creating
/// new security tokens with their associated services.
module securitize::setup;

use pas::namespace::Namespace;
use securitize::{
    compliance_service::{Self, ComplianceConfig},
    ds_token::{Self, Treasury},
    events::{emit_deployer_added_event, emit_deployer_removed_event, emit_admin_switched_event},
    lock_manager,
    registry_service::{Self, InvestorInfo},
    trust_service::{Self, Auth},
    version::Version,
    wallet_manager
};
use sui::{coin::TreasuryCap, coin_registry::CurrencyInitializer, vec_set::{Self, VecSet}};

// ==== Error Codes ====

#[error(code = 0)]
const ENotDeployer: vector<u8> = b"Caller is not a registered deployer";
#[error(code = 1)]
const ENotAdmin: vector<u8> = b"Caller is not the admin";

// ==== Structs ====

/// Registry that tracks authorized deployers and the admin for new ds token deployments.
public struct SetupRegistry has key {
    id: UID,
    /// Set of addresses authorized to deploy tokens
    deployers: VecSet<address>,
    /// Admin address with permission to add/remove deployers
    admin: address,
}

/// Hot potato used to finalize the setup process
public struct SetupFinalize {}

/// Initializes the SetupAuth on module publish.
/// The deployer of this module becomes both the first deployer and the admin.
fun init(ctx: &mut TxContext) {
    let registry = SetupRegistry {
        id: object::new(ctx),
        deployers: vec_set::singleton(ctx.sender()),
        admin: ctx.sender(),
    };
    transfer::share_object(registry);
}

// ==== Public Functions ====

/// Sets up a new securitized token system for the given coin type T.
/// This function validates that the caller is an authorized deployer and initializes
/// the treasury, investor registry, and compliance modules for the token.
///
/// # Aborts
/// * `ENotDeployer` - If the caller is not in the authorized deployers list
public fun setup<T: key>(
    setup_registry: &mut SetupRegistry,
    namespace: &mut Namespace,
    currency: CurrencyInitializer<T>,
    rule_permit: internal::Permit<T>,
    treasury_cap: TreasuryCap<T>,
    version: &Version,
    ctx: &mut TxContext,
): (Auth<T>, Treasury<T>, InvestorInfo<T>, ComplianceConfig<T>, SetupFinalize) {
    version.check_is_valid();
    assert!(setup_registry.deployers.contains(&ctx.sender()), ENotDeployer);
    let metadata_cap = currency.finalize(ctx);
    let mut auth = trust_service::new<T>(setup_registry.uid_mut(), ctx);
    let treasury = ds_token::new<T>(
        setup_registry.uid_mut(),
        &mut auth,
        namespace,
        rule_permit,
        treasury_cap,
        metadata_cap,
        version,
        ctx,
    );
    let investor_info = registry_service::new<T>(setup_registry.uid_mut(), &mut auth, version, ctx);
    let compliance = compliance_service::new<T>(setup_registry.uid_mut(), &mut auth, version, ctx);
    wallet_manager::new<T>(&mut auth, version, ctx);
    lock_manager::new<T>(&mut auth, version, ctx);
    (auth, treasury, investor_info, compliance, SetupFinalize {})
}

/// Finalizes the setup process by sharing the Auth, Treasury, InvestorInfo
/// and ComplianceConfig objects, and by resolving the SetupFinalize hot potato.
public fun finalize_setup<T: key>(
    finalize: SetupFinalize,
    auth: Auth<T>,
    treasury: Treasury<T>,
    investor_info: InvestorInfo<T>,
    compliance: ComplianceConfig<T>,
    version: &Version,
) {
    version.check_is_valid();
    auth.share();
    treasury.share();
    investor_info.share();
    compliance.share();
    let SetupFinalize {} = finalize;
}

/// Adds a new address to the list of authorized deployers.
/// Only the admin can call this function.
///
/// # Aborts
/// * `ENotAdmin` - If the caller is not the admin
public fun add_deployer(
    registry: &mut SetupRegistry,
    deployer: address,
    version: &Version,
    ctx: &mut TxContext,
) {
    version.check_is_valid();
    assert!(registry.admin == ctx.sender(), ENotAdmin);
    registry.deployers.insert(deployer);
    emit_deployer_added_event(deployer);
}

/// Removes an address from the list of authorized deployers.
/// Only the admin can call this function.
///
/// # Aborts
/// * `ENotAdmin` - If the caller is not the admin
public fun remove_deployer(
    registry: &mut SetupRegistry,
    deployer: address,
    version: &Version,
    ctx: &mut TxContext,
) {
    version.check_is_valid();
    assert!(registry.admin == ctx.sender(), ENotAdmin);
    registry.deployers.remove(&deployer);
    emit_deployer_removed_event(deployer);
}

/// Switches the admin to a new address.
/// Only the current admin can call this function.
///
/// # Aborts
/// * `ENotAdmin` - If the caller is not the admin
public fun switch_admin(
    registry: &mut SetupRegistry,
    new_admin: address,
    version: &Version,
    ctx: &mut TxContext,
) {
    version.check_is_valid();
    assert!(registry.admin == ctx.sender(), ENotAdmin);
    registry.admin = new_admin;
    emit_admin_switched_event(ctx.sender(), new_admin);
}

// ==== View Functions ====

/// Checks if the given address is an authorized deployer.
public fun is_deployer(registry: &SetupRegistry, addr: address): bool {
    registry.deployers.contains(&addr)
}

public fun admin(registry: &SetupRegistry): address {
    registry.admin
}

// ==== Package-Private Functions ====

/// Expose `uid_mut` so we can claim derived objects from other modules.
public(package) fun uid_mut(registry: &mut SetupRegistry): &mut UID {
    &mut registry.id
}

/// Test-only function to initialize the SetupAuth in test environments.
#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx);
}
