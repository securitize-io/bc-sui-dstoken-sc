#[test_only]
module securitize::trust_service_tests;

use securitize::{
    abilities::{SetAbilities, SetIssuer, SetTransferAgent, SetServiceOwner},
    test_helpers::{TEST_VOLORO, setup_with_treasury},
    trust_service::{Self, Auth, Master, Issuer},
    version::Version
};
use sui::test_scenario::{Self as ts, Scenario};

const ADMIN: address = @0x001;

// Custom ability witness for testing
public struct CustomAbility has drop {}

// Helper function to assign NewRole for testing
fun set_new_role_for_testing(
    auth: &mut Auth<TEST_VOLORO>,
    owner: address,
    _version: &Version,
    ctx: &TxContext,
) {
    trust_service::internal_assign_role<TEST_VOLORO, NewRole>(auth, owner, ctx);
}

fun setup_for_testing(ts: &mut Scenario) {
    ts.next_tx(ADMIN);
    setup_with_treasury(ts);
}

#[test]
fun test_auth_initialization_and_master_role() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    // Verify sender has Master role
    let role = trust_service::get_role(&auth, ADMIN);
    assert!(role == std::type_name::with_defining_ids<Master>(), 0);

    // Verify Master has all required abilities
    assert!(trust_service::role_has_ability<TEST_VOLORO, Master, SetAbilities>(&auth), 1);
    assert!(trust_service::role_has_ability<TEST_VOLORO, Master, SetServiceOwner>(&auth), 2);
    assert!(trust_service::role_has_ability<TEST_VOLORO, Master, SetIssuer>(&auth), 3);
    assert!(trust_service::role_has_ability<TEST_VOLORO, Master, SetTransferAgent>(&auth), 4);

    // Verify sender (Master) has all abilities
    assert!(trust_service::owner_has_ability<TEST_VOLORO, SetAbilities>(&auth, ADMIN), 5);
    assert!(trust_service::owner_has_ability<TEST_VOLORO, SetServiceOwner>(&auth, ADMIN), 6);
    assert!(trust_service::owner_has_ability<TEST_VOLORO, SetIssuer>(&auth, ADMIN), 7);
    assert!(trust_service::owner_has_ability<TEST_VOLORO, SetTransferAgent>(&auth, ADMIN), 8);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_auth_initialization_non_master_has_no_role() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    let non_master = @0xB;
    ts.next_tx(non_master);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    // get_role returns None type for addresses without a role
    let role = trust_service::get_role(&auth, non_master);
    assert!(role == std::type_name::with_defining_ids<trust_service::None>(), 0);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_set_role_master_can_assign_issuer() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    let new_issuer = @0xB;

    // Master assigns Issuer role to new_issuer
    ts.next_tx(ADMIN);
    let mut auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    trust_service::set_issuer<TEST_VOLORO>(&mut auth, new_issuer, &version, ts.ctx());
    ts::return_shared(auth);
    ts::return_shared(version);

    // Verify new_issuer has Issuer role
    ts.next_tx(new_issuer);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let role = trust_service::get_role(&auth, new_issuer);
    assert!(role == std::type_name::with_defining_ids<Issuer>(), 0);

    // Verify Issuer has SetIssuer ability (can set other Issuers)
    assert!(trust_service::owner_has_ability<TEST_VOLORO, SetIssuer>(&auth, new_issuer), 1);

    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_set_role_issuer_can_assign_another_issuer() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    let issuer1 = @0xB;
    let issuer2 = @0xC;

    // Master assigns Issuer role to issuer1
    ts.next_tx(ADMIN);
    let mut auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    trust_service::set_issuer<TEST_VOLORO>(&mut auth, issuer1, &version, ts.ctx());
    ts::return_shared(auth);
    ts::return_shared(version);

    // issuer1 assigns Issuer role to issuer2
    ts.next_tx(issuer1);
    let mut auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    trust_service::set_issuer<TEST_VOLORO>(&mut auth, issuer2, &version, ts.ctx());
    ts::return_shared(auth);
    ts::return_shared(version);

    // Verify issuer2 has Issuer role
    ts.next_tx(issuer2);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let role = trust_service::get_role(&auth, issuer2);
    assert!(role == std::type_name::with_defining_ids<Issuer>(), 0);
    ts::return_shared(auth);
    ts::return_shared(version);

    ts.end();
}

