/// Module: trust_service
///
/// This is the main module for role management. The core structure here is Auth
/// as an independent shared object.
/// three main administrative roles: Master, Issuer, and TransferAgent.
module securitize::trust_service;

use securitize::{
    abilities::{
        SetRoleTypes,
        SetAbilities,
        SetServiceOwner,
        SetIssuer,
        SetTransferAgent,
        SetExchange
    },
    events::{emit_role_added_event, emit_role_removed_event},
    version::Version
};
use std::type_name::{Self, TypeName};
use sui::{bag::{Self, Bag}, derived_object, vec_map::{Self, VecMap}, vec_set::{Self, VecSet}};

// ==== Error Codes ====

#[error(code = 0)]
const EDirectRoleToRoleChange: vector<u8> = b"Direct role to role change is not allowed";
#[error(code = 1)]
const ECannotRemoveMaster: vector<u8> = b"Cannot remove master role";
#[error(code = 2)]
const ENotEnoughPermissions: vector<u8> = b"Caller does not have sufficient permissions";
#[error(code = 3)]
const ESelfTransferNotAllowed: vector<u8> = b"Cannot transfer ownership to self";
#[error(code = 4)]
const EOwnerHasNoRole: vector<u8> = b"Owner has no role assigned";
#[error(code = 5)]
const ERoleNotFound: vector<u8> = b"Role type not found in the system";
#[error(code = 6)]
const ERoleTypeMismatch: vector<u8> = b"Role type mismatch - stored role doesn't match expected";
#[error(code = 7)]
const ERoleAbilitiesNotFound: vector<u8> = b"Role abilities mapping not found";
#[error(code = 8)]
const EAbilityAlreadyExists: vector<u8> = b"Ability already exists for this role";
#[error(code = 9)]
const EAbilityNotFound: vector<u8> = b"Ability not found for this role";
#[error(code = 10)]
const ERoleAlreadyExists: vector<u8> = b"Role type already exists";
#[error(code = 11)]
const ERoleHasActiveMembers: vector<u8> = b"Role has active members and cannot be removed";

public struct TrustServiceKey<phantom T>() has copy, drop, store;

// ==================== Structs ====================

/// Authorization structure for role and ability management
public struct Auth<phantom T> has key {
    id: UID,
    // Roles and owners counter
    roles: VecMap<TypeName, u32>,
    /// Abilities are witness types mapped per role
    roles_abilities: VecMap<TypeName, VecSet<TypeName>>,
    /// Role keys registry (Bag of AddressKey structs)
    roles_owners: Bag,
}

/// Key structure for identifying role ownership
public struct AddressKey has copy, drop, store {
    owner: address,
}

// ==================== Roles ====================

/// Master role witness
public struct Master has drop {}
/// Issuer role witness
public struct Issuer has drop {}
/// TransferAgent role witness
public struct TransferAgent has drop {}
/// Exchange role Witness
public struct Exchange has drop {}
/// None role Witness
public struct None has drop {}

// ==================== Initialization Functions ====================

/// Create new Auth shared object for type T
/// This should be called during initialization and the Auth object should be shared
public(package) fun new<T>(uid: &mut UID, ctx: &mut TxContext): Auth<T> {
    // Initialize roles VecMap with Master, Issuer, TransferAgent roles
    let mut roles = vec_map::empty();
    roles.insert(type_name::with_defining_ids<Master>(), 0);
    roles.insert(type_name::with_defining_ids<Issuer>(), 0);
    roles.insert(type_name::with_defining_ids<TransferAgent>(), 0);
    roles.insert(type_name::with_defining_ids<Exchange>(), 0);

    // Initialize roles_abilities VecMap
    let mut roles_abilities = vec_map::empty();

    // Add all abilities to Master role, including role TypeNames
    let mut master_abilities = vec_set::empty();
    master_abilities.insert(type_name::with_defining_ids<SetAbilities>());
    master_abilities.insert(type_name::with_defining_ids<SetRoleTypes>());

    // Add role TypeNames as abilities (Master can set all roles)
    master_abilities.insert(type_name::with_defining_ids<SetServiceOwner>());
    master_abilities.insert(type_name::with_defining_ids<SetIssuer>());
    master_abilities.insert(type_name::with_defining_ids<SetTransferAgent>());
    master_abilities.insert(type_name::with_defining_ids<SetExchange>());
    roles_abilities.insert(type_name::with_defining_ids<Master>(), master_abilities);

    // Add TransferAgent role TypeName as ability to TransferAgent role
    let mut transfer_agent_abilities = vec_set::empty();
    transfer_agent_abilities.insert(type_name::with_defining_ids<SetTransferAgent>());
    roles_abilities.insert(type_name::with_defining_ids<TransferAgent>(), transfer_agent_abilities);

    // Add Issuer role TypeName as ability to Issuer role
    let mut issuer_abilities = vec_set::empty();
    issuer_abilities.insert(type_name::with_defining_ids<SetIssuer>());
    issuer_abilities.insert(type_name::with_defining_ids<SetExchange>());
    roles_abilities.insert(type_name::with_defining_ids<Issuer>(), issuer_abilities);

    // Add Exchange abilities set
    let exchange_abilities = vec_set::empty();
    roles_abilities.insert(type_name::with_defining_ids<Exchange>(), exchange_abilities);

    let mut auth = Auth<T> {
        id: derived_object::claim(uid, TrustServiceKey<T>()),
        roles,
        roles_abilities,
        roles_owners: bag::new(ctx),
    };

    // Assign initial Master
    internal_assign_role<T, Master>(&mut auth, ctx.sender(), ctx);
    auth
}

