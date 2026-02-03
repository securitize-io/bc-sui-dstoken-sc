#[test_only]
module securitize::registry_service_tests;

use pas::namespace::{Namespace, init_for_testing};
use securitize::{
    registry_service::{Self, InvestorInfo},
    test_helpers::{TEST_VOLORO, setup_with_treasury},
    trust_service::Auth,
    version::Version
};
use sui::test_scenario::{Self as ts, Scenario};

const ADMIN: address = @0x001;
const UNAUTHORIZED: address = @0x002;

fun setup_for_testing(ts: &mut Scenario) {
    ts.next_tx(ADMIN);
    setup_with_treasury(ts);
}

#[test]
fun test_register_investor() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    // Initially no investor
    assert!(!registry_service::is_investor(&registry, b"INV001".to_string()), 0);

    // Register an investor
    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    // Investor should now exist
    assert!(registry_service::is_investor(&registry, b"INV001".to_string()), 1);

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = registry_service::ENotAuthorized)]
fun test_register_investor_unauthorized() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(UNAUTHORIZED);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    // Should fail - UNAUTHORIZED has no RegisterInvestor ability
    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = registry_service::EInvestorExists)]
fun test_register_investor_already_exists() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    // Register an investor
    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    // Try to register again - should fail
    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = registry_service::EEmptyId)]
fun test_register_investor_empty_id() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    // Try to register with empty ID - should fail
    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"".to_string(),
        &version,
        ts.ctx(),
    );

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_register_investor_if_not_exists() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);

    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    registry_service::register_investor_if_not_exists<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    assert!(registry_service::is_investor(&registry, b"INV001".to_string()), 1);

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_register_investor_if_not_exists_when_exists() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);

    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    // Register an investor
    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    // Try to register again using register_investor_if_not_exists
    registry_service::register_investor_if_not_exists<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    assert!(registry_service::is_investor(&registry, b"INV001".to_string()), 1);

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = registry_service::ENotAuthorized)]
fun test_register_investor_if_not_exists_unauthorized() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(UNAUTHORIZED);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    // Should fail - UNAUTHORIZED has no RegisterInvestor ability
    registry_service::register_investor_if_not_exists<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_remove_investor() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    // Register an investor
    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    assert!(registry_service::is_investor(&registry, b"INV001".to_string()), 0);

    // Remove the investor
    registry_service::remove_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    assert!(!registry_service::is_investor(&registry, b"INV001".to_string()), 1);

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = registry_service::ENotAuthorized)]
fun test_remove_investor_unauthorized() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    // Register an investor
    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    assert!(registry_service::is_investor(&registry, b"INV001".to_string()), 0);

    ts.next_tx(UNAUTHORIZED);
    // Remove the investor
    registry_service::remove_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    assert!(!registry_service::is_investor(&registry, b"INV001".to_string()), 1);

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = registry_service::EInvestorHasWallets)]
fun test_remove_investor_who_has_a_wallet() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);
    init_for_testing(ts.ctx()); // init namespace

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let investor_id = b"INV001".to_string();
    let wallet_addr = @0x1234;

    // Register an investor
    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        investor_id,
        &version,
        ts.ctx(),
    );

    let mut namespace = ts.take_shared<Namespace>();

    // Add a wallet for the investor
    registry_service::add_wallet(
        &mut registry,
        &auth,
        &mut namespace,
        investor_id,
        wallet_addr,
        &version,
        ts.ctx(),
    );

    // Remove the investor while he has a wallet should fail
    registry_service::remove_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        investor_id,
        &version,
        ts.ctx(),
    );

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts::return_shared(namespace);
    ts.end();
}

#[test]
#[expected_failure(abort_code = registry_service::EInvestorNotFound)]
fun test_remove_investor_not_found() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    // Try to remove a non-existent investor - should fail
    registry_service::remove_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_update_investor() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);
    init_for_testing(ts.ctx()); // init namespace

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let mut namespace = ts.take_shared<Namespace>();

    let investor_id = b"INV001".to_string();
    let wallet_addr = @0x1234;

    registry_service::update_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        &mut namespace,
        investor_id,
        b"Greece".to_string(),
        vector[wallet_addr],
        vector[1],
        vector[1],
        vector[1],
        &version,
        ts.ctx(),
    );

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts::return_shared(namespace);
    ts.end();
}

