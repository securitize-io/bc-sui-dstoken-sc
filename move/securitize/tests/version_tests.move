#[test_only]
module securitize::version_tests;

use securitize::version::{Self, Version};
use sui::package;
use sui::test_scenario as ts;

const ADMIN: address = @0x001;

/// Test OTW for creating a valid Publisher (same package)
public struct VERSION_TESTS has drop {}

/// Different package OTW for invalid publisher test
/// Note: We use a test module from sui framework that provides a test publisher
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
#[expected_failure(abort_code = version::EInvalidPublisher)]
fun test_migrate_invalid_publisher() {
    let mut ts = ts::begin(ADMIN);

    ts.next_tx(ADMIN);
    version::init_for_testing(ts.ctx());

    ts.next_tx(ADMIN);
    let mut version = ts.take_shared<Version>();

    // Create Publisher from a different package (sui framework)
    // SUI type is from sui::sui module, so its Publisher won't match securitize package
    let sui_otw = sui::test_utils::create_one_time_witness<sui::sui::SUI>();
    let invalid_publisher = package::test_claim(sui_otw, ts.ctx());

    // Should fail - Publisher is from sui framework, not securitize package
    version::migrate(&invalid_publisher, &mut version);

    package::burn_publisher(invalid_publisher);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_migrate_success() {
    let mut ts = ts::begin(ADMIN);

    ts.next_tx(ADMIN);
    version::init_for_testing(ts.ctx());

    ts.next_tx(ADMIN);
    let mut version = ts.take_shared<Version>();

    // Set version to a different value to verify migrate resets it
    version.set_version_for_testing(0);

    // Create valid Publisher from the same package (securitize)
    // VERSION_TESTS is in the same package as Version, so from_package<Version>() returns true
    let otw = sui::test_utils::create_one_time_witness<VERSION_TESTS>();
    let publisher = package::test_claim(otw, ts.ctx());

    // Migrate should succeed and reset version
    version::migrate(&publisher, &mut version);

    // Version should now be valid
    version.check_is_valid();

    package::burn_publisher(publisher);
    ts::return_shared(version);
    ts.end();
}