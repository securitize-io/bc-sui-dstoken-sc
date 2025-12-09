#[test_only]
module rwa::rule_tests;

use rwa::{
    registry::{Self, RwaRegistry},
    rule::{Self, RwaRule},
    vault::{Self, RwaVault, vault_key_for_testing}
};
use sui::{
    coin::{Self, TreasuryCap},
    derived_object,
    test_scenario::{Self as ts, Scenario},
    test_utils::destroy
};

/// Test coin type
public struct TEST_COIN has drop {}

/// Authorization witness
public struct AuthWitness has drop {}

/// Invalid authorization witness
public struct InvalidAuthWitness has drop {}

// // ========== Helper Functions ==========

fun setup_registry(scenario: &mut Scenario) {
    scenario.next_tx(@0x0);
    let registry = registry::create_for_testing(scenario.ctx());
    registry::share_for_testing(registry);
}

fun create_test_coin(_scenario: &mut Scenario): TreasuryCap<TEST_COIN> {
    // Create a treasury cap for testing without OTW requirement
    coin::create_treasury_cap_for_testing<TEST_COIN>(_scenario.ctx())
}

// // ========== Rule Creation Tests ==========

#[test]
fun test_create_rule_success() {
    let mut scenario = ts::begin(@0x0);
    setup_registry(&mut scenario);

    scenario.next_tx(@0x0);
    let mut registry = scenario.take_shared<RwaRegistry>();
    let treasury_cap = create_test_coin(&mut scenario);

    // Create rule without clawback
    rule::new<TEST_COIN, AuthWitness>(
        &mut registry,
        &treasury_cap,
        false,
        AuthWitness {},
    );

    ts::return_shared(registry);
    destroy(treasury_cap);
    scenario.end();
}

#[test]
fun test_create_rule_with_clawback() {
    let mut scenario = ts::begin(@0x0);
    setup_registry(&mut scenario);

    scenario.next_tx(@0x0);
    let mut registry = scenario.take_shared<RwaRegistry>();
    let treasury_cap = create_test_coin(&mut scenario);

    // Create rule with clawback enabled
    rule::new<TEST_COIN, AuthWitness>(
        &mut registry,
        &treasury_cap,
        true,
        AuthWitness {},
    );

    ts::return_shared(registry);
    destroy(treasury_cap);
    scenario.end();
}

#[test, expected_failure(abort_code = rule::EVaultAlreadyExists)]
fun test_create_rule_twice_fails() {
    let mut scenario = ts::begin(@0x0);
    setup_registry(&mut scenario);

    scenario.next_tx(@0x0);
    let mut registry = scenario.take_shared<RwaRegistry>();
    let treasury_cap = create_test_coin(&mut scenario);

    // Create rule first time
    rule::new<TEST_COIN, AuthWitness>(
        &mut registry,
        &treasury_cap,
        false,
        AuthWitness {},
    );

    // Try to create rule again - should fail
    rule::new<TEST_COIN, AuthWitness>(
        &mut registry,
        &treasury_cap,
        false,
        AuthWitness {},
    );

    abort
}

// ========== Transfer Resolution Tests ==========

#[test]
fun test_resolve_transfer_success() {
    let mut scenario = ts::begin(@0x0);
    setup_registry(&mut scenario);

    scenario.next_tx(@0x0);
    let mut registry = scenario.take_shared<RwaRegistry>();
    let mut treasury_cap = create_test_coin(&mut scenario);

    // Create rule
    rule::new<TEST_COIN, AuthWitness>(
        &mut registry,
        &treasury_cap,
        false,
        AuthWitness {},
    );

    // Create vaults
    let sender = @0x1;
    let receiver = @0x2;
    vault::claim(&mut registry, vault::owner_from_address(sender));
    vault::claim(&mut registry, vault::owner_from_address(receiver));

    scenario.next_tx(sender);
    let rule = scenario.take_shared<RwaRule<TEST_COIN>>();

    let sender_vault_id = derived_object::derive_address(
        registry.uid_mut().to_inner(),
        vault_key_for_testing(sender),
    );
    let mut sender_vault = scenario.take_shared_by_id<RwaVault>(sender_vault_id.to_id());

    // Mint and deposit to sender vault
    let coins = treasury_cap.mint(1000, scenario.ctx());
    sender_vault.deposit_balance(coins.into_balance());

    // Initiate transfer
    let owner_proof = vault::proof_as_sender_for_testing(sender);
    let transfer_request = vault::transfer<TEST_COIN>(
        &mut sender_vault,
        &owner_proof,
        100,
        receiver,
        scenario.ctx(),
    );

    // Resolve transfer
    rule::resolve_transfer(&rule, transfer_request, AuthWitness {});

    ts::return_shared(rule);
    ts::return_shared(sender_vault);
    ts::return_shared(registry);
    destroy(treasury_cap);
    scenario.end();
}

