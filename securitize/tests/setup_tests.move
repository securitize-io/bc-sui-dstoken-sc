#[test_only]
module securitize::setup_tests;

use sui::test_scenario as ts;
use sui::test_utils;
use securitize::setup::{Self, SetupAuth};

const ADMIN: address = @0xCAFE;
const DEPLOYER1: address = @0xBEEF;

#[test]
fun test_setup_auth() {
    let mut ts = ts::begin(ADMIN);
    setup::init_for_testing(ts.ctx());

    ts.next_tx(ADMIN);
    let mut setup_auth = ts.take_shared<SetupAuth>();
    setup::add_deployer(&mut setup_auth, DEPLOYER1, ts.ctx());
    assert!(setup_auth.is_deployer(DEPLOYER1));

    ts.next_tx(ADMIN);
    setup::remove_deployer(&mut setup_auth, DEPLOYER1, ts.ctx());
    assert!(!setup_auth.is_deployer(DEPLOYER1));

    ts.next_tx(ADMIN);
    let new_admin: address = @0xDEAD;
    setup::switch_admin(&mut setup_auth, new_admin, ts.ctx());

    test_utils::destroy(setup_auth);
    ts.end();
}