#[test]
#[expected_failure(abort_code = trust_service::EDirectRoleToRoleChange)]
fun test_set_role_cannot_assign_to_existing_role_holder() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    let issuer = @0xB;

    // Master assigns Issuer role
    ts.next_tx(ADMIN);
    let mut auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    trust_service::set_issuer<TEST_VOLORO>(&mut auth, issuer, &version, ts.ctx());
    ts::return_shared(auth);
    ts::return_shared(version);

    // Try to assign TransferAgent to same address - should fail
    ts.next_tx(ADMIN);
    let mut auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    trust_service::set_transfer_agent<TEST_VOLORO>(&mut auth, issuer, &version, ts.ctx());
    ts::return_shared(auth);
    ts::return_shared(version);

    ts.end();
}

#[test]
fun test_add_and_remove_abilities() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    // Master adds CustomAbility to Issuer role
    ts.next_tx(ADMIN);
    let mut auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    trust_service::add_role_ability<TEST_VOLORO, Issuer, CustomAbility>(
        &mut auth,
        &version,
        ts.ctx(),
    );
    ts::return_shared(auth);
    ts::return_shared(version);

    // Verify Issuer role has CustomAbility
    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    assert!(trust_service::role_has_ability<TEST_VOLORO, Issuer, CustomAbility>(&auth), 0);
    ts::return_shared(auth);

    // Master removes CustomAbility from Issuer role
    ts.next_tx(ADMIN);
    let mut auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    trust_service::remove_role_ability<TEST_VOLORO, Issuer, CustomAbility>(
        &mut auth,
        &version,
        ts.ctx(),
    );
    ts::return_shared(auth);
    ts::return_shared(version);

    // Verify Issuer role no longer has CustomAbility
    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    assert!(!trust_service::role_has_ability<TEST_VOLORO, Issuer, CustomAbility>(&auth), 1);
    ts::return_shared(auth);

    ts.end();
}

#[test]
fun test_set_service_owner_transfers_master_role() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    let new_master = @0xB;

    // Old master transfers ownership to new master
    ts.next_tx(ADMIN);
    let mut auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    trust_service::set_service_owner<TEST_VOLORO>(&mut auth, new_master, &version, ts.ctx());
    ts::return_shared(auth);
    ts::return_shared(version);

    // Verify new_master has Master role
    ts.next_tx(new_master);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let role = trust_service::get_role(&auth, new_master);
    assert!(role == std::type_name::with_defining_ids<Master>(), 0);
    ts::return_shared(auth);
    ts::return_shared(version);

    ts.end();
}

// ==================== Exchange Role Tests ====================

#[test]
fun test_set_exchange_by_master() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    let exchange_addr = @0xB;

    // Master assigns Exchange role
    ts.next_tx(ADMIN);
    let mut auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    trust_service::set_exchange<TEST_VOLORO>(&mut auth, exchange_addr, &version, ts.ctx());
    ts::return_shared(auth);
    ts::return_shared(version);

    // Verify exchange_addr has Exchange role
    ts.next_tx(exchange_addr);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let role = trust_service::get_role(&auth, exchange_addr);
    assert!(role == std::type_name::with_defining_ids<trust_service::Exchange>(), 0);
    ts::return_shared(auth);

    ts.end();
}

#[test]
fun test_set_exchange_by_issuer() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    let issuer_addr = @0xB;
    let exchange_addr = @0xC;

    // Master assigns Issuer role
    ts.next_tx(ADMIN);
    let mut auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    trust_service::set_issuer<TEST_VOLORO>(&mut auth, issuer_addr, &version, ts.ctx());
    ts::return_shared(auth);
    ts::return_shared(version);

    // Issuer assigns Exchange role (Issuer has SetExchange ability)
    ts.next_tx(issuer_addr);
    let mut auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    trust_service::set_exchange<TEST_VOLORO>(&mut auth, exchange_addr, &version, ts.ctx());
    ts::return_shared(auth);
    ts::return_shared(version);

    // Verify exchange_addr has Exchange role
    ts.next_tx(exchange_addr);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let role = trust_service::get_role(&auth, exchange_addr);
    assert!(role == std::type_name::with_defining_ids<trust_service::Exchange>(), 0);
    ts::return_shared(auth);

    ts.end();
}

