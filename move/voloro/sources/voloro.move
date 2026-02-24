module voloro::voloro;

use pas::namespace::Namespace;
use securitize::{
    compliance_service::ComplianceConfig,
    ds_token::Treasury,
    registry_service::InvestorInfo,
    setup::{Self, SetupRegistry, SetupFinalize},
    trust_service::Auth,
    version::Version
};
use std::string::String;
use sui::coin_registry::{Self, CoinRegistry};

public struct VOLORO has key {
    id: UID,
}

public fun create_ds_token(
    name: String,
    symbol: String,
    url: String,
    description: String,
    decimals: u8,
    setup_registry: &mut SetupRegistry,
    namespace: &mut Namespace,
    registry: &mut CoinRegistry,
    version: &Version,
    ctx: &mut TxContext,
): (Auth<VOLORO>, Treasury<VOLORO>, InvestorInfo<VOLORO>, ComplianceConfig<VOLORO>, SetupFinalize) {
    let (currency, treasury_cap) = coin_registry::new_currency<VOLORO>(
        registry,
        decimals,
        name,
        symbol,
        description,
        url,
        ctx,
    );
    let policy_permit = internal::permit<VOLORO>();
    setup::setup(setup_registry, namespace, currency, policy_permit, treasury_cap, version, ctx)
}
