#[test_only, allow(unused_variable, unused_mut_ref, dead_code)]
module pas::e2e;

use pas::{rule, vault::{Self, Vault}};
use std::unit_test::{assert_eq, destroy};
use sui::{balance::{Self, send_funds}, sui::SUI, test_scenario::return_shared};

public struct A has drop {}
public struct B has drop {}
public struct ExtUSD has drop {}

public struct AWitness() has drop;
public struct BWitness() has drop;

#[test]
fun e2e() {
    test_tx!(@0x1, |namespace, managed_rule, unmanaged_rule, scenario| {
        scenario.next_tx(@0x1);

        let namespace_id = object::id(namespace);

        // create vaults of 0x1 and 0x2
        let vault = vault::create(namespace, @0x1);
        let another_vault = vault::create(namespace, @0x2);

        // transfer some funds to both 0x1 and 0x2
        vault.deposit_funds(balance::create_for_testing<A>(100));

        balance::create_for_testing<B>(50).send_funds(namespace.vault_address(@0x2));

        vault.share();
        another_vault.share();

        scenario.next_tx(@0x1);

        let mut vault = scenario.take_shared_by_id<Vault>(namespace
            .vault_address(
                @0x1,
            )
            .to_id());
        let another_vault = scenario.take_shared_by_id<Vault>(namespace
            .vault_address(@0x2)
            .to_id());

        let auth = vault::new_auth(scenario.ctx());
        let transfer_request = vault.transfer_funds<A>(&auth, &another_vault, 50, scenario.ctx());

        // Stamp the request (authorized action)
        managed_rule.resolve_transfer_funds(transfer_request, AWitness());

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

        let mut vault = scenario.take_shared_by_id<Vault>(namespace
            .vault_address(
                @0x1,
            )
            .to_id());

        let auth = vault::new_auth(scenario.ctx());
        let transfer_request = vault.unsafe_transfer_funds<A>(
            &auth,
            @0x2,
            50,
            scenario.ctx(),
        );

        // Stamp the request (authorized action)
        managed_rule.resolve_transfer_funds(transfer_request, BWitness());
        abort
    });
}