#[test]
fun test_remove_exchange() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    let exchange_addr = @0xB;

    // Master assigns Exchange role
    ts.next_tx(ADMIN);
    let mut auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    trust_service::set_exchange<TEST_VOLORO>(&mut auth, exchange_addr, &version, ts.ctx());
    ts::return_shared(auth);
    ts::return_shared(version);

    // Verify exchange_addr has Exchange role
    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let role = trust_service::get_role(&auth, exchange_addr);
    assert!(role == std::type_name::with_defining_ids<trust_service::Exchange>(), 0);
    ts::return_shared(auth);

    // Master removes Exchange role
    ts.next_tx(ADMIN);
    let mut auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    trust_service::remove_exchange<TEST_VOLORO>(&mut auth, exchange_addr, &version, ts.ctx());
    ts::return_shared(auth);
    ts::return_shared(version);

    // Verify exchange_addr no longer has Exchange role
    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let role = trust_service::get_role(&auth, exchange_addr);
    assert!(role == std::type_name::with_defining_ids<trust_service::None>(), 1);
    ts::return_shared(auth);

    ts.end();
}

#[test]
#[expected_failure(abort_code = trust_service::ENotEnoughPermissions)]
fun test_set_exchange_unauthorized() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    let unauthorized = @0x002;
    let exchange_addr = @0xC;

    // Unauthorized user tries to set Exchange role - should fail
    ts.next_tx(unauthorized);
    let mut auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    trust_service::set_exchange<TEST_VOLORO>(&mut auth, exchange_addr, &version, ts.ctx());
    ts::return_shared(auth);
    ts::return_shared(version);

    ts.end();
}

// ==================== Transfer Agent Role Tests ====================

#[test]
fun test_remove_transfer_agent() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    let ta_addr = @0xB;

    // Master assigns TransferAgent role
    ts.next_tx(ADMIN);
    let mut auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    trust_service::set_transfer_agent<TEST_VOLORO>(&mut auth, ta_addr, &version, ts.ctx());
    ts::return_shared(auth);
    ts::return_shared(version);

    // Verify ta_addr has TransferAgent role
    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let role = trust_service::get_role(&auth, ta_addr);
    assert!(role == std::type_name::with_defining_ids<trust_service::TransferAgent>(), 0);
    ts::return_shared(auth);

    // Master removes TransferAgent role
    ts.next_tx(ADMIN);
    let mut auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    trust_service::remove_transfer_agent<TEST_VOLORO>(&mut auth, ta_addr, &version, ts.ctx());
    ts::return_shared(auth);
    ts::return_shared(version);

    // Verify ta_addr no longer has TransferAgent role
    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let role = trust_service::get_role(&auth, ta_addr);
    assert!(role == std::type_name::with_defining_ids<trust_service::None>(), 1);
    ts::return_shared(auth);

    ts.end();
}

#[test]
fun test_transfer_agent_can_set_another_transfer_agent() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    let ta1 = @0xB;
    let ta2 = @0xC;

    // Master assigns TransferAgent role to ta1
    ts.next_tx(ADMIN);
    let mut auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    trust_service::set_transfer_agent<TEST_VOLORO>(&mut auth, ta1, &version, ts.ctx());
    ts::return_shared(auth);
    ts::return_shared(version);

    // ta1 assigns TransferAgent role to ta2
    ts.next_tx(ta1);
    let mut auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    trust_service::set_transfer_agent<TEST_VOLORO>(&mut auth, ta2, &version, ts.ctx());
    ts::return_shared(auth);
    ts::return_shared(version);

    // Verify ta2 has TransferAgent role
    ts.next_tx(ta2);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let role = trust_service::get_role(&auth, ta2);
    assert!(role == std::type_name::with_defining_ids<trust_service::TransferAgent>(), 0);
    ts::return_shared(auth);

    ts.end();
}

#[test]
#[expected_failure(abort_code = trust_service::ENotEnoughPermissions)]
fun test_transfer_agent_cannot_set_exchange() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    let ta = @0xB;
    let exchange_addr = @0xC;

    // Master assigns TransferAgent role to ta
    ts.next_tx(ADMIN);
    let mut auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    trust_service::set_transfer_agent<TEST_VOLORO>(&mut auth, ta, &version, ts.ctx());
    ts::return_shared(auth);
    ts::return_shared(version);

    // TransferAgent tries to set Exchange role - should fail (TransferAgent doesn't have SetExchange ability)
    ts.next_tx(ta);
    let mut auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    trust_service::set_exchange<TEST_VOLORO>(&mut auth, exchange_addr, &version, ts.ctx());
    ts::return_shared(auth);
    ts::return_shared(version);

    ts.end();
}

