/// The Namespace module.
///
/// Namespace is responsible for creating objects that are easy to query & find:
/// 1. Vaults
/// 2. Rules
/// ... any other module we might add in the future
module pas::namespace;

use pas::keys;
use sui::derived_object;

/// The namespace is only used for address derivation of vaults, rules, etc.
public struct Namespace has key {
    id: UID,
}

fun init(ctx: &mut TxContext) {
    transfer::share_object(Namespace {
        id: object::new(ctx),
    });
}

/// Check if `Rule<T>` exists in the namespace
public fun rule_exists<T>(namespace: &Namespace): bool {
    derived_object::exists(&namespace.id, keys::rule_key<T>())
}

/// The derived address for `Rule<T>`
public fun rule_address<T>(namespace: &Namespace): address {
    derived_object::derive_address(namespace.id.to_inner(), keys::rule_key<T>())
}

public fun vault_exists(namespace: &Namespace, owner: address): bool {
    derived_object::exists(&namespace.id, keys::vault_key(owner))
}

public fun vault_address(namespace: &Namespace, owner: address): address {
    derived_object::derive_address(namespace.id.to_inner(), keys::vault_key(owner))
}

// Given the name space ID, calculate the vault address.
public(package) fun vault_address_from_id(namespace_id: ID, owner: address): address {
    derived_object::derive_address(namespace_id, keys::vault_key(owner))
}

/// Expose `uid_mut` so we can claim derived objects from other modules.
public(package) fun uid_mut(namespace: &mut Namespace): &mut UID {
    &mut namespace.id
}

#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx);
}

#[test_only]
public fun create_for_testing(ctx: &mut TxContext): Namespace {
    Namespace {
        id: object::new(ctx),
    }
}

#[test_only]
public fun share_for_testing(namespace: Namespace) {
    transfer::share_object(namespace);
}
