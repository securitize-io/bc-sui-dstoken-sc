#[test_only, allow(unused_variable, unused_mut_ref, dead_code)]
module pas::e2e;

use pas::vault::{Self, Vault, vault_address};
use std::unit_test::{assert_eq, destroy};
use sui::{balance::{Self, send_funds}, test_scenario::return_shared};

public struct MANAGED has drop {}
public struct UNMANAGED has drop {}

public struct ManagedWitness() has drop;
public struct UnmanagedWitness() has drop;

#[test]
fun e2e() {
    test_tx!(@0x1, |namespace, managed_rule, unmanaged_rule, scenario| {
        scenario.next_tx(@0x1);

        let namespace_id = object::id(namespace);

        // create vaults of 0x1 and 0x2
        let vault = vault::create(namespace, @0x1);
        let another_vault = vault::create(namespace, @0x2);

        // transfer some funds to both 0x1 and 0x2
        managed_rule.mint(&vault, 100, ManagedWitness());

        balance::send_funds(
            balance::create_for_testing<UNMANAGED>(50),
            vault::vault_address(object::id(namespace), @0x2),
        );

        vault.share();
        another_vault.share();

        scenario.next_tx(@0x1);

        let mut vault = scenario.take_shared_by_id<Vault>(vault::vault_address(
            namespace_id,
            @0x1,
        ).to_id());
        let another_vault = scenario.take_shared_by_id<Vault>(vault::vault_address(
            namespace_id,
            @0x2,
        ).to_id());

        let auth = vault::new_auth(scenario.ctx());
        let transfer_request = vault.transfer<MANAGED>(&auth, &another_vault, 50, scenario.ctx());

        // Stamp the request (authorized action)
        managed_rule.resolve_transfer(transfer_request, ManagedWitness());

        return_shared(vault);
        return_shared(another_vault);
    });
}

#[test, expected_failure(abort_code = ::pas::rule::EInvalidProof)]
fun try_to_approve_transfer_with_invalid_witness() {
    test_tx!(@0x1, |namespace, managed_rule, _unmanaged_rule, scenario| {
        let namespace_id = object::id(namespace);
        scenario.next_tx(@0x1);
        vault::create_and_share(namespace, @0x1);

        scenario.next_tx(@0x1);

        let mut vault = scenario.take_shared_by_id<Vault>(vault::vault_address(
            namespace_id,
            @0x1,
        ).to_id());

        let auth = vault::new_auth(scenario.ctx());
        let transfer_request = vault.unsafe_transfer<MANAGED>(
            &auth,
            @0x2,
            50,
            scenario.ctx(),
        );

        // Stamp the request (authorized action)
        managed_rule.resolve_transfer(transfer_request, UnmanagedWitness());
        abort
    });
}

#[test]
fun test_address_and_derivation_matches() {
    test_tx!(@0x1, |namespace, managed_rule, _unmanaged_rule, scenario| {
        let namespace_id = object::id(namespace);

        let user_one_vault_id = vault::vault_address(namespace_id, @0x1).to_id();
        let user_two_vault_id = vault::vault_address(namespace_id, @0x2).to_id();

        scenario.next_tx(@0x1);
        vault::create_and_share(namespace, @0x1);
        vault::create_and_share(namespace, @0x2);

        scenario.next_tx(@0x1);

        let mut user_one_vault = scenario.take_shared_by_id<Vault>(user_one_vault_id);
        let user_two_vault = scenario.take_shared_by_id<Vault>(user_two_vault_id);

        let auth = vault::new_auth(scenario.ctx());

        let transfer_request = user_one_vault.unsafe_transfer<MANAGED>(
            &auth,
            @0x2,
            50,
            scenario.ctx(),
        );

        assert_eq!(transfer_request.from(), @0x1);
        assert_eq!(transfer_request.to(), @0x2);
        assert_eq!(transfer_request.from_vault_id(), user_one_vault_id);
        assert_eq!(transfer_request.to_vault_id(), user_two_vault_id);
        assert_eq!(transfer_request.amount(), 50);

        // Both scenarios must calculate the from/to equivalent.
        let safe_request = user_one_vault.transfer<MANAGED>(
            &auth,
            &user_two_vault,
            50,
            scenario.ctx(),
        );
        assert_eq!(safe_request.from(), @0x1);
        assert_eq!(safe_request.to(), @0x2);
        assert_eq!(safe_request.from_vault_id(), user_one_vault_id);
        assert_eq!(safe_request.to_vault_id(), user_two_vault_id);
        assert_eq!(safe_request.amount(), 50);

        destroy(transfer_request);
        destroy(safe_request);

        return_shared(user_one_vault);
        return_shared(user_two_vault);
    });
}

