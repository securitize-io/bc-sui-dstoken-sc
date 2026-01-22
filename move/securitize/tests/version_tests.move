#[test_only]
module securitize::version_tests;

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