// ==================== Role Management Functions ====================

/// Returns the role TypeName for the given address.
/// If no role is assigned, returns the TypeName of `None`.
public fun get_role<T>(self: &Auth<T>, owner: address): TypeName {
    let owner_key = AddressKey { owner };
    if (self.roles_owners.contains(owner_key)) {
        *self.roles_owners.borrow(owner_key)
    } else {
        type_name::with_defining_ids<None>()
    }
}

/// Set/grant a role Exchange to an owner address.
/// Creates an AddressKey and stores it in the roles Bag.
///
/// # Aborts
/// * `ENotEnoughPermissions` - If the sender does not have the SetExchange ability
public fun set_exchange<T>(
    self: &mut Auth<T>,
    owner: address,
    version: &Version,
    ctx: &mut TxContext,
) {
    version.check_is_valid();
    assert!(owner_has_ability<T, SetExchange>(self, ctx.sender()), ENotEnoughPermissions);
    internal_assign_role<T, Exchange>(self, owner, ctx);
}

/// Remove a role Exchange from an owner address.
///
/// # Aborts
/// * `ENotEnoughPermissions` - If the sender does not have the SetExchange ability
public fun remove_exchange<T>(
    self: &mut Auth<T>,
    owner: address,
    version: &Version,
    ctx: &mut TxContext,
) {
    version.check_is_valid();
    assert!(owner_has_ability<T, SetExchange>(self, ctx.sender()), ENotEnoughPermissions);
    internal_remove_role<T, Exchange>(self, owner, ctx);
}

/// Set/grant a role TransferAgent to an owner address.
/// Creates an AddressKey and stores it in the roles Bag.
///
/// # Aborts
/// * `ENotEnoughPermissions` - If the sender does not have the SetTransferAgent ability
public fun set_transfer_agent<T>(
    self: &mut Auth<T>,
    owner: address,
    version: &Version,
    ctx: &mut TxContext,
) {
    version.check_is_valid();
    assert!(owner_has_ability<T, SetTransferAgent>(self, ctx.sender()), ENotEnoughPermissions);
    internal_assign_role<T, TransferAgent>(self, owner, ctx);
}

/// Remove a role TransferAgent from an owner address.
///
/// # Aborts
/// * `ENotEnoughPermissions` - If the sender does not have the SetTransferAgent ability
public fun remove_transfer_agent<T>(
    self: &mut Auth<T>,
    owner: address,
    version: &Version,
    ctx: &mut TxContext,
) {
    version.check_is_valid();
    assert!(owner_has_ability<T, SetTransferAgent>(self, ctx.sender()), ENotEnoughPermissions);
    internal_remove_role<T, TransferAgent>(self, owner, ctx);
}

/// Set/grant a role Issuer to an owner address.
/// Creates an AddressKey and stores it in the roles Bag.
///
/// # Aborts
/// * `ENotEnoughPermissions` - If the sender does not have the SetIssuer ability
public fun set_issuer<T>(
    self: &mut Auth<T>,
    owner: address,
    version: &Version,
    ctx: &mut TxContext,
) {
    version.check_is_valid();
    assert!(owner_has_ability<T, SetIssuer>(self, ctx.sender()), ENotEnoughPermissions);
    internal_assign_role<T, Issuer>(self, owner, ctx);
}

/// Remove a role Issuer from an owner address.
///
/// # Aborts
/// * `ENotEnoughPermissions` - If the sender does not have the SetIssuer ability
public fun remove_issuer<T>(
    self: &mut Auth<T>,
    owner: address,
    version: &Version,
    ctx: &mut TxContext,
) {
    version.check_is_valid();
    assert!(owner_has_ability<T, SetIssuer>(self, ctx.sender()), ENotEnoughPermissions);
    internal_remove_role<T, Issuer>(self, owner, ctx);
}

