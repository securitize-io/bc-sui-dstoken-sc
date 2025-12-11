module voloro::voloro;

use securitize::{
    setup::{Self, SetupRegistry, SetupFinalize},
    version::Version,
    trust_service::Auth,
    ds_token::Treasury,
    registry_service::InvestorInfo,
    compliance_service::ComplianceConfig
};
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
    setup_registry: &mut SetupRegistry,
    rwa_registry: &mut RwaRegistry,
    registry: &mut CoinRegistry,
    version: &Version,
    ctx: &mut TxContext,
): (Auth<VOLORO>, Treasury<VOLORO>, InvestorInfo<VOLORO>, ComplianceConfig<VOLORO>, SetupFinalize) {
    let (currency, treasury_cap) = coin_registry::new_currency<VOLORO>(
        registry,
        decimals,
        name,
        symbol,
        b"This is a Securitize RWA Token".to_string(),
        url,
        ctx,
    );

    setup::setup(setup_registry, rwa_registry, currency, treasury_cap, version, ctx)
}
