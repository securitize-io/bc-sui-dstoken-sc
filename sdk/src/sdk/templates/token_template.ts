export const TOKEN_TEMPLATE = `
module {MODULE}::{MODULE};

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

public struct {SYMBOL} has key {
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
): (Auth<{SYMBOL}>, Treasury<{SYMBOL}>, InvestorInfo<{SYMBOL}>, ComplianceConfig<{SYMBOL}>, SetupFinalize) {
    let (currency, treasury_cap) = coin_registry::new_currency<{SYMBOL}>(
        registry,
        decimals,
        name,
        symbol,
        description,
        url,
        ctx,
    );
    let rule_permit = internal::permit<{SYMBOL}>();
    setup::setup(setup_registry, namespace, currency, rule_permit, treasury_cap, version, ctx)
}
`