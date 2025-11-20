/// Module: trust_service
///
/// This is the main module for role management. The core structure here is Auth 
/// as an independent shared object.
/// three main (administrative) roles: Master, Issuer, and TransferAgent.
module securitize::trust_service;

use sui::bag::{Self, Bag};
use sui::vec_map::{Self, VecMap};
use sui::vec_set::{Self, VecSet};
use std::type_name::{Self, TypeName};
use sui::event;

// ==== Errors and Constants ====
/// Direct role to role change is not allowed.
const EDirectRoleToRoleChange: u64 = 3;
/// Cannot remove master role.
const ECannotRemoveMaster: u64 = 4;
/// Not enough permissions.
const ENotEnoughPermissions: u64 = 5;
/// Cannot transfer ownership to self.
const ESelfTransferNotAllowed: u64 = 6;
/// Owner has no role assigned.
const EOwnerHasNoRole: u64 = 7;
/// Role type not found in the system.
const ERoleNotFound: u64 = 8;
/// Role type mismatch - stored role doesn't match expected.
const ERoleTypeMismatch: u64 = 9;
/// Role abilities mapping not found.
const ERoleAbilitiesNotFound: u64 = 10;
/// Ability already exists for this role.
const EAbilityAlreadyExists: u64 = 11;
/// Ability not found for this role.
const EAbilityNotFound: u64 = 12;
/// Role type already exists.
const ERoleAlreadyExists: u64 = 13;
/// Role has active members and cannot be removed.
const ERoleHasActiveMembers: u64 = 14;

// ==== Events ====

public struct DSTrustServiceRoleAdded<phantom T> has copy, drop {
    target_address: address,
    role: TypeName,
    sender: address
}

public struct DSTrustServiceRoleRemoved<phantom T> has copy, drop {
    target_address: address,
    role: TypeName,
    sender: address
}

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
public struct AddressKey has copy, store, drop {
    owner: address,
}

// ==================== Roles ====================

/// Master role witness
public struct Master has drop {}
/// Issuer role witness
public struct Issuer has drop {}
/// TransferAgent role witness
public struct TransferAgent has drop {}

// ==================== Trust Service Abilities ====================

/// Change Master role
public struct SetServiceOwner has drop {}
/// Add/Remove Transfer Agent role
public struct SetTransferAgent has drop {}
/// Add/Remove Issuer role
public struct SetIssuer has drop {}
/// Add/Remove abilities from roles
public struct SetAbilities has drop {}
/// Add/Remove role types dynamically
public struct SetRoleTypes has drop {}

// ==================== Initialization Functions ====================

/// Create new Auth shared object for type T
/// This should be called during initialization and the Auth object should be shared
public(package) fun new<T>(ctx: &mut TxContext): Auth<T> {
    // Initialize roles VecMap with Master, Issuer, TransferAgent roles
    let mut roles = vec_map::empty();
    roles.insert(type_name::with_original_ids<Master>(), 0);
    roles.insert(type_name::with_original_ids<Issuer>(), 0);
    roles.insert(type_name::with_original_ids<TransferAgent>(), 0);

    // Initialize roles_abilities VecMap
    let mut roles_abilities = vec_map::empty();

    // Add all abilities to Master role, including role TypeNames
    let mut master_abilities = vec_set::empty();
    master_abilities.insert(type_name::with_original_ids<SetAbilities>());
    master_abilities.insert(type_name::with_original_ids<SetRoleTypes>());

    // Add role TypeNames as abilities (Master can set all roles)
    master_abilities.insert(type_name::with_original_ids<SetServiceOwner>());
    master_abilities.insert(type_name::with_original_ids<SetIssuer>());
    master_abilities.insert(type_name::with_original_ids<SetTransferAgent>());
    roles_abilities.insert(type_name::with_original_ids<Master>(), master_abilities);

    // Add TransferAgent role TypeName as ability to TransferAgent role
    let mut transfer_agent_abilities = vec_set::empty();
    transfer_agent_abilities.insert(type_name::with_original_ids<SetTransferAgent>());
    roles_abilities.insert(type_name::with_original_ids<TransferAgent>(), transfer_agent_abilities);

    // Add Issuer role TypeName as ability to Issuer role
    let mut issuer_abilities = vec_set::empty();
    issuer_abilities.insert(type_name::with_original_ids<SetIssuer>());
    roles_abilities.insert(type_name::with_original_ids<Issuer>(), issuer_abilities);

    let mut auth = Auth<T> {
        id: object::new(ctx),
        roles,
        roles_abilities,
        roles_owners: bag::new(ctx)
    };

    // Assign initial Master
    internal_assign_role<T, Master>(&mut auth, ctx.sender(),ctx);
    auth
}

// ==================== Role Management Functions ====================