#[test]
fun test_address_and_derivation_matches() {
    test_tx!(@0x1, |namespace, managed_rule, _unmanaged_rule, scenario| {
        let user_one_vault_id = namespace.vault_address(@0x1).to_id();
        let user_two_vault_id = namespace.vault_address(@0x2).to_id();

        scenario.next_tx(@0x1);
        vault::create_and_share(namespace, @0x1);
        vault::create_and_share(namespace, @0x2);

        scenario.next_tx(@0x1);

        let mut user_one_vault = scenario.take_shared_by_id<Vault>(user_one_vault_id);
        let user_two_vault = scenario.take_shared_by_id<Vault>(user_two_vault_id);

        let auth = vault::new_auth(scenario.ctx());

        let transfer_request = user_one_vault.unsafe_transfer_funds<A>(
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
        let safe_request = user_one_vault.transfer_funds<A>(
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

#[test]
fun unlock_funds_successfully() {
    test_tx!(@0x1, |namespace, managed_rule, _unmanaged_rule, scenario| {
        scenario.next_tx(@0x1);
        let mut vault = vault::create(namespace, @0x1);
        vault.deposit_funds(balance::create_for_testing<A>(100));

        let auth = vault::new_auth(scenario.ctx());
        let unlock_request = vault.unlock_funds<A>(&auth, 50, scenario.ctx());

        let balance = managed_rule.resolve_unlock_funds(unlock_request, AWitness());
        assert_eq!(balance.value(), 50);

        vault.share();

        balance.send_funds(@0x10);
    });
}

#[test, expected_failure(abort_code = ::pas::vault::ENotOwner)]
fun try_to_auth_to_another_owners_vault() {
    test_tx!(@0x1, |namespace, managed_rule, _unmanaged_rule, scenario| {
        scenario.next_tx(@0x1);
        vault::create_and_share(namespace, @0x1);

        scenario.next_tx(@0x2);

        let mut vault = scenario.take_shared_by_id<Vault>(namespace
            .vault_address(
                @0x1,
            )
            .to_id());

        let auth = vault::new_auth(scenario.ctx());

        let transfer_request = vault.unsafe_transfer_funds<A>(
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

#[test, expected_failure(abort_code = ::pas::unlock_funds_request::ECannotResolveManagedAssets)]
fun try_to_resolve_unlock_funds_request_for_managed_assets() {
    test_tx!(@0x1, |namespace, managed_rule, _unmanaged_rule, scenario| {
        scenario.next_tx(@0x1);
        let mut vault = vault::create(namespace, @0x1);
        vault.deposit_funds(balance::create_for_testing<A>(100));

        let auth = vault::new_auth(scenario.ctx());
        let unlock_request = vault.unlock_funds<A>(&auth, 50, scenario.ctx());

        let _balance = unlock_request.resolve_unrestricted(namespace);
        abort
    });
}

#[test]
fun unlock_non_managed_funds() {
    test_tx!(@0x1, |namespace, managed_rule, _unmanaged_rule, scenario| {
        scenario.next_tx(@0x1);
        let mut vault = vault::create(namespace, @0x1);
        vault.deposit_funds(balance::create_for_testing<SUI>(100));

        let auth = vault::new_auth(scenario.ctx());
        let unlock_request = vault.unlock_funds<SUI>(&auth, 100, scenario.ctx());
        let balance = unlock_request.resolve_unrestricted(namespace);

        balance.send_funds(@0x1);

        vault.share();
    });
}

#[test, expected_failure(abort_code = ::pas::rule::EFundManagementAlreadyEnabled)]
fun try_to_disable_clawbacks_for_managed_assets() {
    test_tx!(@0x1, |namespace, managed_rule, _unmanaged_rule, scenario| {
        scenario.next_tx(@0x1);

        // Try to disable clawbacks.
        managed_rule.enable_funds_management(AWitness(), false);

        abort
    });
}

#[test, expected_failure(abort_code = ::pas::rule::EFundManagementNotEnabled)]
fun try_to_transfer_unmanaged_assets() {
    test_tx!(@0x1, |namespace, managed_rule, _unmanaged_rule, scenario| {
        scenario.next_tx(@0x1);

        // create a rule but do not enable funds management.
        let rule = rule::new(namespace, internal::permit<ExtUSD>(), internal::permit<ExtUSD>());

        // somehow transfer balance<ExtUSD> to vault a
        let mut vault = vault::create(namespace, @0x1);
        vault.deposit_funds(balance::create_for_testing<ExtUSD>(100));

        // Try to authorize a transfer which cannot conclude until registration is finalized.
        let auth = vault::new_auth(scenario.ctx());

        let transfer_request = vault.unsafe_transfer_funds<ExtUSD>(
            &auth,
            @0x2,
            50,
            scenario.ctx(),
        );

        rule.resolve_transfer_funds(transfer_request, internal::permit<ExtUSD>());

        abort
    });
}

#[test, expected_failure(abort_code = ::pas::rule::EFundManagementNotEnabled)]
fun try_to_unlock_unmanaged_assets() {
    test_tx!(@0x1, |namespace, managed_rule, _unmanaged_rule, scenario| {
        scenario.next_tx(@0x1);

        // create a rule but do not enable funds management.
        let rule = rule::new(namespace, internal::permit<ExtUSD>(), internal::permit<ExtUSD>());

        // somehow transfer balance<ExtUSD> to vault a
        let mut vault = vault::create(namespace, @0x1);
        vault.deposit_funds(balance::create_for_testing<ExtUSD>(100));

        // Try to authorize a transfer which cannot conclude until registration is finalized.
        let auth = vault::new_auth(scenario.ctx());
        let unlock_request = vault.unlock_funds<ExtUSD>(
            &auth,
            50,
            scenario.ctx(),
        );

        let _balance = rule.resolve_unlock_funds(unlock_request, internal::permit<ExtUSD>());

        abort
    });
}

#[test]
fun clawback_managed_assets() {
    test_tx!(@0x1, |namespace, managed_rule, _unmanaged_rule, scenario| {
        scenario.next_tx(@0x1);
        let mut vault = vault::create(namespace, @0x1);
        vault.deposit_funds(balance::create_for_testing<A>(100));

        let balance = managed_rule.clawback_funds(&mut vault, 50, AWitness());
        assert_eq!(balance.value(), 50);

        vault.share();

        balance.send_funds(@0x10);
    });
}

#[test, expected_failure(abort_code = ::pas::rule::EClawbackNotAllowed)]
fun try_to_clawback_unmanaged_assets() {
    test_tx!(@0x1, |namespace, _managed_rule, unmanaged_rule, scenario| {
        scenario.next_tx(@0x1);
        let mut vault = vault::create(namespace, @0x1);
        vault.deposit_funds(balance::create_for_testing<B>(100));

        let _balance = unmanaged_rule.clawback_funds(&mut vault, 50, BWitness());

        abort
    });
}

#[test]
fun derivation_is_consistent() {
    test_tx!(@0x1, |namespace, managed_rule, _unmanaged_rule, scenario| {
        scenario.next_tx(@0x1);
        let vault = vault::create(namespace, @0x1);

        assert_eq!(namespace.vault_address(@0x1), object::id(&vault).to_address());
        assert_eq!(namespace.rule_address<A>(), object::id(managed_rule).to_address());

        vault.share();
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
        assert_eq!(object::id(&vault).to_address(), namespace.vault_address(uid_address));

        let auth = vault::new_auth_as_object(&mut uid);

        let transfer_request = vault.unsafe_transfer_funds<A>(
            &auth,
            @0x2,
            50,
            scenario.ctx(),
        );

        assert_eq!(transfer_request.from(), uid_address);
        assert_eq!(transfer_request.to(), @0x2);
        assert_eq!(transfer_request.from_vault_id(), namespace.vault_address(uid_address).to_id());
        assert_eq!(transfer_request.to_vault_id(), namespace.vault_address(@0x2).to_id());
        assert_eq!(transfer_request.amount(), 50);

        destroy(transfer_request);

        return_shared(vault);
        uid.delete();
    });
}

#[test]
fun test_unlock_request_getters() {
    test_tx!(@0x1, |namespace, managed_rule, _unmanaged_rule, scenario| {
        scenario.next_tx(@0x1);
        let mut vault = vault::create(namespace, @0x1);
        vault.deposit_funds(balance::create_for_testing<A>(100));

        let auth = vault::new_auth(scenario.ctx());

        let unlock_request = vault.unlock_funds<A>(&auth, 50, scenario.ctx());

        assert_eq!(unlock_request.from(), @0x1);
        assert_eq!(unlock_request.from_vault_id(), namespace.vault_address(@0x1).to_id());
        assert_eq!(unlock_request.amount(), 50);

        destroy(unlock_request);
        vault.share();
    });
}

#[test, expected_failure(abort_code = ::pas::rule::ERuleAlreadyExists)]
fun try_to_create_duplicate_rule() {
    test_tx!(@0x1, |namespace, managed_rule, _unmanaged_rule, scenario| {
        scenario.next_tx(@0x1);
        let rule = rule::new(namespace, internal::permit<A>(), AWitness());

        abort
    });
}

/// A test_tx already set up for convenience.
public macro fun test_tx(
    $admin: address,
    $f: |
        &mut pas::namespace::Namespace,
        &mut pas::rule::Rule<A>,
        &mut pas::rule::Rule<B>,
        &mut sui::test_scenario::Scenario,
    |,
) {
    let mut scenario = sui::test_scenario::begin($admin);

    pas::namespace::init_for_testing(scenario.ctx());

    scenario.next_tx($admin);

    let mut namespace = scenario.take_shared<pas::namespace::Namespace>();

    let mut rule_a = pas::rule::new(&mut namespace, internal::permit<A>(), AWitness());
    rule_a.enable_funds_management(AWitness(), true);
    rule_a.share();

    let mut rule_b = pas::rule::new(&mut namespace, internal::permit<B>(), BWitness());
    rule_b.enable_funds_management(BWitness(), false);
    rule_b.share();

    scenario.next_tx($admin);

    let mut managed_rule = scenario.take_shared<pas::rule::Rule<A>>();
    let mut unmanaged_rule = scenario.take_shared<pas::rule::Rule<B>>();

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
    scenario.end();
}
