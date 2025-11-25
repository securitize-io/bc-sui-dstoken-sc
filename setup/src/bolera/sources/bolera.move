module bolera::bolera;

use securitize::setup::{Self, SetupAuth};
use sui::coin_registry::{Self, CoinRegistry};

const DECIMAL: u8 = 6;

public struct BOLERA has key {
    id: UID
}

public fun create_ds_token(
    setup_auth: &SetupAuth,
    registry: &mut CoinRegistry,
    ctx: &mut TxContext,
) {
    let (currency, treasury_cap) = coin_registry::new_currency<BOLERA>(
        registry,
        DECIMAL,
        b"BOLERA".to_string(),
        b"Bolera Test Token".to_string(),
        b"Bolera Test Token".to_string(),
        b"https://example.io/bolera.png".to_string(),
        ctx,
    );

    setup::setup(setup_auth, currency, treasury_cap, ctx);
}