#[test]
fun test_update_investor_when_already_registered() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);
    init_for_testing(ts.ctx()); // init namespace

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let mut namespace = ts.take_shared<Namespace>();

    let investor_id = b"INV001".to_string();
    let wallet_addr = @0x1234;

    // Register an investor
    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        investor_id,
        &version,
        ts.ctx(),
    );

    registry_service::add_wallet(
        &mut registry,
        &auth,
        &mut namespace,
        investor_id,
        wallet_addr,
        &version,
        ts.ctx(),
    );

    registry_service::update_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        &mut namespace,
        investor_id,
        b"Greece".to_string(),
        vector[wallet_addr],
        vector[1],
        vector[1],
        vector[1],
        &version,
        ts.ctx(),
    );

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts::return_shared(namespace);
    ts.end();
}

#[test]
#[expected_failure(abort_code = registry_service::ENotAuthorized)]
fun test_update_investor_unauthorized() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);
    init_for_testing(ts.ctx()); // init namespace

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let mut namespace = ts.take_shared<Namespace>();

    let investor_id = b"INV001".to_string();
    let wallet_addr = @0x1234;

    ts.next_tx(UNAUTHORIZED);

    registry_service::update_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        &mut namespace,
        investor_id,
        b"Greece".to_string(),
        vector[wallet_addr],
        vector[1],
        vector[1],
        vector[1],
        &version,
        ts.ctx(),
    );

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts::return_shared(namespace);
    ts.end();
}

#[test]
#[expected_failure(abort_code = registry_service::EWrongVectorLength)]
fun test_update_investor_attribute_values_length_mismatch() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);
    init_for_testing(ts.ctx()); // init namespace

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let mut namespace = ts.take_shared<Namespace>();

    let investor_id = b"INV001".to_string();
    let wallet_addr = @0x1234;

    registry_service::update_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        &mut namespace,
        investor_id,
        b"Greece".to_string(),
        vector[wallet_addr],
        vector[1],
        vector[1, 2],
        vector[1],
        &version,
        ts.ctx(),
    );

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts::return_shared(namespace);
    ts.end();
}

#[test]
#[expected_failure(abort_code = registry_service::EWrongVectorLength)]
fun test_update_investor_attribute_expirations_length_mismatch() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);
    init_for_testing(ts.ctx()); // init namespace

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let mut namespace = ts.take_shared<Namespace>();

    let investor_id = b"INV001".to_string();
    let wallet_addr = @0x1234;

    registry_service::update_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        &mut namespace,
        investor_id,
        b"Greece".to_string(),
        vector[wallet_addr],
        vector[1],
        vector[1],
        vector[1, 2],
        &version,
        ts.ctx(),
    );

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts::return_shared(namespace);
    ts.end();
}

#[test]
#[expected_failure(abort_code = registry_service::EWrongInvestor)]
fun test_update_investor_fails_when_investor_wallet_mismatch() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);
    init_for_testing(ts.ctx()); // init namespace

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let mut namespace = ts.take_shared<Namespace>();

    let investor1_id = b"INV001".to_string();
    let investor2_id = b"INV002".to_string();
    let wallet_addr = @0x1234;

    // Register an investor
    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        investor1_id,
        &version,
        ts.ctx(),
    );
    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        investor2_id,
        &version,
        ts.ctx(),
    );

    registry_service::add_wallet(
        &mut registry,
        &auth,
        &mut namespace,
        investor1_id,
        wallet_addr,
        &version,
        ts.ctx(),
    );

    // try to update investor2 with a wallet of investor1 - should fail
    registry_service::update_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        &mut namespace,
        investor2_id,
        b"Greece".to_string(),
        vector[wallet_addr],
        vector[1],
        vector[1],
        vector[1],
        &version,
        ts.ctx(),
    );

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts::return_shared(namespace);
    ts.end();
}

// test add_wallet
// test remove_wallet

#[test]
fun test_set_country() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    // Register an investor
    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    // Set country
    registry_service::set_country<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        b"USA".to_string(),
        &version,
        ts.ctx(),
    );

    // Verify country
    let country = registry_service::get_country(&registry, b"INV001".to_string());
    assert!(country == b"USA".to_string(), 0);

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = registry_service::ENotAuthorized)]
fun test_set_country_unauthorized() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    // Register an investor
    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );
    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);

    ts.next_tx(UNAUTHORIZED);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    // Should fail - UNAUTHORIZED has no SetCountry ability
    registry_service::set_country<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        b"USA".to_string(),
        &version,
        ts.ctx(),
    );

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_issuance_creation() {
    // Test Issuance struct creation and accessors
    let issuance = registry_service::new_issuance(1000, 123456789);

    assert!(registry_service::issuance_amount(&issuance) == 1000, 0);
    assert!(registry_service::issuance_time_ms(&issuance) == 123456789, 1);
}

