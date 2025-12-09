module voloro::voloro;

use securitize::setup::{Self, SetupAuth};
use securitize::{version::Version};
use rwa::registry::RwaRegistry;
use sui::coin_registry::{Self, CoinRegistry};
use std::string::{String};

public struct VOLORO has key {
    id: UID,
}

public fun create_ds_token(
    name: String,
    symbol: String,
    url: String,
    decimals: u8,
    setup_auth: &SetupAuth,
    rwa_registry: &mut RwaRegistry,
    registry: &mut CoinRegistry,
    version: &Version,
    ctx: &mut TxContext,
) {
    let (currency, treasury_cap) = coin_registry::new_currency<VOLORO>(
        registry,
        decimals,
        name,
        symbol,
        b"This is a Securitize RWA Token".to_string(),
        url,
        ctx,
    );

    setup::setup(setup_auth, rwa_registry, currency, treasury_cap, version, ctx);
}
