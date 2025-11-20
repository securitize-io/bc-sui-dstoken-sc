/// Module: trust_service
///
/// This is the main module for role management. The core structure here is Auth,
/// which we implemented as an independent shared object.
/// We have three main (administrative) roles: Master, Issuer, and TransferAgent.
module securitize::trust_service;

use sui::bag::{Self, Bag};
use sui::vec_map::{Self, VecMap};
use sui::vec_set::{Self, VecSet};
use std::type_name::{Self, TypeName};
use sui::event;

// ==== Errors and Constants ====
/// Unauthorized access, only the master can call this function.
const EUnauthorizedOnlyMaster: u64 = 1;
/// Direct role to role change is not allowed.
const EDirectRoleToRoleChange: u64 = 2;
/// Invalid target role.
const EInvalidTargetRole: u64 = 3;
/// Cannot remove master role.
const ECannotRemoveMaster: u64 = 4;
/// Not enough permissions.
const ENotEnoughPermissions: u64 = 5;

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
///
/// Design pattern: Role TypeNames are also used as abilities.
/// - To grant permission to set role R, add R's TypeName as an ability to another role
/// - Example: Issuer role has Issuer TypeName as an ability, so Issuers can set Issuer roles
/// - Master has all role TypeNames as abilities, so Master can set any role
public struct Auth<phantom T> has key {
    id: UID,
    // Roles and owners counter
    roles: VecMap<TypeName, u32>,
    /// Abilities are witness types mapped per role
    /// Role TypeNames can also be used as abilities to grant permission to set that role
    roles_abilities: VecMap<TypeName, VecSet<TypeName>>,
    /// Role keys registry (Bag of AddressKey structs)
    roles_owners: Bag,
}

/// Key structure for identifying role ownership
public struct AddressKey has copy, store, drop {
    owner: address,
}

// ==================== Role Witnesses ====================

/// Master role witness
public struct Master has drop {}

/// Issuer role witness
public struct Issuer has drop {}

/// TransferAgent role witness
public struct TransferAgent has drop {}

// ==================== Abilities ====================
//
// Note: Role TypeNames (Master, Issuer, TransferAgent) are used as abilities
// to grant permission to set/remove those roles. The structs below are for
// administrative abilities only.

/// Add/Remove abilities from roles
public struct SetAbilities has drop {}

/// Add/Remove role types dynamically
public struct SetRoleTypes has drop {}

// ==================== Initialization Functions ====================

/// Create new Auth shared object for type T
/// This should be called during initialization and the Auth object should be shared
public(package) fun new<T>(ctx: &mut TxContext): Auth<T> {
    // Initialize roles VecMap with Master, Issuer, TransferAgent roles
    let mut roles = vec_map::empty<TypeName, u32>();
    roles.insert(type_name::with_original_ids<Master>(), 0);
    roles.insert(type_name::with_original_ids<Issuer>(), 0);
    roles.insert(type_name::with_original_ids<TransferAgent>(), 0);

    // Initialize roles_abilities VecMap
    let mut roles_abilities = vec_map::empty<TypeName, VecSet<TypeName>>();
    
    // Add all abilities to Master role, including role TypeNames
    let mut master_abilities = vec_set::empty<TypeName>();
    master_abilities.insert(type_name::with_original_ids<SetAbilities>());
    master_abilities.insert(type_name::with_original_ids<SetRoleTypes>());

    // Add role TypeNames as abilities (Master can set all roles)
    master_abilities.insert(type_name::with_original_ids<Master>());
    master_abilities.insert(type_name::with_original_ids<Issuer>());
    master_abilities.insert(type_name::with_original_ids<TransferAgent>());
    roles_abilities.insert(type_name::with_original_ids<Master>(), master_abilities);

    // Add TransferAgent role TypeName as ability to TransferAgent role
    let mut transfer_agent_abilities = vec_set::empty<TypeName>();
    transfer_agent_abilities.insert(type_name::with_original_ids<TransferAgent>());
    roles_abilities.insert(type_name::with_original_ids<TransferAgent>(), transfer_agent_abilities);

    // Add Issuer role TypeName as ability to Issuer role
    let mut issuer_abilities = vec_set::empty<TypeName>();
    issuer_abilities.insert(type_name::with_original_ids<Issuer>());
    roles_abilities.insert(type_name::with_original_ids<Issuer>(), issuer_abilities);

    // Initialize roles_owners Bag
    let mut roles_owners = bag::new(ctx);

    // Add sender as Master and increment counter
    let sender = ctx.sender();
    let master_key = AddressKey { owner: sender };
    roles_owners.add(master_key, type_name::with_original_ids<Master>());
    *roles.get_mut(&type_name::with_original_ids<Master>()) = 1;

    Auth {
        id: object::new(ctx),
        roles,
        roles_abilities,
        roles_owners,
    }
}

// ==================== Role Management Functions ====================