// ==================== Issuer Role Tests ====================

#[test]
fun test_remove_issuer() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    let issuer_addr = @0xB;

    // Master assigns Issuer role
    ts.next_tx(ADMIN);
    let mut auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    trust_service::set_issuer<TEST_VOLORO>(&mut auth, issuer_addr, &version, ts.ctx());
    ts::return_shared(auth);
    ts::return_shared(version);

    // Verify issuer_addr has Issuer role
    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let role = trust_service::get_role(&auth, issuer_addr);
    assert!(role == std::type_name::with_defining_ids<Issuer>(), 0);
    ts::return_shared(auth);

    // Master removes Issuer role
    ts.next_tx(ADMIN);
    let mut auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    trust_service::remove_issuer<TEST_VOLORO>(&mut auth, issuer_addr, &version, ts.ctx());
    ts::return_shared(auth);
    ts::return_shared(version);

    // Verify issuer_addr no longer has Issuer role
    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let role = trust_service::get_role(&auth, issuer_addr);
    assert!(role == std::type_name::with_defining_ids<trust_service::None>(), 1);
    ts::return_shared(auth);

    ts.end();
}

// ==================== Error Case Tests ====================

#[test]
#[expected_failure(abort_code = trust_service::ESelfTransferNotAllowed)]
fun test_set_service_owner_to_self_fails() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    // Master tries to transfer ownership to self - should fail
    ts.next_tx(ADMIN);
    let mut auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    trust_service::set_service_owner<TEST_VOLORO>(&mut auth, ADMIN, &version, ts.ctx());
    ts::return_shared(auth);
    ts::return_shared(version);

    ts.end();
}

#[test]
#[expected_failure(abort_code = trust_service::ENotEnoughPermissions)]
fun test_set_transfer_agent_unauthorized() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    let unauthorized = @0x002;
    let ta_addr = @0xC;

    // Unauthorized user tries to set TransferAgent role - should fail
    ts.next_tx(unauthorized);
    let mut auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    trust_service::set_transfer_agent<TEST_VOLORO>(&mut auth, ta_addr, &version, ts.ctx());
    ts::return_shared(auth);
    ts::return_shared(version);

    ts.end();
}

#[test]
#[expected_failure(abort_code = trust_service::ENotEnoughPermissions)]
fun test_set_issuer_unauthorized() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    let unauthorized = @0x002;
    let issuer_addr = @0xC;

    // Unauthorized user tries to set Issuer role - should fail
    ts.next_tx(unauthorized);
    let mut auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    trust_service::set_issuer<TEST_VOLORO>(&mut auth, issuer_addr, &version, ts.ctx());
    ts::return_shared(auth);
    ts::return_shared(version);

    ts.end();
}

#[test]
#[expected_failure(abort_code = trust_service::ENotEnoughPermissions)]
fun test_set_service_owner_unauthorized() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    let issuer_addr = @0xB;
    let new_owner = @0xC;

    // Master assigns Issuer role
    ts.next_tx(ADMIN);
    let mut auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    trust_service::set_issuer<TEST_VOLORO>(&mut auth, issuer_addr, &version, ts.ctx());
    ts::return_shared(auth);
    ts::return_shared(version);

    // Issuer tries to set service owner - should fail (Issuer doesn't have SetServiceOwner ability)
    ts.next_tx(issuer_addr);
    let mut auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    trust_service::set_service_owner<TEST_VOLORO>(&mut auth, new_owner, &version, ts.ctx());
    ts::return_shared(auth);
    ts::return_shared(version);

    ts.end();
}

