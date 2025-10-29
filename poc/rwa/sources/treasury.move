module rwa_poc::treasury;

use sui::coin::{TreasuryCap};
use sui::coin_registry::{MetadataCap};
use rwa_poc::investors::InvestorRegistry;
use rwa_poc::compliance::{Self, ComplianceConfig};
use rwa::vault::{Self, RwaVault};
use rwa::registry::{RwaRegistry};
use rwa::rule::{RwaRule};

public struct Treasury<phantom T> has key {
    id: UID,
    treasury_cap: TreasuryCap<T>,
    metadata_cap: MetadataCap<T>,
}

public(package) fun new<T: key>(
    treasury_cap: TreasuryCap<T>,
    metadata_cap: MetadataCap<T>,
    ctx: &mut TxContext,
) {
    let treasury = Treasury {
        id: object::new(ctx),
        treasury_cap,
        metadata_cap,
    };
    transfer::share_object(treasury);
}

public fun mint<T>(
    treasury: &mut Treasury<T>,
    investors: &InvestorRegistry<T>,
    config: &ComplianceConfig<T>,
    rwa_reg: &mut RwaRegistry,
    rule: &RwaRule<T>,
    to: address,
    amount: u64,
    ctx: &mut TxContext,
) {
    let balance = treasury.treasury_cap.mint_balance(amount);
    let req = vault::deposit_to_vault<T>(
        rwa_reg,
        balance,
        to,
        ctx
    );
    compliance::validate_mint(
        rule, 
        req, 
        config, 
        investors,
        to,
        amount,
        ctx 
    );
}

public fun burn<T>(
    treasury: &mut Treasury<T>,
    investors: &InvestorRegistry<T>,
    config: &ComplianceConfig<T>,
    rule: &RwaRule<T>,
    from: &mut RwaVault,
    amount: u64,
    ctx: &mut TxContext,
) {
    let (balance, req) = vault::withdraw_from_vault<T>(
        from,
        amount,
    );
    compliance::validate_burn(
        rule, 
        req, 
        config, 
        investors,
        from.get_owner_address(),
        amount,
        ctx 
    );
    treasury.treasury_cap.burn(balance.into_coin(ctx));
}

public fun register_rule<T>(
    treasury: &Treasury<T>,
    registry: &mut RwaRegistry,
    clawback_allowed: bool,
) {
    compliance::register_rule<T>(&treasury.treasury_cap, registry, clawback_allowed);
}