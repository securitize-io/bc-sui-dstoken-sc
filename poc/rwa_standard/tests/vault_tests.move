#[test_only]
module rwa::vault_tests;

use rwa::registry::{Self, RwaRegistry};
use rwa::vault::{Self, RwaVault};
use sui::coin::{Self, TreasuryCap};
use sui::derived_object;
use sui::test_scenario::{Self as ts, Scenario};
use sui::test_utils::destroy;
use std::unit_test::assert_eq;
use rwa::vault::vault_key_for_testing;

/// Test coin type
public struct TEST_COIN has drop {}

// ========== Helper Functions ==========

fun setup_registry(scenario: &mut Scenario) {
    scenario.next_tx(@0x0);
    let registry = registry::create_for_testing(scenario.ctx());
    registry::share_for_testing(registry);
}

fun create_test_coin(_scenario: &mut Scenario): TreasuryCap<TEST_COIN> {
    // Create a treasury cap for testing without OTW requirement
    coin::create_treasury_cap_for_testing<TEST_COIN>(_scenario.ctx())
}

// ========== Vault Creation Tests ==========

#[test]
fun test_claim_vault_for_address() {
    let mut scenario = ts::begin(@0x0);
    setup_registry(&mut scenario);

    scenario.next_tx(@0x1);
    let mut registry = scenario.take_shared<RwaRegistry>();

    // Claim vault for address
    let owner_proof = vault::proof_as_sender(scenario.ctx());
    vault::claim(&mut registry, owner_proof);

    scenario.next_tx(@0x1);

    // Verify vault exists and is shared
    let vault_id = derived_object::derive_address(registry.uid_mut().to_inner(), vault_key_for_testing(@0x1));
    let vault = scenario.take_shared_by_id<RwaVault>(vault_id.to_id());

    ts::return_shared(registry);
    ts::return_shared(vault);

    scenario.end();
}

#[test, expected_failure(abort_code = vault::EVaultAlreadyExists)]
fun test_claim_vault_twice_fails() {
    let mut scenario = ts::begin(@0x0);
    setup_registry(&mut scenario);

    scenario.next_tx(@0x1);
    let mut registry = scenario.take_shared<RwaRegistry>();

    // Claim vault first time
    let owner_proof1 = vault::proof_as_sender(scenario.ctx());
    vault::claim(&mut registry, owner_proof1);

    // Try to claim vault again - should fail
    let owner_proof2 = vault::proof_as_sender(scenario.ctx());
    vault::claim(&mut registry, owner_proof2);

    abort
}

// // ========== Deposit Tests ==========

#[test]
fun test_deposit_to_vault() {
    let mut scenario = ts::begin(@0x0);
    setup_registry(&mut scenario);

    scenario.next_tx(@0x0);
    let mut registry = scenario.take_shared<RwaRegistry>();
    let mut treasury_cap = create_test_coin(&mut scenario);

    // Create vault for receiver
    let receiver = @0x2;
    vault::claim(&mut registry, vault::proof_as_sender_for_testing(receiver));

    // Mint and deposit
    let coins = treasury_cap.mint(1000, scenario.ctx());
    let _deposit_request = vault::deposit_to_vault(
        &mut registry,
        coins.into_balance(),
        receiver,
        scenario.ctx()
    );

    destroy(_deposit_request);
    ts::return_shared(registry);
    destroy(treasury_cap);
    scenario.end();
}

// // ========== Withdraw Tests ==========

#[test]
fun test_withdraw_from_vault() {
    let mut scenario = ts::begin(@0x0);
    setup_registry(&mut scenario);

    scenario.next_tx(@0x0);
    let mut registry = scenario.take_shared<RwaRegistry>();
    let mut treasury_cap = create_test_coin(&mut scenario);

    // Create vault
    let owner = @0x1;
    vault::claim(&mut registry, vault::proof_as_sender_for_testing(owner));

    scenario.next_tx(owner);

    let vault_id = derived_object::derive_address(registry.uid_mut().to_inner(), vault_key_for_testing(owner));
    let mut vault_obj = scenario.take_shared_by_id<RwaVault>(vault_id.to_id());

    // Mint and deposit
    let coins = treasury_cap.mint(1000, scenario.ctx());
    vault_obj.deposit_balance(coins.into_balance());

    // Withdraw
    let (balance, _withdraw_request) = vault::withdraw_from_vault<TEST_COIN>(
        &mut vault_obj,
        100,
    );

    assert_eq!(balance.value(), 100);

    destroy(_withdraw_request);
    balance.destroy_for_testing();
    ts::return_shared(registry);
    ts::return_shared(vault_obj);
    destroy(treasury_cap);
    scenario.end();
}

// // ========== Transfer Tests ==========

