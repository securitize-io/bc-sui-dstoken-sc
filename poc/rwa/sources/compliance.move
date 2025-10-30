module rwa_poc::compliance;

use sui::coin::{TreasuryCap};
use sui::balance::Balance;
use rwa_poc::investors::{Self, InvestorRegistry};
use rwa::rule::{Self, RwaRule, resolve_transfer};
use rwa::vault::{RwaVault, RwaTransferRequest, VaultOwnerProof};
use rwa::registry::{RwaRegistry};

const CLAWBACK_ADDRESS: address = @0xDEADBEEF;

const ENotSameCountry: u64 = 0;
const EBelowMinTransfer: u64 = 1;
const EAboveMaxTransfer: u64 = 2;

public struct SecuritizeCompliance() has drop;

public struct ComplianceConfig<phantom T> has key {
    id: UID,
    minimum_holdings: u64,
    maximum_holdings: u64,
    minimum_transfer_amount: u64,
    maximum_transfer_amount: u64,
    clawback_address: address,
}

public(package) fun new<T>(
    min_holdings: u64,
    max_holdings: u64,
    min_transfer: u64,
    max_transfer: u64,
    ctx: &mut TxContext,
) {
    let config = ComplianceConfig<T> {
        id: object::new(ctx),
        minimum_holdings: min_holdings,
        maximum_holdings: max_holdings,
        minimum_transfer_amount: min_transfer,
        maximum_transfer_amount: max_transfer,
        clawback_address: CLAWBACK_ADDRESS,
    };
    transfer::share_object(config);
}

public fun validate_transfer<T>(
    rule: &RwaRule<T>,
    req: RwaTransferRequest<T>,
    config: &ComplianceConfig<T>,
    investors: &InvestorRegistry<T>,
    _ctx: &mut TxContext,
) {
    let from = req.request_from_address();
    let to = req.request_to_address();
    let amount = req.request_amount();
    let from_country = investors::get_country<T>(investors, from);
    let to_country = investors::get_country<T>(investors, to);
    
    // Add your compliance logic here
    assert!(from_country == to_country, ENotSameCountry); // Example: same country transfer
    assert!(amount >= config.minimum_transfer_amount, EBelowMinTransfer);
    assert!(amount <= config.maximum_transfer_amount, EAboveMaxTransfer);

    resolve_transfer(rule, req, SecuritizeCompliance());
}

public fun validate_mint<T>(
    rule: &RwaRule<T>,
    _config: &ComplianceConfig<T>,
    investors: &InvestorRegistry<T>,
    vault: &mut RwaVault,
    balance: Balance<T>,
    to: address,
    _amount: u64,
    _ctx: &mut TxContext,
) {
    let _to_country = investors::get_country<T>(investors, to);
    
    // Add your compliance logic here
    // For minting, you might want to check the investor's country or other criteria

    rule::deposit_to_vault(
        rule,
        vault,
        balance,
        SecuritizeCompliance(),
    );
}

public(package) fun validate_burn<T>(
    rule: &RwaRule<T>,
    _config: &ComplianceConfig<T>,
    investors: &InvestorRegistry<T>,
    vault: &mut RwaVault,
    owner_proof: &VaultOwnerProof,
    from: address,
    amount: u64,
    _ctx: &mut TxContext,
): Balance<T> {
    let _from_country = investors::get_country<T>(investors, from);

    // Add your compliance logic here
    // For burning, you might want to check the investor's country or other criteria

    let balance = rule::withdraw_from_vault(
        rule,
        vault,
        owner_proof,
        amount,
        SecuritizeCompliance(),
    );
    balance
}

public fun clawback<T>(
    rwa_reg: &RwaRegistry,
    config: &ComplianceConfig<T>,
    rule: &RwaRule<T>,
    vault: &mut RwaVault,
    amount: u64,
    ctx: &mut TxContext,
) {

    let balance = rule::clawback(rule, vault, amount, SecuritizeCompliance());
    rule::deposit(
        rwa_reg,
        rule,
        config.clawback_address,
        balance,
        SecuritizeCompliance(),
        ctx,
    );
}

public(package) fun register_rule<T>(
    cap: &TreasuryCap<T>,
    rwa_registry: &mut RwaRegistry,
    clawback_allowed: bool,
) {
    rule::new(rwa_registry, cap, clawback_allowed, SecuritizeCompliance());
}