#[test]
fun test_set_attribute() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    // Register an investor
    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    // Set an attribute (ACCREDITED = 2)
    registry_service::set_attribute<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        2, // ACCREDITED
        1, // APPROVED
        9999999999, // expiration
        &version,
        ts.ctx(),
    );

    // Verify attribute value
    let value = registry_service::get_attribute_value(&registry, b"INV001".to_string(), 2);
    assert!(value == 1, 0);

    // Verify attribute expiration
    let expiration = registry_service::get_attribute_expiration(
        &registry,
        b"INV001".to_string(),
        2,
    );
    assert!(expiration == 9999999999, 1);

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_set_attribute_update_existing() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    // Register an investor
    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    // Set initial attribute
    registry_service::set_attribute<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        2,
        1,
        1000,
        &version,
        ts.ctx(),
    );

    // Update the same attribute
    registry_service::set_attribute<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        2,
        2, // new value
        2000, // new expiration
        &version,
        ts.ctx(),
    );

    // Verify updated values
    let value = registry_service::get_attribute_value(&registry, b"INV001".to_string(), 2);
    assert!(value == 2, 0);

    let expiration = registry_service::get_attribute_expiration(
        &registry,
        b"INV001".to_string(),
        2,
    );
    assert!(expiration == 2000, 1);

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = registry_service::EUnknownAttribute)]
fun test_set_attribute_unknown() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    // Register an investor
    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    // Try to set attribute with ID >= 16 - should fail
    registry_service::set_attribute<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        16, // Invalid: >= 16
        1,
        1000,
        &version,
        ts.ctx(),
    );

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_get_attribute_value_nonexistent() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    // Register an investor
    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    // Get nonexistent attribute - should return 0
    let value = registry_service::get_attribute_value(&registry, b"INV001".to_string(), 5);
    assert!(value == 0, 0);

    let expiration = registry_service::get_attribute_expiration(
        &registry,
        b"INV001".to_string(),
        5,
    );
    assert!(expiration == 0, 1);

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_get_country_compliance_nonexistent() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();

    // Get compliance for non-configured country - should return NONE (0)
    let compliance = registry_service::get_country_compliance(&registry, b"XX".to_string());
    assert!(compliance == 0, 0);

    ts::return_shared(registry);
    ts.end();
}

#[test]
fun test_investor_wallet_balance_total() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    // Register an investor
    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    // Initial balance should be 0
    let balance = registry_service::investor_wallet_balance_total(&registry, b"INV001".to_string());
    assert!(balance == 0, 0);

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_is_accredited_investor_by_id() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    // Register an investor
    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    // Initially not accredited
    assert!(!registry_service::is_accredited_investor_by_id(&registry, b"INV001".to_string()), 0);

    // Set ACCREDITED attribute to APPROVED (value = 1)
    registry_service::set_attribute<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        2, // ACCREDITED
        1, // APPROVED
        9999999999,
        &version,
        ts.ctx(),
    );

    // Now should be accredited
    assert!(registry_service::is_accredited_investor_by_id(&registry, b"INV001".to_string()), 1);

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_is_qualified_investor_by_id() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    // Register an investor
    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    // Initially not qualified
    assert!(!registry_service::is_qualified_investor_by_id(&registry, b"INV001".to_string()), 0);

    // Set QUALIFIED attribute to APPROVED (value = 1)
    registry_service::set_attribute<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        4, // QUALIFIED
        1, // APPROVED
        9999999999,
        &version,
        ts.ctx(),
    );

    // Now should be qualified
    assert!(registry_service::is_qualified_investor_by_id(&registry, b"INV001".to_string()), 1);

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_is_wallet_false() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();

    // Random address should not be a wallet
    assert!(!registry_service::is_wallet(&registry, @0x1234), 0);

    ts::return_shared(registry);
    ts.end();
}

#[test]
fun test_is_special_wallet_false() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();

    // Random address should not be a special wallet
    assert!(!registry_service::is_special_wallet(&registry, @0x1234), 0);

    ts::return_shared(registry);
    ts.end();
}
