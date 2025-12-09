/// The Registry module.
///
/// Registry is responsible for creating namespaced objects:
/// 1. Vaults
/// 2. Rules
module rwa::registry;

/// The registry, from which all RWA related objects are namespaced.
public struct RwaRegistry has key {
    id: UID,
}

fun init(ctx: &mut TxContext) {
    transfer::share_object(RwaRegistry {
        id: object::new(ctx),
    });
}

/// Expose `uid_mut` so we can claim derived objects from other modules.
public(package) fun uid_mut(registry: &mut RwaRegistry): &mut UID {
    &mut registry.id
}

#[test_only]
public fun create_for_testing(ctx: &mut TxContext): RwaRegistry {
    RwaRegistry {
        id: object::new(ctx),
    }
}

#[test_only]
public fun share_for_testing(rwa_registry: RwaRegistry) {
    transfer::share_object(rwa_registry);
}