#[test, expected_failure(abort_code = rule::EInvalidProof)]
fun test_resolve_transfer_invalid_witness() {
    let mut scenario = ts::begin(@0x0);
    setup_registry(&mut scenario);

    scenario.next_tx(@0x0);
    let mut registry = scenario.take_shared<RwaRegistry>();
    let mut treasury_cap = create_test_coin(&mut scenario);

    // Create rule with AuthWitness
    rule::new<TEST_COIN, AuthWitness>(
        &mut registry,
        &treasury_cap,
        false,
        AuthWitness {},
    );

    // Create vaults
    let sender = @0x1;
    let receiver = @0x2;
    vault::claim(&mut registry, vault::owner_from_address(sender));
    vault::claim(&mut registry, vault::owner_from_address(receiver));

    scenario.next_tx(sender);
    let rule = scenario.take_shared<RwaRule<TEST_COIN>>();

    let sender_vault_id = derived_object::derive_address(
        registry.uid_mut().to_inner(),
        vault_key_for_testing(sender),
    );
    let mut sender_vault = scenario.take_shared_by_id<RwaVault>(sender_vault_id.to_id());

    // Mint and deposit
    let coins = treasury_cap.mint(1000, scenario.ctx());
    sender_vault.deposit_balance(coins.into_balance());

    // Initiate transfer
    let owner_proof = vault::proof_as_sender_for_testing(sender);
    let transfer_request = vault::transfer<TEST_COIN>(
        &mut sender_vault,
        &owner_proof,
        100,
        receiver,
        scenario.ctx(),
    );

    // Try to resolve with invalid witness - should fail
    rule::resolve_transfer(&rule, transfer_request, InvalidAuthWitness {});

    abort
}

// ========== Deposit Tests ==========

#[test]
fun test_deposit_success() {
    let mut scenario = ts::begin(@0x0);
    setup_registry(&mut scenario);

    scenario.next_tx(@0x0);
    let mut registry = scenario.take_shared<RwaRegistry>();
    let mut treasury_cap = create_test_coin(&mut scenario);

    // Create rule
    rule::new<TEST_COIN, AuthWitness>(
        &mut registry,
        &treasury_cap,
        false,
        AuthWitness {},
    );

    // Create vault for receiver
    let receiver = @0x2;
    vault::claim(&mut registry, vault::owner_from_address(receiver));

    scenario.next_tx(@0x0);
    let rule = scenario.take_shared<RwaRule<TEST_COIN>>();

    let vault_id = derived_object::derive_address(
        registry.uid_mut().to_inner(),
        vault_key_for_testing(receiver),
    );
    let mut vault = scenario.take_shared_by_id<RwaVault>(vault_id.to_id());

    // Mint and deposit
    let coins = treasury_cap.mint(1000, scenario.ctx());
    rule::deposit_to_vault(&rule, &mut vault, coins.into_balance(), AuthWitness {});

    ts::return_shared(rule);
    ts::return_shared(vault);
    ts::return_shared(registry);
    destroy(treasury_cap);
    scenario.end();
}

#[test, expected_failure(abort_code = rule::EInvalidProof)]
fun test_deposit_invalid_witness() {
    let mut scenario = ts::begin(@0x0);
    setup_registry(&mut scenario);

    scenario.next_tx(@0x0);
    let mut registry = scenario.take_shared<RwaRegistry>();
    let mut treasury_cap = create_test_coin(&mut scenario);

    // Create rule with AuthWitness
    rule::new<TEST_COIN, AuthWitness>(
        &mut registry,
        &treasury_cap,
        false,
        AuthWitness {},
    );

    // Create vault
    let receiver = @0x2;
    vault::claim(&mut registry, vault::owner_from_address(receiver));

    scenario.next_tx(@0x0);
    let rule = scenario.take_shared<RwaRule<TEST_COIN>>();

    let vault_id = derived_object::derive_address(
        registry.uid_mut().to_inner(),
        vault_key_for_testing(receiver),
    );
    let mut vault = scenario.take_shared_by_id<RwaVault>(vault_id.to_id());

    // Mint and try to deposit with invalid witness - should fail
    let coins = treasury_cap.mint(1000, scenario.ctx());
    rule::deposit_to_vault(&rule, &mut vault, coins.into_balance(), InvalidAuthWitness {});

    abort
}

// ========== Withdraw Tests ==========

