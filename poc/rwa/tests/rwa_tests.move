
#[test_only]
module rwa_poc::rwa_tests;

use sui::test_scenario::{Self, Scenario};
use sui::coin_registry;
use sui::test_utils::{destroy};
use rwa::registry::{Self, RwaRegistry};
use rwa::rule::{RwaRule};
use rwa::vault::{Self, RwaVault};
use rwa::token::{RwaToken};
use rwa_poc::setup::{Self, DeployerRegistry};
use rwa_poc::rwa::{Self, RWA};
use rwa_poc::investors::{Self, InvestorRegistry};
use rwa_poc::treasury::{Self, Treasury};
use rwa_poc::compliance::{Self, ComplianceConfig};

const DEPLOYER: address = @0xf38a463604d2db4582033a09db6f8d4b846b113b3cd0a7c4f0d4690b3fe6aa37;
const INVESTOR: address = @0xBABE;
const INVESTOR_2: address = @0xBEEF;

#[test]
fun test_rwa_mint() {
    let mut scenario = test_scenario::begin(DEPLOYER);
    let (mut treasury, mut rwa_reg) = init_test(&mut scenario);
    let mut investors = scenario.take_shared<InvestorRegistry<RWA>>();
    investors.register_investor(
        INVESTOR,
        b"US".to_string(),
        INVESTOR,
    );
    scenario.next_tx(DEPLOYER);
    let config = scenario.take_shared<ComplianceConfig<RWA>>();
    let rule = scenario.take_shared<RwaRule<RWA>>();
    treasury::mint(
        &mut treasury,
        &investors,
        &config,
        &mut rwa_reg,
        &rule,
        INVESTOR,
        10_000_000_000,
        scenario.ctx(),
    );

    scenario.next_tx(INVESTOR);
    let owner_proof = vault::proof_as_sender(scenario.ctx());
    vault::claim(&mut rwa_reg, owner_proof);

    // assert that the vault exists and has the correct balance
    scenario.next_tx(DEPLOYER);
    let mut vault = scenario.take_shared<RwaVault>();
    let receiving = test_scenario::most_recent_receiving_ticket<RwaToken<RWA>>(&object::id(&vault));
    vault::squash_tokens<RWA>(&mut vault, vector[receiving]); 
    assert!(vault.get_balance<RWA>() == 10_000_000_000);
    
    destroy(treasury);
    destroy(rwa_reg);
    destroy(investors);
    destroy(config);
    destroy(rule);
    destroy(vault);

    scenario.end();
}

#[test]
fun test_rwa_transfer() {
    let mut scenario = test_scenario::begin(DEPLOYER);
    let (mut treasury, mut rwa_reg) = init_test(&mut scenario);
    let mut investors = scenario.take_shared<InvestorRegistry<RWA>>();
    investors.register_investor(
        INVESTOR,
        b"US".to_string(),
        INVESTOR,
    );
    investors.register_investor(
        INVESTOR_2,
        b"US".to_string(),
        INVESTOR_2,
    );
    scenario.next_tx(DEPLOYER);
    let config = scenario.take_shared<ComplianceConfig<RWA>>();
    let rule = scenario.take_shared<RwaRule<RWA>>();
    treasury::mint(
        &mut treasury,
        &investors,
        &config,
        &mut rwa_reg,
        &rule,
        INVESTOR,
        10_000_000_000,
        scenario.ctx(),
    );

    scenario.next_tx(INVESTOR);
    let owner_proof = vault::proof_as_sender(scenario.ctx());
    vault::claim(&mut rwa_reg, owner_proof);

    // assert that the vault exists and has the correct balance
    scenario.next_tx(DEPLOYER);
    let mut vault = scenario.take_shared<RwaVault>();
    let receiving = test_scenario::most_recent_receiving_ticket<RwaToken<RWA>>(&object::id(&vault));
    vault::squash_tokens<RWA>(&mut vault, vector[receiving]);

    scenario.next_tx(INVESTOR_2);
    let owner_proof = vault::proof_as_sender(scenario.ctx());
    vault::claim(&mut rwa_reg, owner_proof);

    scenario.next_tx(INVESTOR);
    let mut vault_2 = scenario.take_shared<RwaVault>();
    let owner_proof = vault::proof_as_sender(scenario.ctx());
    let req = vault::transfer_to_vault(&mut vault, &owner_proof, 5_000_000_000, &mut vault_2, scenario.ctx());
    compliance::validate_transfer(&rule, req, &config, &investors, scenario.ctx());

    scenario.next_tx(DEPLOYER);
    assert!(vault.get_balance<RWA>() == 5_000_000_000);
    assert!(vault_2.get_balance<RWA>() == 5_000_000_000);


    
    destroy(treasury);
    destroy(rwa_reg);
    destroy(investors);
    destroy(config);
    destroy(rule);
    destroy(vault);
    destroy(vault_2);

    scenario.end();
}