#[test, expected_failure(abort_code = ::pas::vault::ENotOwner)]
fun try_to_auth_to_another_owners_vault() {
    test_tx!(@0x1, |namespace, managed_rule, _unmanaged_rule, scenario| {
        scenario.next_tx(@0x1);
        vault::create_and_share(namespace, @0x1);

        scenario.next_tx(@0x2);

        let mut vault = scenario.take_shared_by_id<Vault>(vault::vault_address(
            object::id(namespace),
            @0x1,
        ).to_id());

        let auth = vault::new_auth(scenario.ctx());

        let transfer_request = vault.unsafe_transfer<MANAGED>(
            &auth,
            @0x2,
            50,
            scenario.ctx(),
        );

        abort
    });
}

#[test, expected_failure(abort_code = ::pas::vault::EVaultAlreadyExists)]
fun try_to_create_vault_with_same_owner() {
    test_tx!(@0x1, |namespace, managed_rule, _unmanaged_rule, scenario| {
        scenario.next_tx(@0x1);
        vault::create_and_share(namespace, @0x1);
        vault::create_and_share(namespace, @0x1);
        abort
    });
}

#[test]
fun authenticate_with_uid() {
    test_tx!(@0x1, |namespace, managed_rule, _unmanaged_rule, scenario| {
        let namespace_id = object::id(namespace);
        scenario.next_tx(@0x1);

        // create a UID.
        let mut uid = object::new(scenario.ctx());

        let uid_address = uid.to_inner().to_address();
        vault::create_and_share(namespace, uid_address);

        scenario.next_tx(@0x1);

        let mut vault = scenario.take_shared<Vault>();

        assert_eq!(vault.owner(), uid_address);
        assert_eq!(object::id(&vault).to_address(), vault_address(namespace_id, uid_address));

        let auth = vault::new_auth_as_object(&mut uid);

        let transfer_request = vault.unsafe_transfer<MANAGED>(
            &auth,
            @0x2,
            50,
            scenario.ctx(),
        );

        assert_eq!(transfer_request.from(), uid_address);
        assert_eq!(transfer_request.to(), @0x2);
        assert_eq!(
            transfer_request.from_vault_id(),
            vault_address(namespace_id, uid_address).to_id(),
        );
        assert_eq!(transfer_request.to_vault_id(), vault_address(namespace_id, @0x2).to_id());
        assert_eq!(transfer_request.amount(), 50);

        destroy(transfer_request);

        return_shared(vault);
        uid.delete();
    });
}

/// A test_tx already set up for convenience.
public macro fun test_tx(
    $admin: address,
    $f: |
        &mut pas::namespace::Namespace,
        &mut pas::rule::Rule<MANAGED>,
        &mut pas::rule::Rule<UNMANAGED>,
        &mut sui::test_scenario::Scenario,
    |,
) {
    let mut scenario = sui::test_scenario::begin($admin);

    pas::namespace::init_for_testing(scenario.ctx());

    scenario.next_tx($admin);

    let mut namespace = scenario.take_shared<pas::namespace::Namespace>();

    let managed_treasury_cap = sui::coin::create_treasury_cap_for_testing<MANAGED>(scenario.ctx());
    let unmanaged_treasury_cap = sui::coin::create_treasury_cap_for_testing<
        UNMANAGED,
    >(scenario.ctx());

    pas::rule::new_managed_treasury(
        &mut namespace,
        managed_treasury_cap,
        true,
        ManagedWitness(),
    );

    pas::rule::new(
        &mut namespace,
        &unmanaged_treasury_cap,
        false,
        UnmanagedWitness(),
    );

    scenario.next_tx($admin);

    let mut managed_rule = scenario.take_shared<pas::rule::Rule<MANAGED>>();
    let mut unmanaged_rule = scenario.take_shared<pas::rule::Rule<UNMANAGED>>();

    $f(
        &mut namespace,
        &mut managed_rule,
        &mut unmanaged_rule,
        &mut scenario,
    );

    scenario.next_tx($admin);

    sui::test_scenario::return_shared(namespace);
    sui::test_scenario::return_shared(managed_rule);
    sui::test_scenario::return_shared(unmanaged_rule);
    std::unit_test::destroy(unmanaged_treasury_cap);
    scenario.end();
}