/// Check the role of the address
public fun get_role<T>(
    self: &Auth<T>,
    owner: address
): TypeName {
    let owner_key = AddressKey { owner };
    assert!(self.roles_owners.contains(owner_key), EOwnerHasNoRole);
    *self.roles_owners.borrow(owner_key)
}

/// Set/grant a role TransferAgent to an owner address
/// Creates an AddressKey and stores it in the roles Bag
public fun set_transfer_agent<T>(
    self: &mut Auth<T>,
    owner: address,
    ctx: &mut TxContext
) {
    assert!(owner_has_ability<T, SetTransferAgent>(self, ctx.sender()), ENotEnoughPermissions);
    internal_assign_role<T, TransferAgent>(self, owner,ctx);
}

/// Remove a role TransferAgent from an owner address
public fun remove_transfer_agent<T>(
    self: &mut Auth<T>,
    owner: address,
    ctx: &mut TxContext
) {
    assert!(owner_has_ability<T, SetTransferAgent>(self, ctx.sender()), ENotEnoughPermissions);
    internal_remove_role<T, TransferAgent>(self, owner,ctx);
}

/// Set/grant a role Issuer to an owner address
/// Creates an AddressKey and stores it in the roles Bag
public fun set_issuer<T>(
    self: &mut Auth<T>,
    owner: address,
    ctx: &mut TxContext
) {
    assert!(owner_has_ability<T, SetIssuer>(self, ctx.sender()), ENotEnoughPermissions);
    internal_assign_role<T, Issuer>(self, owner,ctx);
}

/// Remove a role Issuer from an owner address
public fun remove_issuer<T>(
    self: &mut Auth<T>,
    owner: address,
    ctx: &mut TxContext
) {
    assert!(owner_has_ability<T, SetIssuer>(self, ctx.sender()), ENotEnoughPermissions);
    internal_remove_role<T, Issuer>(self, owner,ctx);
}

/// Set/transfer service ownership (reassigns Master role)
public fun set_service_owner<T>(
    self: &mut Auth<T>,
    owner: address,
    ctx: &mut TxContext
) {
    assert!(ctx.sender() != owner, ESelfTransferNotAllowed);
    assert!(owner_has_ability<T, SetServiceOwner>(self, ctx.sender()), ENotEnoughPermissions);
    internal_remove_role<T, Master>(self, ctx.sender(),ctx);
    internal_assign_role<T, Master>(self, owner,ctx);
}

/// Set/grant a role R to an owner address
/// Creates an AddressKey and stores it in the roles Bag
public(package) fun internal_assign_role<T, R: drop>(
    self: &mut Auth<T>,
    owner: address,
    ctx: &TxContext
) {
    let roles_type = type_name::with_original_ids<R>();
    assert!(self.roles.contains(&roles_type), ERoleNotFound);

    // Assert if the address already has a role
    let owner_key = AddressKey { owner };
    assert!(!self.roles_owners.contains(owner_key), EDirectRoleToRoleChange);

    // Add role TransferAgent and increment counter
    self.roles_owners.add(owner_key, roles_type);
    *self.roles.get_mut(&roles_type) = *self.roles.get_mut(&roles_type) + 1;

    // Emit event
    event::emit(DSTrustServiceRoleAdded<T> {
        target_address: owner,
        role: roles_type,
        sender: ctx.sender()
    });
}

/// Remove a role R from an owner address
public(package) fun internal_remove_role<T, R: drop>(
    self: &mut Auth<T>,
    owner: address,
    ctx: &TxContext
) {
    let roles_type = type_name::with_original_ids<R>();

    // Assert if the address doesn't have a role
    let owner_key = AddressKey { owner };
    assert!(self.roles_owners.contains(owner_key), EOwnerHasNoRole);

    // Remove addresskey from roles_owners and decrement counter
    let stored_role: TypeName = self.roles_owners.remove(owner_key);
    assert!(stored_role == roles_type, ERoleTypeMismatch);
    *self.roles.get_mut(&roles_type) = *self.roles.get_mut(&roles_type) - 1;

    // Emit event
    event::emit(DSTrustServiceRoleRemoved<T> {
        target_address: owner,
        role: roles_type,
        sender: ctx.sender()
    });
}

// ==================== Ability Management Functions ====================

/// Add an ability A to role R
/// This grants all holders of role R the ability to perform actions requiring A
public fun add_role_ability<T, R: drop, A: drop>(
    self: &mut Auth<T>,
    ctx: &TxContext
) {
    assert!(owner_has_ability<T, SetAbilities>(self, ctx.sender()), ENotEnoughPermissions);

    let roles_type = type_name::with_original_ids<R>();
    let ability_type = type_name::with_original_ids<A>();

    assert!(self.roles.contains(&roles_type), ERoleNotFound);
    assert!(self.roles_abilities.contains(&roles_type), ERoleAbilitiesNotFound);

    // Add Ability
    let abilities = self.roles_abilities.get_mut(&roles_type);
    assert!(!abilities.contains(&ability_type), EAbilityAlreadyExists);
    abilities.insert(ability_type);
}