/// Set/transfer service ownership (reassigns Master role).
///
/// # Aborts
/// * `ESelfTransferNotAllowed` - If attempting to transfer ownership to self
/// * `ENotEnoughPermissions` - If the sender does not have the SetServiceOwner ability
public fun set_service_owner<T>(
    self: &mut Auth<T>,
    owner: address,
    version: &Version,
    ctx: &mut TxContext,
) {
    version.check_is_valid();
    assert!(ctx.sender() != owner, ESelfTransferNotAllowed);
    assert!(owner_has_ability<T, SetServiceOwner>(self, ctx.sender()), ENotEnoughPermissions);
    internal_remove_role<T, Master>(self, ctx.sender(), ctx);
    internal_assign_role<T, Master>(self, owner, ctx);
}

/// Set/grant a role R to an owner address
/// Creates an AddressKey and stores it in the roles Bag
public(package) fun internal_assign_role<T, R: drop>(
    self: &mut Auth<T>,
    owner: address,
    ctx: &TxContext,
) {
    let roles_type = type_name::with_defining_ids<R>();
    assert!(self.roles.contains(&roles_type), ERoleNotFound);

    // Assert if the address already has a role
    let owner_key = AddressKey { owner };
    assert!(!self.roles_owners.contains(owner_key), EDirectRoleToRoleChange);

    // Add role R and increment counter
    self.roles_owners.add(owner_key, roles_type);
    *self.roles.get_mut(&roles_type) = *self.roles.get_mut(&roles_type) + 1;

    // Emit event
    emit_role_added_event<T>(owner, roles_type, ctx.sender());
}

/// Remove a role R from an owner address
public(package) fun internal_remove_role<T, R: drop>(
    self: &mut Auth<T>,
    owner: address,
    ctx: &TxContext,
) {
    let roles_type = type_name::with_defining_ids<R>();

    // Assert if the address doesn't have a role
    let owner_key = AddressKey { owner };
    assert!(self.roles_owners.contains(owner_key), EOwnerHasNoRole);

    // Remove addresskey from roles_owners and decrement counter
    let stored_role: TypeName = self.roles_owners.remove(owner_key);
    assert!(stored_role == roles_type, ERoleTypeMismatch);
    *self.roles.get_mut(&roles_type) = *self.roles.get_mut(&roles_type) - 1;

    // Emit event
    emit_role_removed_event<T>(owner, roles_type, ctx.sender());
}

// ==================== Ability Management Functions ====================

/// Add an ability A to role R.
/// This grants all holders of role R the ability to perform actions requiring A.
///
/// # Aborts
/// * `ENotEnoughPermissions` - If the sender does not have the SetAbilities ability
/// * `ERoleNotFound` - If the role type R is not registered
/// * `ERoleAbilitiesNotFound` - If the role's abilities mapping is not found
/// * `EAbilityAlreadyExists` - If the ability A is already assigned to role R
public fun add_role_ability<T, R: drop, A: drop>(
    self: &mut Auth<T>,
    version: &Version,
    ctx: &TxContext,
) {
    version.check_is_valid();
    assert!(owner_has_ability<T, SetAbilities>(self, ctx.sender()), ENotEnoughPermissions);

    let roles_type = type_name::with_defining_ids<R>();
    let ability_type = type_name::with_defining_ids<A>();

    assert!(self.roles.contains(&roles_type), ERoleNotFound);
    assert!(self.roles_abilities.contains(&roles_type), ERoleAbilitiesNotFound);

    // Add Ability
    let abilities = self.roles_abilities.get_mut(&roles_type);
    assert!(!abilities.contains(&ability_type), EAbilityAlreadyExists);
    abilities.insert(ability_type);
}

/// Remove an ability A from role R.
/// This revokes the ability to perform actions requiring A from all holders of role R.
///
/// # Aborts
/// * `ENotEnoughPermissions` - If the sender does not have the SetAbilities ability
/// * `ECannotRemoveMaster` - If attempting to remove SetAbilities from Master role
/// * `ERoleNotFound` - If the role type R is not registered
/// * `ERoleAbilitiesNotFound` - If the role's abilities mapping is not found
/// * `EAbilityNotFound` - If the ability A is not found for role R
public fun remove_role_ability<T, R: drop, A: drop>(
    self: &mut Auth<T>,
    version: &Version,
    ctx: &TxContext,
) {
    version.check_is_valid();
    assert!(owner_has_ability<T, SetAbilities>(self, ctx.sender()), ENotEnoughPermissions);

    let roles_type = type_name::with_defining_ids<R>();
    let ability_type = type_name::with_defining_ids<A>();

    // Prevent removing SetAbilities from Master role
    assert!(
        !(
            roles_type == type_name::with_defining_ids<Master>() && ability_type == type_name::with_defining_ids<SetAbilities>(),
        ),
        ECannotRemoveMaster,
    );
    assert!(self.roles.contains(&roles_type), ERoleNotFound);
    assert!(self.roles_abilities.contains(&roles_type), ERoleAbilitiesNotFound);

    // Remove Ability
    let abilities = self.roles_abilities.get_mut(&roles_type);
    assert!(abilities.contains(&ability_type), EAbilityNotFound);
    abilities.remove(&ability_type);
}

