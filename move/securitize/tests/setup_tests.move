#[test_only]
module securitize::setup_tests;

use securitize::{setup::{Self, SetupRegistry}, version::{Self, Version}};
use sui::test_scenario as ts;

const ADMIN: address = @0x001;
const DEPLOYER1: address = @0x002;

#[test]
#[expected_failure(abort_code = setup::ENotAdmin)]
fun test_add_deployer_fails_if_not_admin() {
    let mut ts = ts::begin(ADMIN);
    setup::init_for_testing(ts.ctx());
    version::init_for_testing(ts.ctx());

    ts.next_tx(ADMIN);
    let mut setup_auth = ts.take_shared<SetupRegistry>();
    let version = ts.take_shared<Version>();

    // DEPLOYER1 is not admin, should fail
    ts.next_tx(DEPLOYER1);
    setup::add_deployer(&mut setup_auth, @0x999, &version, ts.ctx());

    ts::return_shared(setup_auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = setup::ENotAdmin)]
fun test_remove_deployer_fails_if_not_admin() {
    let mut ts = ts::begin(ADMIN);
    setup::init_for_testing(ts.ctx());
    version::init_for_testing(ts.ctx());

    ts.next_tx(ADMIN);
    let mut setup_auth = ts.take_shared<SetupRegistry>();
    let version = ts.take_shared<Version>();

    // First add DEPLOYER1 as deployer (by admin)
    setup::add_deployer(&mut setup_auth, DEPLOYER1, &version, ts.ctx());

    // DEPLOYER1 tries to remove themselves (not admin, should fail)
    ts.next_tx(DEPLOYER1);
    setup::remove_deployer(&mut setup_auth, DEPLOYER1, &version, ts.ctx());

    ts::return_shared(setup_auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = setup::ENotAdmin)]
fun test_switch_admin_fails_if_not_admin() {
    let mut ts = ts::begin(ADMIN);
    setup::init_for_testing(ts.ctx());
    version::init_for_testing(ts.ctx());

    ts.next_tx(ADMIN);
    let mut setup_auth = ts.take_shared<SetupRegistry>();
    let version = ts.take_shared<Version>();

    // DEPLOYER1 is not admin, should fail
    ts.next_tx(DEPLOYER1);
    setup::switch_admin(&mut setup_auth, DEPLOYER1, &version, ts.ctx());

    ts::return_shared(setup_auth);
    ts::return_shared(version);
    ts.end();
}

// ============ Success Tests ============

#[test]
fun test_add_deployer_succeeds() {
    let mut ts = ts::begin(ADMIN);
    setup::init_for_testing(ts.ctx());
    version::init_for_testing(ts.ctx());

    ts.next_tx(ADMIN);
    let mut setup_auth = ts.take_shared<SetupRegistry>();
    let version = ts.take_shared<Version>();

    // Admin adds DEPLOYER1
    setup::add_deployer(&mut setup_auth, DEPLOYER1, &version, ts.ctx());
    assert!(setup_auth.is_deployer(DEPLOYER1));

    ts::return_shared(setup_auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_remove_deployer_succeeds() {
    let mut ts = ts::begin(ADMIN);
    setup::init_for_testing(ts.ctx());
    version::init_for_testing(ts.ctx());

    ts.next_tx(ADMIN);
    let mut setup_auth = ts.take_shared<SetupRegistry>();
    let version = ts.take_shared<Version>();

    // Admin adds then removes DEPLOYER1
    setup::add_deployer(&mut setup_auth, DEPLOYER1, &version, ts.ctx());
    assert!(setup_auth.is_deployer(DEPLOYER1));

    ts.next_tx(ADMIN);
    setup::remove_deployer(&mut setup_auth, DEPLOYER1, &version, ts.ctx());
    assert!(!setup_auth.is_deployer(DEPLOYER1));

    ts::return_shared(setup_auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_switch_admin_succeeds() {
    let mut ts = ts::begin(ADMIN);
    setup::init_for_testing(ts.ctx());
    version::init_for_testing(ts.ctx());

    ts.next_tx(ADMIN);
    let mut setup_auth = ts.take_shared<SetupRegistry>();
    let version = ts.take_shared<Version>();

    // Verify initial admin
    assert!(setup_auth.admin() == ADMIN);

    // Admin switches to DEPLOYER1
    setup::switch_admin(&mut setup_auth, DEPLOYER1, &version, ts.ctx());
    assert!(setup_auth.admin() == DEPLOYER1);

    ts::return_shared(setup_auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_is_deployer() {
    let mut ts = ts::begin(ADMIN);
    setup::init_for_testing(ts.ctx());
    version::init_for_testing(ts.ctx());

    ts.next_tx(ADMIN);
    let setup_auth = ts.take_shared<SetupRegistry>();

    // ADMIN is deployer by default (from init)
    assert!(setup_auth.is_deployer(ADMIN));
    // DEPLOYER1 is not a deployer yet
    assert!(!setup_auth.is_deployer(DEPLOYER1));

    ts::return_shared(setup_auth);
    ts.end();
}