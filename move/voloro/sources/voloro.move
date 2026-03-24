module voloro::voloro;

use std::string::String;
use sui::{coin::TreasuryCap, coin_registry::{Self, CoinRegistry, MetadataCap}};

public struct Voloro has key {
    id: UID,
}

public fun create_ds_token(
    name: String,
    symbol: String,
    url: String,
    description: String,
    decimals: u8,
    registry: &mut CoinRegistry,
    ctx: &mut TxContext,
): (MetadataCap<Voloro>, TreasuryCap<Voloro>) {
    let (currency, treasury_cap) = coin_registry::new_currency<Voloro>(
        registry,
        decimals,
        name,
        symbol,
        description,
        url,
        ctx,
    );
    let metadata_cap = currency.finalize(ctx);
    (metadata_cap, treasury_cap)
}