/// Check if role R has ability A
public(package) fun role_has_ability<T, R: drop, A: drop>(self: &Auth<T>): bool {
    let roles_type = type_name::with_defining_ids<R>();
    let ability_type = type_name::with_defining_ids<A>();
    if (!self.roles_abilities.contains(&roles_type)) {
        return false
    };
    let abilities = self.roles_abilities.get(&roles_type);
    abilities.contains(&ability_type)
}

/// Check if an owner address has ability A through their role
/// This is a combined check: does the owner have a role, and does that role have ability A
public(package) fun owner_has_ability<T, A: drop>(self: &Auth<T>, owner: address): bool {
    let owner_key = AddressKey { owner };
    if (!self.roles_owners.contains(owner_key)) {
        return false
    };
    let owner_role = self.roles_owners.borrow(owner_key);
    let ability_type = type_name::with_defining_ids<A>();
    let abilities = self.roles_abilities.get(owner_role);
    abilities.contains(&ability_type)
}

/// Add a new role type R to the system.
/// When a new role is added, Master automatically gets the ability to set it.
///
/// # Aborts
/// * `ENotEnoughPermissions` - If the sender does not have the SetRoleTypes ability
/// * `ERoleAlreadyExists` - If the role type R already exists
public fun add_role_type<T, R, A>(self: &mut Auth<T>, version: &Version, ctx: &mut TxContext) {
    version.check_is_valid();
    assert!(owner_has_ability<T, SetRoleTypes>(self, ctx.sender()), ENotEnoughPermissions);

    let roles_type = type_name::with_defining_ids<R>();
    let set_ability = type_name::with_defining_ids<A>();
    // Check if the type already exists
    assert!(!self.roles.contains(&roles_type), ERoleAlreadyExists);
    // Add new type R with a 0 counter in the MAP
    self.roles.insert(roles_type, 0);

    // Add the new abilities set
    let roles_abilities_set = vec_set::empty<TypeName>();
    self.roles_abilities.insert(roles_type, roles_abilities_set);

    // Add the role set ability A to Master (so Master can set this new role)
    let master_type = type_name::with_defining_ids<Master>();
    let master_abilities = self.roles_abilities.get_mut(&master_type);
    master_abilities.insert(set_ability);
}

/// Remove a role type R from the system.
/// Can only remove if no addresses currently have this role (counter == 0).
/// Also cleans up the role's abilities and removes it from Master's abilities.
///
/// # Aborts
/// * `ENotEnoughPermissions` - If the sender does not have the SetRoleTypes ability
/// * `ECannotRemoveMaster` - If attempting to remove the Master role
/// * `ERoleNotFound` - If the role type R is not registered
/// * `ERoleHasActiveMembers` - If the role has active members (counter > 0)
/// * `ERoleAbilitiesNotFound` - If the role's abilities mapping is not found
/// * `EAbilityNotFound` - If the set ability A is not found in Master's abilities
public fun remove_role_type<T, R, A>(self: &mut Auth<T>, version: &Version, ctx: &mut TxContext) {
    version.check_is_valid();
    assert!(owner_has_ability<T, SetRoleTypes>(self, ctx.sender()), ENotEnoughPermissions);

    let roles_type = type_name::with_defining_ids<R>();
    let set_ability = type_name::with_defining_ids<A>();

    // Prevent removing Master role
    assert!(roles_type != type_name::with_defining_ids<Master>(), ECannotRemoveMaster);

    assert!(self.roles.contains(&roles_type), ERoleNotFound);

    // Remove R only if counter is 0 (no active role holders)
    let (_, counter) = self.roles.remove(&roles_type);
    assert!(counter == 0, ERoleHasActiveMembers);

    // Clean up: Remove the role's ability set
    assert!(self.roles_abilities.contains(&roles_type), ERoleAbilitiesNotFound);
    self.roles_abilities.remove(&roles_type);

    // Clean up: Remove this role from Master's abilities
    let master_type = type_name::with_defining_ids<Master>();
    let master_abilities = self.roles_abilities.get_mut(&master_type);
    assert!(master_abilities.contains(&set_ability), EAbilityNotFound);
    master_abilities.remove(&set_ability);
}

/// Makes the Auth a shared object for public access.
#[lint_allow(share_owned)]
public(package) fun share<T>(auth: Auth<T>) {
    transfer::share_object(auth);
}