#[test]
fun test_rwa_burn() {
    let mut scenario = test_scenario::begin(DEPLOYER);
    let (mut treasury, mut rwa_reg) = init_test(&mut scenario);
    let mut investors = scenario.take_shared<InvestorRegistry<RWA>>();
    investors.register_investor(
        INVESTOR,
        b"US".to_string(),
        INVESTOR,
    );
    scenario.next_tx(DEPLOYER);
    let config = scenario.take_shared<ComplianceConfig<RWA>>();
    let rule = scenario.take_shared<RwaRule<RWA>>();
    treasury::mint(
        &mut treasury,
        &investors,
        &config,
        &mut rwa_reg,
        &rule,
        INVESTOR,
        10_000_000_000,
        scenario.ctx(),
    );

    scenario.next_tx(INVESTOR);
    let owner_proof = vault::proof_as_sender(scenario.ctx());
    vault::claim(&mut rwa_reg, owner_proof);

    // assert that the vault exists and has the correct balance
    scenario.next_tx(DEPLOYER);
    let mut vault = scenario.take_shared<RwaVault>();
    let receiving = test_scenario::most_recent_receiving_ticket<RwaToken<RWA>>(&object::id(&vault));
    vault::squash_tokens<RWA>(&mut vault, vector[receiving]); 

    scenario.next_tx(DEPLOYER);
    treasury::burn(
        &mut treasury,
        &investors,
        &config,
        &rule,
        &mut vault,
        9_000_000_000,
        scenario.ctx(),
    );
    assert!(vault.get_balance<RWA>() == 1_000_000_000);
    
    destroy(treasury);
    destroy(rwa_reg);
    destroy(investors);
    destroy(config);
    destroy(rule);
    destroy(vault);

    scenario.end();
}

#[test]
fun test_rwa_clawback() {
    let mut scenario = test_scenario::begin(DEPLOYER);
    let (mut treasury, mut rwa_reg) = init_test(&mut scenario);
    let mut investors = scenario.take_shared<InvestorRegistry<RWA>>();
    investors.register_investor(
        INVESTOR,
        b"US".to_string(),
        INVESTOR,
    );

    scenario.next_tx(DEPLOYER);
    let config = scenario.take_shared<ComplianceConfig<RWA>>();
    let rule = scenario.take_shared<RwaRule<RWA>>();
    treasury::mint(
        &mut treasury,
        &investors,
        &config,
        &mut rwa_reg,
        &rule,
        INVESTOR,
        10_000_000_000,
        scenario.ctx(),
    );

    scenario.next_tx(INVESTOR);
    let owner_proof = vault::proof_as_sender(scenario.ctx());
    vault::claim(&mut rwa_reg, owner_proof);

    // assert that the vault exists and has the correct balance
    scenario.next_tx(DEPLOYER);
    let mut vault = scenario.take_shared<RwaVault>();
    let receiving = test_scenario::most_recent_receiving_ticket<RwaToken<RWA>>(&object::id(&vault));
    vault::squash_tokens<RWA>(&mut vault, vector[receiving]);

    scenario.next_tx(DEPLOYER);
    compliance::clawback(
        &config,
        &mut rwa_reg,
        &rule,
        &mut vault,
        10_000_000_000,
        scenario.ctx(),
    );

    scenario.next_tx(DEPLOYER);
    assert!(vault.get_balance<RWA>() == 0);
    
    destroy(treasury);
    destroy(rwa_reg);
    destroy(investors);
    destroy(config);
    destroy(rule);
    destroy(vault);

    scenario.end();
}