#[test]
#[expected_failure(abort_code = trust_service::ENotEnoughPermissions)]
fun test_remove_exchange_unauthorized() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    let exchange_addr = @0xB;
    let unauthorized = @0x002;

    // Master assigns Exchange role
    ts.next_tx(ADMIN);
    let mut auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    trust_service::set_exchange<TEST_VOLORO>(&mut auth, exchange_addr, &version, ts.ctx());
    ts::return_shared(auth);
    ts::return_shared(version);

    // Unauthorized user tries to remove Exchange role - should fail
    ts.next_tx(unauthorized);
    let mut auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    trust_service::remove_exchange<TEST_VOLORO>(&mut auth, exchange_addr, &version, ts.ctx());
    ts::return_shared(auth);
    ts::return_shared(version);

    ts.end();
}

#[test]
#[expected_failure(abort_code = trust_service::ENotEnoughPermissions)]
fun test_remove_transfer_agent_unauthorized() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    let ta_addr = @0xB;
    let unauthorized = @0x002;

    // Master assigns TransferAgent role
    ts.next_tx(ADMIN);
    let mut auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    trust_service::set_transfer_agent<TEST_VOLORO>(&mut auth, ta_addr, &version, ts.ctx());
    ts::return_shared(auth);
    ts::return_shared(version);

    // Unauthorized user tries to remove TransferAgent role - should fail
    ts.next_tx(unauthorized);
    let mut auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    trust_service::remove_transfer_agent<TEST_VOLORO>(&mut auth, ta_addr, &version, ts.ctx());
    ts::return_shared(auth);
    ts::return_shared(version);

    ts.end();
}

#[test]
#[expected_failure(abort_code = trust_service::ENotEnoughPermissions)]
fun test_remove_issuer_unauthorized() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    let issuer_addr = @0xB;
    let unauthorized = @0x002;

    // Master assigns Issuer role
    ts.next_tx(ADMIN);
    let mut auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    trust_service::set_issuer<TEST_VOLORO>(&mut auth, issuer_addr, &version, ts.ctx());
    ts::return_shared(auth);
    ts::return_shared(version);

    // Unauthorized user tries to remove Issuer role - should fail
    ts.next_tx(unauthorized);
    let mut auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    trust_service::remove_issuer<TEST_VOLORO>(&mut auth, issuer_addr, &version, ts.ctx());
    ts::return_shared(auth);
    ts::return_shared(version);

    ts.end();
}

// ==================== Ability Management Error Tests ====================

#[test]
#[expected_failure(abort_code = trust_service::EAbilityAlreadyExists)]
fun test_add_role_ability_already_exists() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    // Master adds CustomAbility to Issuer role
    ts.next_tx(ADMIN);
    let mut auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    trust_service::add_role_ability<TEST_VOLORO, Issuer, CustomAbility>(
        &mut auth,
        &version,
        ts.ctx(),
    );
    ts::return_shared(auth);
    ts::return_shared(version);

    // Try to add CustomAbility again - should fail
    ts.next_tx(ADMIN);
    let mut auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    trust_service::add_role_ability<TEST_VOLORO, Issuer, CustomAbility>(
        &mut auth,
        &version,
        ts.ctx(),
    );
    ts::return_shared(auth);
    ts::return_shared(version);

    ts.end();
}

#[test]
#[expected_failure(abort_code = trust_service::EAbilityNotFound)]
fun test_remove_role_ability_not_found() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    // Try to remove CustomAbility from Issuer role (never added) - should fail
    ts.next_tx(ADMIN);
    let mut auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    trust_service::remove_role_ability<TEST_VOLORO, Issuer, CustomAbility>(
        &mut auth,
        &version,
        ts.ctx(),
    );
    ts::return_shared(auth);
    ts::return_shared(version);

    ts.end();
}

#[test]
#[expected_failure(abort_code = trust_service::ECannotRemoveMaster)]
fun test_cannot_remove_set_abilities_from_master() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    // Try to remove SetAbilities from Master role - should fail
    ts.next_tx(ADMIN);
    let mut auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    trust_service::remove_role_ability<TEST_VOLORO, Master, SetAbilities>(
        &mut auth,
        &version,
        ts.ctx(),
    );
    ts::return_shared(auth);
    ts::return_shared(version);

    ts.end();
}

