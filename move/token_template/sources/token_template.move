module token_template::token_template;

use std::string::String;
use sui::{coin::TreasuryCap, coin_registry::{Self, CoinRegistry, MetadataCap}};

public struct TOKEN_TEMPLATE has key {
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
): (MetadataCap<TOKEN_TEMPLATE>, TreasuryCap<TOKEN_TEMPLATE>) {
    let (currency, treasury_cap) = coin_registry::new_currency<TOKEN_TEMPLATE>(
        registry,
        decimals,
        symbol,
        name,
        description,
        url,
        ctx,
    );
    let metadata_cap = currency.finalize(ctx);
    (metadata_cap, treasury_cap)
}