#[test, expected_failure(abort_code = compliance::ENotSameCountry)]
fun test_rwa_transfer_invalid() {
    let mut scenario = test_scenario::begin(DEPLOYER);
    let (mut treasury, mut rwa_reg) = init_test(&mut scenario);
    let mut investors = scenario.take_shared<InvestorRegistry<RWA>>();
    investors.register_investor(
        INVESTOR,
        b"US".to_string(),
        INVESTOR,
    );
    investors.register_investor(
        INVESTOR_2,
        b"UK".to_string(),
        INVESTOR_2,
    );
    scenario.next_tx(DEPLOYER);
    let config = scenario.take_shared<ComplianceConfig<RWA>>();
    let rule = scenario.take_shared<RwaRule<RWA>>();
    treasury::mint(
        &mut treasury,
        &investors,
        &config,
        &mut rwa_reg,
        &rule,
        INVESTOR,
        10_000_000_000,
        scenario.ctx(),
    );

    scenario.next_tx(INVESTOR);
    let owner_proof = vault::proof_as_sender(scenario.ctx());
    vault::claim(&mut rwa_reg, owner_proof);

    // assert that the vault exists and has the correct balance
    scenario.next_tx(DEPLOYER);
    let mut vault = scenario.take_shared<RwaVault>();
    let receiving = test_scenario::most_recent_receiving_ticket<RwaToken<RWA>>(&object::id(&vault));
    vault::squash_tokens<RWA>(&mut vault, vector[receiving]);

    scenario.next_tx(INVESTOR_2);
    let owner_proof = vault::proof_as_sender(scenario.ctx());
    vault::claim(&mut rwa_reg, owner_proof);

    scenario.next_tx(INVESTOR);
    let mut vault_2 = scenario.take_shared<RwaVault>();
    let owner_proof = vault::proof_as_sender(scenario.ctx());
    let req = vault::transfer_to_vault(&mut vault, &owner_proof, 5_000_000_000, &mut vault_2, scenario.ctx());
    compliance::validate_transfer(&rule, req, &config, &investors, scenario.ctx());

    abort
}

#[test, expected_failure(abort_code = investors::ENotRegistered)]
fun test_rwa_transfer_not_registered() {
    let mut scenario = test_scenario::begin(DEPLOYER);
    let (mut treasury, mut rwa_reg) = init_test(&mut scenario);
    let mut investors = scenario.take_shared<InvestorRegistry<RWA>>();
    investors.register_investor(
        INVESTOR,
        b"US".to_string(),
        INVESTOR,
    );

    scenario.next_tx(DEPLOYER);
    let config = scenario.take_shared<ComplianceConfig<RWA>>();
    let rule = scenario.take_shared<RwaRule<RWA>>();
    treasury::mint(
        &mut treasury,
        &investors,
        &config,
        &mut rwa_reg,
        &rule,
        INVESTOR,
        10_000_000_000,
        scenario.ctx(),
    );

    scenario.next_tx(INVESTOR);
    let owner_proof = vault::proof_as_sender(scenario.ctx());
    vault::claim(&mut rwa_reg, owner_proof);

    // assert that the vault exists and has the correct balance
    scenario.next_tx(DEPLOYER);
    let mut vault = scenario.take_shared<RwaVault>();
    let receiving = test_scenario::most_recent_receiving_ticket<RwaToken<RWA>>(&object::id(&vault));
    vault::squash_tokens<RWA>(&mut vault, vector[receiving]);

    scenario.next_tx(INVESTOR_2);
    let owner_proof = vault::proof_as_sender(scenario.ctx());
    vault::claim(&mut rwa_reg, owner_proof);

    scenario.next_tx(INVESTOR);
    let mut vault_2 = scenario.take_shared<RwaVault>();
    let owner_proof = vault::proof_as_sender(scenario.ctx());
    let req = vault::transfer_to_vault(&mut vault, &owner_proof, 5_000_000_000, &mut vault_2, scenario.ctx());
    compliance::validate_transfer(&rule, req, &config, &investors, scenario.ctx());

    abort
}

fun init_test(scenario: &mut Scenario): (Treasury<RWA>, RwaRegistry) {
    scenario.next_tx(@0x0);
    let mut coin_reg = coin_registry::create_coin_data_registry_for_testing(scenario.ctx());
    scenario.next_tx(DEPLOYER);
    setup::init_for_testing(scenario.ctx());
    scenario.next_tx(DEPLOYER);
    let reg = scenario.take_shared<DeployerRegistry>();
    rwa::create_rwa(&reg, &mut coin_reg, scenario.ctx());
    scenario.next_tx(DEPLOYER);
    let treasury = scenario.take_shared<Treasury<RWA>>();
    let mut rwa_reg = registry::create_for_testing(scenario.ctx());
    treasury::register_rule<RWA>(&treasury, &mut rwa_reg, true);

    destroy(coin_reg);
    destroy(reg);

    (treasury, rwa_reg)
}
