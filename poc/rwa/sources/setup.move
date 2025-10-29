module rwa_poc::setup;

use sui::coin::{TreasuryCap};
use sui::coin_registry::{MetadataCap};
use sui::vec_set::{Self, VecSet};
use rwa_poc::treasury;
use rwa_poc::investors;
use rwa_poc::compliance;

const ENotDeployer: u64 = 0;

public struct DeployerRegistry has key {
    id: UID,
    deployers: VecSet<address>
}

fun init(ctx: &mut TxContext) {
    let registry = DeployerRegistry {
        id: object::new(ctx),
        deployers: vec_set::singleton(ctx.sender())
    };
    transfer::share_object(registry);
}

public fun setup<T: key>(
    registry: &DeployerRegistry,
    treasury_cap: TreasuryCap<T>,
    metadata_cap: MetadataCap<T>,
    ctx: &mut TxContext,
) {
    assert!(registry.deployers.contains(&ctx.sender()), ENotDeployer);
    treasury::new<T>(treasury_cap, metadata_cap, ctx);
    investors::new<T>(ctx);
    compliance::new<T>(1_000_000_000, 1_000_000_000_000, 1_000_000, 100_000_000_000, ctx);
}

#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx);
}