#[test]
#[expected_failure(abort_code = trust_service::ENotEnoughPermissions)]
fun test_add_role_ability_unauthorized() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    let issuer_addr = @0xB;

    // Master assigns Issuer role
    ts.next_tx(ADMIN);
    let mut auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    trust_service::set_issuer<TEST_VOLORO>(&mut auth, issuer_addr, &version, ts.ctx());
    ts::return_shared(auth);
    ts::return_shared(version);

    // Issuer tries to add ability - should fail (Issuer doesn't have SetAbilities)
    ts.next_tx(issuer_addr);
    let mut auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    trust_service::add_role_ability<TEST_VOLORO, Issuer, CustomAbility>(
        &mut auth,
        &version,
        ts.ctx(),
    );
    ts::return_shared(auth);
    ts::return_shared(version);

    ts.end();
}

#[test]
#[expected_failure(abort_code = trust_service::ENotEnoughPermissions)]
fun test_remove_role_ability_unauthorized() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    let issuer_addr = @0xB;

    // Master assigns Issuer role
    ts.next_tx(ADMIN);
    let mut auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    trust_service::set_issuer<TEST_VOLORO>(&mut auth, issuer_addr, &version, ts.ctx());
    ts::return_shared(auth);
    ts::return_shared(version);

    // Master adds CustomAbility to Issuer role
    ts.next_tx(ADMIN);
    let mut auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    trust_service::add_role_ability<TEST_VOLORO, Issuer, CustomAbility>(
        &mut auth,
        &version,
        ts.ctx(),
    );
    ts::return_shared(auth);
    ts::return_shared(version);

    // Issuer tries to remove ability - should fail
    ts.next_tx(issuer_addr);
    let mut auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    trust_service::remove_role_ability<TEST_VOLORO, Issuer, CustomAbility>(
        &mut auth,
        &version,
        ts.ctx(),
    );
    ts::return_shared(auth);
    ts::return_shared(version);

    ts.end();
}

// ==================== Role Type Management Tests ====================

public struct NewRole has drop {}
public struct SetNewRole has drop {}

#[test]
fun test_add_role_type() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    // Master adds new role type
    ts.next_tx(ADMIN);
    let mut auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    trust_service::add_role_type<TEST_VOLORO, NewRole, SetNewRole>(&mut auth, &version, ts.ctx());
    ts::return_shared(auth);
    ts::return_shared(version);

    // Verify Master has the SetNewRole ability now
    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    assert!(trust_service::owner_has_ability<TEST_VOLORO, SetNewRole>(&auth, ADMIN), 0);
    ts::return_shared(auth);

    ts.end();
}

#[test]
fun test_remove_role_type() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    // Master adds new role type
    ts.next_tx(ADMIN);
    let mut auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    trust_service::add_role_type<TEST_VOLORO, NewRole, SetNewRole>(&mut auth, &version, ts.ctx());
    ts::return_shared(auth);
    ts::return_shared(version);

    // Master removes the role type (no active members)
    ts.next_tx(ADMIN);
    let mut auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    trust_service::remove_role_type<TEST_VOLORO, NewRole, SetNewRole>(
        &mut auth,
        &version,
        ts.ctx(),
    );
    ts::return_shared(auth);
    ts::return_shared(version);

    // Verify Master no longer has SetNewRole ability
    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    assert!(!trust_service::owner_has_ability<TEST_VOLORO, SetNewRole>(&auth, ADMIN), 0);
    ts::return_shared(auth);

    ts.end();
}

#[test]
#[expected_failure(abort_code = trust_service::ERoleAlreadyExists)]
fun test_add_role_type_already_exists() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    // Master adds new role type
    ts.next_tx(ADMIN);
    let mut auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    trust_service::add_role_type<TEST_VOLORO, NewRole, SetNewRole>(&mut auth, &version, ts.ctx());
    ts::return_shared(auth);
    ts::return_shared(version);

    // Try to add same role type again - should fail
    ts.next_tx(ADMIN);
    let mut auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    trust_service::add_role_type<TEST_VOLORO, NewRole, SetNewRole>(&mut auth, &version, ts.ctx());
    ts::return_shared(auth);
    ts::return_shared(version);

    ts.end();
}

#[test]
#[expected_failure(abort_code = trust_service::ECannotRemoveMaster)]
fun test_cannot_remove_master_role_type() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    // Try to remove Master role type - should fail
    ts.next_tx(ADMIN);
    let mut auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    trust_service::remove_role_type<TEST_VOLORO, Master, SetServiceOwner>(
        &mut auth,
        &version,
        ts.ctx(),
    );
    ts::return_shared(auth);
    ts::return_shared(version);

    ts.end();
}

