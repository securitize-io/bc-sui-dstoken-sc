/// The Namespace module.
///
/// Namespace is responsible for creating objects that are easy to query & find:
/// 1. Vaults
/// 2. Rules
/// ... any other module we might add in the future
module pas::namespace;

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

public(package) fun uid(registry: &Namespace): &UID {
    &registry.id
}

/// Expose `uid_mut` so we can claim derived objects from other modules.
public(package) fun uid_mut(registry: &mut Namespace): &mut UID {
    &mut registry.id
}

// Check if a derived object exists in the registry.
public(package) fun exists<T: copy + store + drop>(registry: &Namespace, key: T): bool {
    derived_object::exists(&registry.id, key)
}

#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    transfer::share_object(Namespace {
        id: object::new(ctx),
    });
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
