#[test_only]
module securitize::trust_service_tests;

use securitize::trust_service::{
    Self,
    Auth,
    Master,
    Issuer,
    SetAbilities,
    SetIssuer,
    SetTransferAgent,
    SetServiceOwner
};
use sui::test_scenario::{Self as ts, Scenario};

const ADMIN: address = @0xCAFE;

// Test witness type for Auth<TestWitness>
public struct TestWitness has drop {}

// Custom ability witness for testing
public struct CustomAbility has drop {}

fun setup_for_testing(ts: &mut Scenario) {
    ts.next_tx(ADMIN);
    let auth = trust_service::new<TestWitness>(ts.ctx());
    trust_service::share(auth);
}

#[test]
fun test_auth_initialization_and_master_role() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TestWitness>>();

    // Verify sender has Master role
    let role = trust_service::get_role(&auth, ADMIN);
    assert!(role == std::type_name::with_defining_ids<Master>(), 0);

    // Verify Master has all required abilities
    assert!(trust_service::role_has_ability<TestWitness, Master, SetAbilities>(&auth), 1);
    assert!(trust_service::role_has_ability<TestWitness, Master, SetServiceOwner>(&auth), 2);
    assert!(trust_service::role_has_ability<TestWitness, Master, SetIssuer>(&auth), 3);
    assert!(trust_service::role_has_ability<TestWitness, Master, SetTransferAgent>(&auth), 4);

    // Verify sender (Master) has all abilities
    assert!(trust_service::owner_has_ability<TestWitness, SetAbilities>(&auth, ADMIN), 5);
    assert!(trust_service::owner_has_ability<TestWitness, SetServiceOwner>(&auth, ADMIN), 6);
    assert!(trust_service::owner_has_ability<TestWitness, SetIssuer>(&auth, ADMIN), 7);
    assert!(trust_service::owner_has_ability<TestWitness, SetTransferAgent>(&auth, ADMIN), 8);

    ts::return_shared(auth);
    ts.end();
}

#[test]
#[expected_failure(abort_code = trust_service::EOwnerHasNoRole)]
fun test_auth_initialization_non_master_has_no_role() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    let non_master = @0xB;
    ts.next_tx(non_master);
    let auth = ts.take_shared<Auth<TestWitness>>();

    // This should abort because non_master doesn't have a role
    let _role = trust_service::get_role(&auth, non_master);

    ts::return_shared(auth);
    ts.end();
}

#[test]
fun test_set_role_master_can_assign_issuer() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    let new_issuer = @0xB;

    // Master assigns Issuer role to new_issuer
    ts.next_tx(ADMIN);
    let mut auth = ts.take_shared<Auth<TestWitness>>();
    trust_service::set_issuer<TestWitness>(&mut auth, new_issuer, ts.ctx());
    ts::return_shared(auth);

    // Verify new_issuer has Issuer role
    ts.next_tx(new_issuer);
    let auth = ts.take_shared<Auth<TestWitness>>();

    let role = trust_service::get_role(&auth, new_issuer);
    assert!(role == std::type_name::with_defining_ids<Issuer>(), 0);

    // Verify Issuer has SetIssuer ability (can set other Issuers)
    assert!(trust_service::owner_has_ability<TestWitness, SetIssuer>(&auth, new_issuer), 1);

    ts::return_shared(auth);
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
    let mut auth = ts.take_shared<Auth<TestWitness>>();
    trust_service::set_issuer<TestWitness>(&mut auth, issuer1, ts.ctx());
    ts::return_shared(auth);

    // issuer1 assigns Issuer role to issuer2
    ts.next_tx(issuer1);
    let mut auth = ts.take_shared<Auth<TestWitness>>();
    trust_service::set_issuer<TestWitness>(&mut auth, issuer2, ts.ctx());
    ts::return_shared(auth);

    // Verify issuer2 has Issuer role
    ts.next_tx(issuer2);
    let auth = ts.take_shared<Auth<TestWitness>>();
    let role = trust_service::get_role(&auth, issuer2);
    assert!(role == std::type_name::with_defining_ids<Issuer>(), 0);
    ts::return_shared(auth);

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
    let mut auth = ts.take_shared<Auth<TestWitness>>();
    trust_service::set_issuer<TestWitness>(&mut auth, issuer, ts.ctx());
    ts::return_shared(auth);

    // Try to assign TransferAgent to same address - should fail
    ts.next_tx(ADMIN);
    let mut auth = ts.take_shared<Auth<TestWitness>>();
    trust_service::set_transfer_agent<TestWitness>(&mut auth, issuer, ts.ctx());
    ts::return_shared(auth);

    ts.end();
}

#[test]
fun test_add_and_remove_abilities() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    // Master adds CustomAbility to Issuer role
    ts.next_tx(ADMIN);
    let mut auth = ts.take_shared<Auth<TestWitness>>();
    trust_service::add_role_ability<TestWitness, Issuer, CustomAbility>(&mut auth, ts.ctx());
    ts::return_shared(auth);

    // Verify Issuer role has CustomAbility
    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TestWitness>>();
    assert!(trust_service::role_has_ability<TestWitness, Issuer, CustomAbility>(&auth), 0);
    ts::return_shared(auth);

    // Master removes CustomAbility from Issuer role
    ts.next_tx(ADMIN);
    let mut auth = ts.take_shared<Auth<TestWitness>>();
    trust_service::remove_role_ability<TestWitness, Issuer, CustomAbility>(&mut auth, ts.ctx());
    ts::return_shared(auth);

    // Verify Issuer role no longer has CustomAbility
    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TestWitness>>();
    assert!(!trust_service::role_has_ability<TestWitness, Issuer, CustomAbility>(&auth), 1);
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
    let mut auth = ts.take_shared<Auth<TestWitness>>();
    trust_service::set_service_owner<TestWitness>(&mut auth, new_master, ts.ctx());
    ts::return_shared(auth);

    // Verify new_master has Master role
    ts.next_tx(new_master);
    let auth = ts.take_shared<Auth<TestWitness>>();
    let role = trust_service::get_role(&auth, new_master);
    assert!(role == std::type_name::with_defining_ids<Master>(), 0);
    ts::return_shared(auth);

    ts.end();
}