#[test]
fun test_transfer_between_vaults() {
    let mut scenario = ts::begin(@0x0);
    setup_registry(&mut scenario);

    scenario.next_tx(@0x0);
    let mut registry = scenario.take_shared<RwaRegistry>();
    let mut treasury_cap = create_test_coin(&mut scenario);

    // Create vaults
    let sender = @0x1;
    let receiver = @0x2;
    vault::claim(&mut registry, vault::proof_as_sender_for_testing(sender));
    vault::claim(&mut registry, vault::proof_as_sender_for_testing(receiver));

    scenario.next_tx(sender);

    let sender_vault_id = derived_object::derive_address(registry.uid_mut().to_inner(), vault_key_for_testing(sender));
    let mut sender_vault = scenario.take_shared_by_id<RwaVault>(sender_vault_id.to_id());

    // Mint and deposit to sender vault
    let coins = treasury_cap.mint(1000, scenario.ctx());
    sender_vault.deposit_balance(coins.into_balance());

    // Initiate transfer
    let owner_proof = vault::proof_as_sender(scenario.ctx());
    let transfer_request = vault::transfer<TEST_COIN>(
        &mut sender_vault,
        &owner_proof,
        100,
        receiver,
        scenario.ctx()
    );

    // Verify request details
    assert_eq!(vault::request_amount(&transfer_request), 100);

    transfer_request.resolve_transfer();
    ts::return_shared(registry);
    ts::return_shared(sender_vault);
    destroy(treasury_cap);
    scenario.end();
}

#[test, expected_failure(abort_code = vault::ENotOwner)]
fun test_transfer_invalid_owner_proof() {
    let mut scenario = ts::begin(@0x0);
    setup_registry(&mut scenario);

    scenario.next_tx(@0x0);
    let mut registry = scenario.take_shared<RwaRegistry>();
    let mut treasury_cap = create_test_coin(&mut scenario);

    // Create vaults
    let sender = @0x1;
    let receiver = @0x2;
    vault::claim(&mut registry, vault::proof_as_sender_for_testing(sender));
    vault::claim(&mut registry, vault::proof_as_sender_for_testing(receiver));

    scenario.next_tx(sender);
    let sender_vault_id = derived_object::derive_address(registry.uid_mut().to_inner(), vault_key_for_testing(sender));
    let mut sender_vault = scenario.take_shared_by_id<RwaVault>(sender_vault_id.to_id());

    // Mint and deposit
    let coins = treasury_cap.mint(1000, scenario.ctx());
    sender_vault.deposit_balance(coins.into_balance());

    // Try to transfer with wrong owner proof - should fail
    let wrong_proof = vault::proof_as_sender_for_testing(@0x999);
    let _transfer_request = vault::transfer<TEST_COIN>(
        &mut sender_vault,
        &wrong_proof,
        100,
        receiver,
        scenario.ctx()
    );

    abort
}

#[test]
fun test_transfer_to_vault_direct() {
    let mut scenario = ts::begin(@0x0);
    setup_registry(&mut scenario);

    scenario.next_tx(@0x0);
    let mut registry = scenario.take_shared<RwaRegistry>();
    let mut treasury_cap = create_test_coin(&mut scenario);

    // Create vaults
    let sender = @0x1;
    let receiver = @0x2;
    vault::claim(&mut registry, vault::proof_as_sender_for_testing(sender));
    vault::claim(&mut registry, vault::proof_as_sender_for_testing(receiver));

    scenario.next_tx(sender);

    let sender_vault_id = derived_object::derive_address(registry.uid_mut().to_inner(), vault_key_for_testing(sender));
    let mut sender_vault = scenario.take_shared_by_id<RwaVault>(sender_vault_id.to_id());

    let receiver_vault_id = derived_object::derive_address(registry.uid_mut().to_inner(), vault_key_for_testing(receiver));
    let mut receiver_vault = scenario.take_shared_by_id<RwaVault>(receiver_vault_id.to_id());

    // Mint and deposit to sender vault
    let coins = treasury_cap.mint(1000, scenario.ctx());
    sender_vault.deposit_balance(coins.into_balance());

    // Transfer directly to receiver vault
    let owner_proof = vault::proof_as_sender(scenario.ctx());
    let transfer_request = vault::transfer_to_vault<TEST_COIN>(
        &mut sender_vault,
        &owner_proof,
        100,
        &mut receiver_vault,
        scenario.ctx()
    );

    assert_eq!(vault::request_amount(&transfer_request), 100);

    transfer_request.resolve_transfer();
    ts::return_shared(registry);
    ts::return_shared(sender_vault);
    ts::return_shared(receiver_vault);
    destroy(treasury_cap);
    scenario.end();
}

// // ========== Token Squashing Tests ==========

#[test]
fun test_squash_multiple_tokens() {
    let mut scenario = ts::begin(@0x0);
    setup_registry(&mut scenario);

    scenario.next_tx(@0x0);
    let mut registry = scenario.take_shared<RwaRegistry>();
    let mut treasury_cap = create_test_coin(&mut scenario);

    // Create vault
    let owner = @0x1;
    vault::claim(&mut registry, vault::proof_as_sender_for_testing(owner));

    scenario.next_tx(owner);
    let owner_vault_id = derived_object::derive_address(registry.uid_mut().to_inner(), vault_key_for_testing(owner));
    let mut vault = scenario.take_shared_by_id<RwaVault>(owner_vault_id.to_id());

    // Directly deposit balances (simulating squashed tokens)
    vault.deposit_balance(treasury_cap.mint(100, scenario.ctx()).into_balance());
    vault.deposit_balance(treasury_cap.mint(200, scenario.ctx()).into_balance());
    vault.deposit_balance(treasury_cap.mint(300, scenario.ctx()).into_balance());

    // Verify total by withdrawing
    let (balance, _request) = vault::withdraw_from_vault<TEST_COIN>(&mut vault, 600);
    assert_eq!(balance.value(), 600);

    balance.destroy_for_testing();
    ts::return_shared(vault);
    destroy(_request);
    ts::return_shared(registry);
    destroy(treasury_cap);
    scenario.end();
}