/// Remove an ability A from role R
/// This revokes the ability to perform actions requiring A from all holders of role R
public fun remove_role_ability<T, R: drop, A: drop>(
    self: &mut Auth<T>,
    ctx: &TxContext
) {
    assert!(owner_has_ability<T, SetAbilities>(self, ctx.sender()), ENotEnoughPermissions);

    let roles_type = type_name::with_original_ids<R>();
    let ability_type = type_name::with_original_ids<A>();

    // Prevent removing SetAbilities from Master role
    assert!(
        !(roles_type == type_name::with_original_ids<Master>() && ability_type == type_name::with_original_ids<SetAbilities>()),
        ECannotRemoveMaster
    );
    assert!(self.roles.contains(&roles_type), ERoleNotFound);
    assert!(self.roles_abilities.contains(&roles_type), ERoleAbilitiesNotFound);

    // Remove Ability
    let abilities = self.roles_abilities.get_mut(&roles_type);
    assert!(abilities.contains(&ability_type), EAbilityNotFound);
    abilities.remove(&ability_type);
}

/// Check if role R has ability A
public fun role_has_ability<T, R: drop, A: drop>(
    self: &Auth<T>,
): bool {
    let roles_type = type_name::with_original_ids<R>();
    let ability_type = type_name::with_original_ids<A>();

    assert!(self.roles_abilities.contains(&roles_type), ERoleAbilitiesNotFound);

    let abilities = self.roles_abilities.get(&roles_type);
    abilities.contains(&ability_type)
}

/// Check if an owner address has ability A through their role
/// This is a combined check: does the owner have a role, and does that role have ability A
public fun owner_has_ability<T, A: drop>(
    self: &Auth<T>,
    owner: address,
): bool {
    let owner_key = AddressKey { owner };
    assert!(self.roles_owners.contains(owner_key), EOwnerHasNoRole);
    let owner_role = self.roles_owners.borrow(owner_key);

    let ability_type = type_name::with_original_ids<A>();
    let abilities = self.roles_abilities.get(owner_role);
    abilities.contains(&ability_type)
}

/// Add a new role type R to the system
/// When a new role is added, Master automatically gets the ability to set it
public fun add_role_type<T, R, A>(
    self: &mut Auth<T>,
    ctx: &mut TxContext
) {
    assert!(owner_has_ability<T, SetRoleTypes>(self, ctx.sender()), ENotEnoughPermissions);

    let roles_type = type_name::with_original_ids<R>();
    let set_ability = type_name::with_original_ids<A>();
    // Check if the type already exists
    assert!(!self.roles.contains(&roles_type), ERoleAlreadyExists);
    // Add new type R with a 0 counter in the MAP
    self.roles.insert(roles_type, 0);

    // Add the new abilities set
    let roles_abilities_set = vec_set::empty<TypeName>();
    self.roles_abilities.insert(roles_type, roles_abilities_set);

    // Add the role set ability A to Master (so Master can set this new role)
    let master_type = type_name::with_original_ids<Master>();
    let master_abilities = self.roles_abilities.get_mut(&master_type);
    master_abilities.insert(set_ability);
}

/// Remove a role type R from the system
/// Can only remove if no addresses currently have this role (counter == 0)
/// Also cleans up the role's abilities and removes it from Master's abilities
public fun remove_role_type<T, R, A>(
    self: &mut Auth<T>,
    ctx: &mut TxContext
) {
    assert!(owner_has_ability<T, SetRoleTypes>(self, ctx.sender()), ENotEnoughPermissions);

    let roles_type = type_name::with_original_ids<R>();
    let set_ability = type_name::with_original_ids<A>();

    // Prevent removing Master role
    assert!(roles_type != type_name::with_original_ids<Master>(), ECannotRemoveMaster);

    assert!(self.roles.contains(&roles_type), ERoleNotFound);

    // Remove R only if counter is 0 (no active role holders)
    let (_, counter) = self.roles.remove(&roles_type);
    assert!(counter == 0, ERoleHasActiveMembers);

    // Clean up: Remove the role's ability set
    assert!(self.roles_abilities.contains(&roles_type), ERoleAbilitiesNotFound);
    self.roles_abilities.remove(&roles_type);

    // Clean up: Remove this role from Master's abilities
    let master_type = type_name::with_original_ids<Master>();
    let master_abilities = self.roles_abilities.get_mut(&master_type);
    assert!(master_abilities.contains(&set_ability), EAbilityNotFound);
    master_abilities.remove(&set_ability);
}

/// Makes the Auth a shared object for public access.
#[lint_allow(share_owned)]
public(package) fun share<T>(auth: Auth<T>) {
    transfer::share_object(auth);
}
