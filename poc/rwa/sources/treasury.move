module rwa_poc::treasury;

use sui::coin::{TreasuryCap};
use sui::coin_registry::{MetadataCap};
use rwa_poc::investors::InvestorRegistry;
use rwa_poc::compliance::{Self, ComplianceConfig};
use rwa::vault::{RwaVault, VaultOwnerProof};
use rwa::registry::{RwaRegistry};
use rwa::rule::{RwaRule};

const ENotVaultOwner: u64 = 0;

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
    rule: &RwaRule<T>,
    vault: &mut RwaVault,
    to: address,
    amount: u64,
    ctx: &mut TxContext,
) {
    assert!(vault.get_owner_address() == to, ENotVaultOwner);
    let balance = treasury.treasury_cap.mint_balance(amount);
    compliance::validate_mint(
        rule, 
        config, 
        investors,
        vault,
        balance,
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
    vault: &mut RwaVault,
    owner_proof: &VaultOwnerProof,
    amount: u64,
    ctx: &mut TxContext,
) {
    let from = vault.get_owner_address();
    let balance = compliance::validate_burn(
        rule, 
        config, 
        investors,
        vault,
        owner_proof,
        from,
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