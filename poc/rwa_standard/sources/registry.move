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