#[test]
#[expected_failure(abort_code = trust_service::ERoleHasActiveMembers)]
fun test_remove_role_type_with_active_members_fails() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    let member = @0xB;

    // Master adds new role type (this also grants SetNewRole ability to Master)
    ts.next_tx(ADMIN);
    let mut auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    trust_service::add_role_type<TEST_VOLORO, NewRole, SetNewRole>(&mut auth, &version, ts.ctx());
    ts::return_shared(auth);
    ts::return_shared(version);

    // Master assigns NewRole to member
    ts.next_tx(ADMIN);
    let mut auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    set_new_role_for_testing(&mut auth, member, &version, ts.ctx());
    ts::return_shared(auth);
    ts::return_shared(version);

    // Try to remove role type while member still has it - should fail
    ts.next_tx(ADMIN);
    let mut auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    trust_service::remove_role_type<TEST_VOLORO, NewRole, SetNewRole>(
        &mut auth,
        &version,
        ts.ctx(),
    );
    ts::return_shared(auth);
    ts::return_shared(version);

    ts.end();
}

#[test]
#[expected_failure(abort_code = trust_service::ENotEnoughPermissions)]
fun test_add_role_type_unauthorized() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    let issuer_addr = @0xB;

    // Master assigns Issuer role
    ts.next_tx(ADMIN);
    let mut auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    trust_service::set_issuer<TEST_VOLORO>(&mut auth, issuer_addr, &version, ts.ctx());
    ts::return_shared(auth);
    ts::return_shared(version);

    // Issuer tries to add role type - should fail (Issuer doesn't have SetRoleTypes)
    ts.next_tx(issuer_addr);
    let mut auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    trust_service::add_role_type<TEST_VOLORO, NewRole, SetNewRole>(&mut auth, &version, ts.ctx());
    ts::return_shared(auth);
    ts::return_shared(version);

    ts.end();
}

#[test]
#[expected_failure(abort_code = trust_service::ENotEnoughPermissions)]
fun test_remove_role_type_unauthorized() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    let issuer_addr = @0xB;

    // Master adds new role type
    ts.next_tx(ADMIN);
    let mut auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    trust_service::add_role_type<TEST_VOLORO, NewRole, SetNewRole>(&mut auth, &version, ts.ctx());
    ts::return_shared(auth);
    ts::return_shared(version);

    // Master assigns Issuer role
    ts.next_tx(ADMIN);
    let mut auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    trust_service::set_issuer<TEST_VOLORO>(&mut auth, issuer_addr, &version, ts.ctx());
    ts::return_shared(auth);
    ts::return_shared(version);

    // Issuer tries to remove role type - should fail
    ts.next_tx(issuer_addr);
    let mut auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    trust_service::remove_role_type<TEST_VOLORO, NewRole, SetNewRole>(
        &mut auth,
        &version,
        ts.ctx(),
    );
    ts::return_shared(auth);
    ts::return_shared(version);

    ts.end();
}

// ==================== Additional Coverage Tests ====================

#[test]
fun test_role_has_ability_for_non_existent_role() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    // Check ability on None role (which has no abilities mapping)
    assert!(
        !trust_service::role_has_ability<TEST_VOLORO, trust_service::None, SetAbilities>(&auth),
        0,
    );
    ts::return_shared(auth);

    ts.end();
}

#[test]
fun test_owner_has_ability_for_owner_without_role() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    let no_role_addr = @0x002;

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    // Check ability for address without any role
    assert!(!trust_service::owner_has_ability<TEST_VOLORO, SetAbilities>(&auth, no_role_addr), 0);
    ts::return_shared(auth);

    ts.end();
}

#[test]
fun test_service_owner_transfer_removes_old_master_role() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    let new_master = @0xB;

    // Old master transfers ownership to new master
    ts.next_tx(ADMIN);
    let mut auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    trust_service::set_service_owner<TEST_VOLORO>(&mut auth, new_master, &version, ts.ctx());
    ts::return_shared(auth);
    ts::return_shared(version);

    // Verify old master (ADMIN) no longer has Master role
    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let role = trust_service::get_role(&auth, ADMIN);
    assert!(role == std::type_name::with_defining_ids<trust_service::None>(), 0);
    ts::return_shared(auth);

    ts.end();
}