#[test]
fun test_withdraw_success() {
    let mut scenario = ts::begin(@0x0);
    setup_registry(&mut scenario);

    scenario.next_tx(@0x0);
    let mut registry = scenario.take_shared<RwaRegistry>();
    let mut treasury_cap = create_test_coin(&mut scenario);

    // Create rule
    rule::new<TEST_COIN, AuthWitness>(
        &mut registry,
        &treasury_cap,
        false,
        AuthWitness {},
    );

    // Create vault
    let owner = @0x1;
    vault::claim(&mut registry, vault::owner_from_address(owner));

    scenario.next_tx(owner);
    let rule = scenario.take_shared<RwaRule<TEST_COIN>>();

    let vault_id = derived_object::derive_address(
        registry.uid_mut().to_inner(),
        vault_key_for_testing(owner),
    );
    let mut vault_obj = scenario.take_shared_by_id<RwaVault>(vault_id.to_id());

    // Mint and deposit
    let coins = treasury_cap.mint(1000, scenario.ctx());
    vault_obj.deposit_balance(coins.into_balance());

    // Withdraw with rule
    let owner_proof = vault::proof_as_sender_for_testing(owner);
    let balance = rule::withdraw_from_vault<TEST_COIN, AuthWitness>(
        &rule,
        &mut vault_obj,
        &owner_proof,
        100,
        AuthWitness {},
    );

    balance.destroy_for_testing();
    ts::return_shared(registry);
    ts::return_shared(rule);
    ts::return_shared(vault_obj);
    destroy(treasury_cap);
    scenario.end();
}

#[test, expected_failure(abort_code = rule::EInvalidProof)]
fun test_withdraw_invalid_witness() {
    let mut scenario = ts::begin(@0x0);
    setup_registry(&mut scenario);

    scenario.next_tx(@0x0);
    let mut registry = scenario.take_shared<RwaRegistry>();
    let mut treasury_cap = create_test_coin(&mut scenario);

    // Create rule with AuthWitness
    rule::new<TEST_COIN, AuthWitness>(
        &mut registry,
        &treasury_cap,
        false,
        AuthWitness {},
    );

    // Create vault
    let owner = @0x1;
    vault::claim(&mut registry, vault::owner_from_address(owner));

    scenario.next_tx(owner);
    let rule = scenario.take_shared<RwaRule<TEST_COIN>>();

    let vault_id = derived_object::derive_address(
        registry.uid_mut().to_inner(),
        vault_key_for_testing(owner),
    );
    let mut vault_obj = scenario.take_shared_by_id<RwaVault>(vault_id.to_id());

    // Mint and deposit
    let coins = treasury_cap.mint(1000, scenario.ctx());
    vault_obj.deposit_balance(coins.into_balance());

    // Try to withdraw with invalid witness - should fail
    let owner_proof = vault::proof_as_sender_for_testing(owner);
    let _balance = rule::withdraw_from_vault<TEST_COIN, InvalidAuthWitness>(
        &rule,
        &mut vault_obj,
        &owner_proof,
        100,
        InvalidAuthWitness {},
    );

    abort
}

#[test, expected_failure(abort_code = vault::ENotOwner)]
fun test_withdraw_invalid_owner() {
    let mut scenario = ts::begin(@0x0);
    setup_registry(&mut scenario);

    scenario.next_tx(@0x0);
    let mut registry = scenario.take_shared<RwaRegistry>();
    let mut treasury_cap = create_test_coin(&mut scenario);

    // Create rule
    rule::new<TEST_COIN, AuthWitness>(
        &mut registry,
        &treasury_cap,
        false,
        AuthWitness {},
    );

    // Create vault for owner
    let owner = @0x1;
    vault::claim(&mut registry, vault::owner_from_address(owner));

    scenario.next_tx(owner);
    let rule = scenario.take_shared<RwaRule<TEST_COIN>>();

    let vault_id = derived_object::derive_address(
        registry.uid_mut().to_inner(),
        vault_key_for_testing(owner),
    );
    let mut vault_obj = scenario.take_shared_by_id<RwaVault>(vault_id.to_id());

    // Mint and deposit
    let coins = treasury_cap.mint(1000, scenario.ctx());
    vault_obj.deposit_balance(coins.into_balance());

    // Try to withdraw with wrong owner proof - should fail
    let wrong_owner_proof = vault::proof_as_sender_for_testing(@0x999);
    let _balance = rule::withdraw_from_vault<TEST_COIN, AuthWitness>(
        &rule,
        &mut vault_obj,
        &wrong_owner_proof,
        100,
        AuthWitness {},
    );

    abort
}
