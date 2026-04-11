#[test_only]
module securitize::version_tests;

use securitize::setup::{Self, SetupRegistry};
use securitize::version::{Self, Version};
use sui::test_scenario as ts;

const ADMIN: address = @0x001;

#[test]
fun test_version_initialization() {
    let mut ts = ts::begin(ADMIN);

    ts.next_tx(ADMIN);
    version::init_for_testing(ts.ctx());
    ts.next_tx(ADMIN);
    let version = ts.take_shared<Version>();
    // Version should be valid after initialization
    version.check_is_valid();

    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = version::EInvalidPackageVersion)]
fun test_check_is_valid_invalid_version() {
    let mut ts = ts::begin(ADMIN);

    ts.next_tx(ADMIN);
    version::init_for_testing(ts.ctx());

    ts.next_tx(ADMIN);
    let mut version = ts.take_shared<Version>();

    // Set version to invalid value
    version.set_version_for_testing(999);

    // Should fail - version doesn't match VERSION constant
    version.check_is_valid();

    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = setup::ENotAdmin)]
fun test_migrate_not_admin() {
    let mut ts = ts::begin(ADMIN);

    ts.next_tx(ADMIN);
    setup::init_for_testing(ts.ctx());
    version::init_for_testing(ts.ctx());

    // Call migrate from a non-admin address
    let non_admin: address = @0x999;
    ts.next_tx(non_admin);
    let registry = ts.take_shared<SetupRegistry>();
    let mut version = ts.take_shared<Version>();

    // Should fail - caller is not admin
    setup::migrate_version(&registry, &mut version, ts.ctx());

    ts::return_shared(registry);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_migrate_success() {
    let mut ts = ts::begin(ADMIN);

    ts.next_tx(ADMIN);
    setup::init_for_testing(ts.ctx());
    version::init_for_testing(ts.ctx());

    ts.next_tx(ADMIN);
    let registry = ts.take_shared<SetupRegistry>();
    let mut version = ts.take_shared<Version>();

    // Set version to a different value to verify migrate resets it
    version.set_version_for_testing(0);

    // Migrate should succeed - ADMIN is the registry admin
    setup::migrate_version(&registry, &mut version, ts.ctx());

    // Version should now be valid
    version.check_is_valid();

    ts::return_shared(registry);
    ts::return_shared(version);
    ts.end();
}
