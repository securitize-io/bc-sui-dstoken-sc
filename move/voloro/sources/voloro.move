module voloro::voloro;

use securitize::setup::{Self, SetupAuth};
use sui::coin_registry::{Self, CoinRegistry};

const DECIMAL: u8 = 6;

public struct VOLORO has key {
    id: UID,
}

public fun create_ds_token(
    setup_auth: &SetupAuth,
    registry: &mut CoinRegistry,
    ctx: &mut TxContext,
) {
    let (currency, treasury_cap) = coin_registry::new_currency<VOLORO>(
        registry,
        DECIMAL,
        b"VOLORO".to_string(),
        b"Voloro Test Token".to_string(),
        b"Voloro Test Token".to_string(),
        b"https://example.io/voloro.png".to_string(),
        ctx,
    );

    setup::setup(setup_auth, currency, treasury_cap, ctx);
}