/// Check the role of the address
public fun get_role<T>(
    self: &Auth<T>,
    owner: address
): TypeName {
    // Return R from Bag else abort if address doesn't have role
    let owner_key = AddressKey { owner };
    assert!(self.roles_owners.contains(owner_key), EInvalidTargetRole);
    *self.roles_owners.borrow(owner_key)
}

/// Set/grant a role R to an owner address
/// Creates a RoleKey<R> and stores it in the roles Bag
public fun set_role<T, R: drop>(
    self: &mut Auth<T>,
    owner: address,
    ctx: &mut TxContext
) {
    let sender = ctx.sender();
    let roles_type = type_name::with_original_ids<R>();

    // Check if role R exists in Roles
    assert!(self.roles.contains(&roles_type), EInvalidTargetRole);

    // Assert sender has the role TypeName as an ability (which grants permission to set that role)
    assert!(owner_has_ability<T, R>(self, sender), ENotEnoughPermissions);

    // Assert if the address already has a role
    let owner_key = AddressKey { owner };
    assert!(!self.roles_owners.contains(owner_key), EDirectRoleToRoleChange);

    // Add role R and increment counter
    self.roles_owners.add(owner_key, roles_type);
    let counter = self.roles.get_mut(&roles_type);
    *counter = *counter + 1;
    // Emit event
    event::emit(DSTrustServiceRoleAdded<T> {
        target_address: owner,
        role: roles_type,
        sender
    });
}

/// Remove a role R from an owner address
/// Removes the RoleKey<R> from the roles Bag
public fun remove_role<T, R: drop>(
    self: &mut Auth<T>,
    owner: address,
    ctx: &mut TxContext
) {
    let sender = ctx.sender();
    let roles_type = type_name::with_original_ids<R>();

    // Cannot remove Master role
    assert!(roles_type != type_name::with_original_ids<Master>(), ECannotRemoveMaster);

    // Assert sender has the role TypeName as an ability (which grants permission to remove that role)
    assert!(owner_has_ability<T, R>(self, sender), ENotEnoughPermissions);

    // Assert if the address has a role
    let owner_key = AddressKey { owner };
    assert!(self.roles_owners.contains(owner_key), EInvalidTargetRole);

    // Remove addresskey from roles_owners and decrement counter
    let stored_role: TypeName = self.roles_owners.remove(owner_key);
    assert!(stored_role == roles_type, EInvalidTargetRole);
    let counter = self.roles.get_mut(&roles_type);
    *counter = *counter - 1;
    // Emit event
    event::emit(DSTrustServiceRoleRemoved<T> {
        target_address: owner,
        role: roles_type,
        sender
    });
}

/// Set/transfer service ownership (reassigns Master role)
public fun set_service_owner<T, R: drop>(
    self: &mut Auth<T>,
    owner: address,
    ctx: &mut TxContext
) {
    let sender = ctx.sender();
    // Assert sender has SetServiceOwner ability
    assert!(owner_has_ability<T, Master>(self, sender), ENotEnoughPermissions);
    // Assert R is Master
    let roles_type = type_name::with_original_ids<R>();
    assert!(roles_type == type_name::with_original_ids<Master>(), EInvalidTargetRole);
    // Assert sender has Master role
    let sender_key = AddressKey { owner: sender };
    assert!(self.roles_owners.contains(sender_key), EUnauthorizedOnlyMaster);
    let sender_role: &TypeName = self.roles_owners.borrow(sender_key);
    assert!(*sender_role == type_name::with_original_ids<Master>(), EUnauthorizedOnlyMaster);
    // Remove Master from sender and add it to owner
    let _: TypeName = self.roles_owners.remove(sender_key);
    let owner_key = AddressKey { owner };
    // If owner already has a role, remove it first and decrement counter
    if (self.roles_owners.contains(owner_key)) {
        let old_role: TypeName = self.roles_owners.remove(owner_key);
        let old_counter = self.roles.get_mut(&old_role);
        *old_counter = *old_counter - 1;
    };
    self.roles_owners.add(owner_key, type_name::with_original_ids<Master>());

    // Emit events
    event::emit(DSTrustServiceRoleRemoved<T> {
        target_address: sender,
        role: type_name::with_original_ids<Master>(),
        sender
    });

    event::emit(DSTrustServiceRoleAdded<T> {
        target_address: owner,
        role: type_name::with_original_ids<Master>(),
        sender
    });
}

// ==================== Ability Management Functions ====================

/// Add an ability A to role R
/// This grants all holders of role R the ability to perform actions requiring A
public fun add_roles_ability<T, R: drop, A: drop>(
    self: &mut Auth<T>,
    ctx: &TxContext
) {
    // Assert sender has SetAbilities
    assert!(owner_has_ability<T, SetAbilities>(self, ctx.sender()), ENotEnoughPermissions);
    let roles_type = type_name::with_original_ids<R>();
    let ability_type = type_name::with_original_ids<A>();
    // Assert if R exists in roles
    assert!(self.roles.contains(&roles_type), EInvalidTargetRole);
    // Get abilities set for role R
    assert!(self.roles_abilities.contains(&roles_type), EInvalidTargetRole);
    let abilities = self.roles_abilities.get_mut(&roles_type);
    // Assert if the ability doesn't already exist
    assert!(!abilities.contains(&ability_type), EInvalidTargetRole);
    // Add ability to role R
    abilities.insert(ability_type);
}

