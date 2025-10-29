module rwa_poc::rwa;

use sui::coin_registry::{Self, CoinRegistry};
use rwa::setup::{Self, DeployerRegistry};

public struct RWA has key {
    id: UID
}

public fun create_rwa(
    deployer_reg: &DeployerRegistry,
    registry: &mut CoinRegistry,
    ctx: &mut TxContext,
) {
    let (currency, treasury_cap) = coin_registry::new_currency<RWA>(
        registry,
        9,
        b"RWA".to_string(),
        b"Real World Asset".to_string(),
        b"RWA token for testing".to_string(),
        b"https://exmple.io/rwa.png".to_string(),
        ctx,
    );

    let metadata_cap = currency.finalize(ctx);

    setup::setup(deployer_reg, treasury_cap, metadata_cap, ctx);
}