/// Remove an ability A from role R
/// This revokes the ability to perform actions requiring A from all holders of role R
public fun remove_roles_ability<T, R: drop, A: drop>(
    self: &mut Auth<T>,
    ctx: &TxContext
) {
    // Assert sender has SetAbilities
    assert!(owner_has_ability<T, SetAbilities>(self, ctx.sender()), ENotEnoughPermissions);
    let roles_type = type_name::with_original_ids<R>();
    let ability_type = type_name::with_original_ids<A>();
    // Assert if R exists in roles
    assert!(self.roles.contains(&roles_type), EInvalidTargetRole);
    // Assert role has abilities
    assert!(self.roles_abilities.contains(&roles_type), EInvalidTargetRole);
    let abilities = self.roles_abilities.get_mut(&roles_type);
    // Assert if the ability exists
    assert!(abilities.contains(&ability_type), EInvalidTargetRole);
    // Remove ability from role R
    abilities.remove(&ability_type);
}

/// Check if role R has ability A
public fun roles_has_ability<T, R: drop, A: drop>(
    self: &Auth<T>,
): bool {
    let roles_type = type_name::with_original_ids<R>();
    let ability_type = type_name::with_original_ids<A>();
    // Check if role exists and has the ability
    assert!(self.roles_abilities.contains(&roles_type), EInvalidTargetRole);
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
    // Find owner's role
    assert!(self.roles_owners.contains(owner_key), EInvalidTargetRole);
    let owner_role = self.roles_owners.borrow(owner_key);
    let ability_type = type_name::with_original_ids<A>();
    // Check if the role has the ability
    assert!(self.roles_abilities.contains(owner_role), EInvalidTargetRole);
    let abilities = self.roles_abilities.get(owner_role);
    abilities.contains(&ability_type)
}

/// Add a new role type R to the system
/// When a new role is added, Master automatically gets the ability to set it
/// The new role R also gets itself as an ability (so holders of R can set R)
public fun add_roles_type<T, R>(
    self: &mut Auth<T>,
    ctx: &mut TxContext
) {
    // Assert sender has SetRoleTypes ability
    assert!(owner_has_ability<T, SetRoleTypes>(self, ctx.sender()), ENotEnoughPermissions);
    let roles_type = type_name::with_original_ids<R>();
    // Check if the type already exists
    assert!(!self.roles.contains(&roles_type), EInvalidTargetRole);
    // Add new type R with a 0 counter in the MAP
    self.roles.insert(roles_type, 0);

    // Add the role TypeName as an ability to the new role itself
    let mut roles_abilities_set = vec_set::empty<TypeName>();
    roles_abilities_set.insert(roles_type);
    self.roles_abilities.insert(roles_type, roles_abilities_set);

    // Add the role TypeName as an ability to Master (so Master can set this new role)
    let master_type = type_name::with_original_ids<Master>();
    if (self.roles_abilities.contains(&master_type)) {
        let master_abilities = self.roles_abilities.get_mut(&master_type);
        master_abilities.insert(roles_type);
    };
}

/// Remove a role type R from the system
/// Can only remove if no addresses currently have this role (counter == 0)
/// Also cleans up the role's abilities and removes it from Master's abilities
public fun remove_roles_type<T, R>(
    self: &mut Auth<T>,
    ctx: &mut TxContext
) {
    // Assert sender has SetRoleTypes ability
    assert!(owner_has_ability<T, SetRoleTypes>(self, ctx.sender()), ENotEnoughPermissions);
    let roles_type = type_name::with_original_ids<R>();

    // Prevent removing core roles
    assert!(roles_type != type_name::with_original_ids<Master>(), EInvalidTargetRole);
    assert!(roles_type != type_name::with_original_ids<Issuer>(), EInvalidTargetRole);
    assert!(roles_type != type_name::with_original_ids<TransferAgent>(), EInvalidTargetRole);

    // Check if the type exists
    assert!(self.roles.contains(&roles_type), EInvalidTargetRole);

    // Remove R only if counter is 0 (no active role holders)
    let (_, counter) = self.roles.remove(&roles_type);
    assert!(counter == 0, EInvalidTargetRole);

    // Clean up: Remove the role's ability set
    assert!(self.roles_abilities.contains(&roles_type), EInvalidTargetRole);
    self.roles_abilities.remove(&roles_type);

    // Clean up: Remove this role from Master's abilities
    let master_type = type_name::with_original_ids<Master>();
    assert!(self.roles_abilities.contains(&master_type), EInvalidTargetRole);
    let master_abilities = self.roles_abilities.get_mut(&master_type);
    assert!(master_abilities.contains(&roles_type), EInvalidTargetRole);
    master_abilities.remove(&roles_type);
}
