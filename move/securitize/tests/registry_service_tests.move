#[test_only]
module securitize::registry_service_tests;

use pas::{account::Account, namespace::Namespace};
use securitize::{
    compliance_service::{Self, ComplianceConfig},
    ds_token::{Self, Treasury},
    registry_service::{Self, InvestorInfo},
    test_helpers::{
        Self as test_helpers,
        TEST_VOLORO,
        setup_with_treasury,
        add_platform_wallet,
        add_issuer_wallet
    },
    trust_service::Auth,
    version::Version
};
use sui::{clock, test_scenario::{Self as ts, Scenario}};

const ADMIN: address = @0x001;
const UNAUTHORIZED: address = @0x002;
const PLATFORM_WALLET: address = @0x3001;
const WALLET1: address = @0x1001;

// Compliance region constants
const COMPLIANCE_NONE: u64 = 0;
const COMPLIANCE_US: u64 = 1;
const COMPLIANCE_EU: u64 = 2;
const COMPLIANCE_JP: u64 = 8;

// Attribute constants
const ACCREDITED: u64 = 2;
const QUALIFIED: u64 = 4;
const APPROVED: u64 = 1;

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
    test_helpers::init_namespace_for_testing(&mut ts); // init namespace

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
    test_helpers::init_namespace_for_testing(&mut ts); // init namespace

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
    test_helpers::init_namespace_for_testing(&mut ts); // init namespace

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
    test_helpers::init_namespace_for_testing(&mut ts); // init namespace

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
    test_helpers::init_namespace_for_testing(&mut ts); // init namespace

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
    test_helpers::init_namespace_for_testing(&mut ts); // init namespace

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
    test_helpers::init_namespace_for_testing(&mut ts); // init namespace

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

// ==================== Special Wallet Balance Tests ====================

#[test]
fun test_special_wallet_balance_is_zero_on_add() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    // Add a platform wallet using test helper
    add_platform_wallet(&mut ts, PLATFORM_WALLET);

    ts.next_tx(ADMIN);
    let registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();

    // Verify the special wallet balance is 0 initially
    assert!(registry_service::special_wallet_balance(&registry, PLATFORM_WALLET) == 0, 0);

    ts::return_shared(registry);
    ts.end();
}

#[test]
fun test_update_special_wallet_total_balance() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    // Add a platform wallet using test helper
    add_platform_wallet(&mut ts, PLATFORM_WALLET);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();

    // Initially balance should be 0
    assert!(registry_service::special_wallet_balance(&registry, PLATFORM_WALLET) == 0, 0);

    // Update the balance to 1000
    registry_service::update_special_wallet_total_balance(&mut registry, PLATFORM_WALLET, 1000);

    // Verify the balance is now 1000
    assert!(registry_service::special_wallet_balance(&registry, PLATFORM_WALLET) == 1000, 1);

    // Update the balance again to 500
    registry_service::update_special_wallet_total_balance(&mut registry, PLATFORM_WALLET, 500);

    // Verify the balance is now 500
    assert!(registry_service::special_wallet_balance(&registry, PLATFORM_WALLET) == 500, 2);

    ts::return_shared(registry);
    ts.end();
}

#[test]
fun test_special_wallet_balance_after_remove_and_read() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    // Add a platform wallet using test helper
    add_platform_wallet(&mut ts, PLATFORM_WALLET);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    // Verify initial balance is 0
    assert!(registry_service::special_wallet_balance(&registry, PLATFORM_WALLET) == 0, 0);

    // Remove the platform wallet
    securitize::wallet_manager::remove_special_wallet<TEST_VOLORO>(
        &mut registry,
        &auth,
        PLATFORM_WALLET,
        &version,
        ts.ctx(),
    );

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);

    // Re-add the wallet
    add_platform_wallet(&mut ts, PLATFORM_WALLET);

    ts.next_tx(ADMIN);
    let registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();

    // Verify balance is reset to 0 after re-adding
    assert!(registry_service::special_wallet_balance(&registry, PLATFORM_WALLET) == 0, 1);

    ts::return_shared(registry);
    ts.end();
}

// ==================== Group 1: add_wallet Error Conditions ====================

#[test]
#[expected_failure(abort_code = registry_service::ENotAuthorized)]
fun test_add_wallet_unauthorized() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);
    test_helpers::init_namespace_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    // Register an investor first
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

    // Try to add wallet from unauthorized address
    ts.next_tx(UNAUTHORIZED);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let mut namespace = ts.take_shared<Namespace>();

    registry_service::add_wallet<TEST_VOLORO>(
        &mut registry,
        &auth,
        &mut namespace,
        b"INV001".to_string(),
        WALLET1,
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
#[expected_failure(abort_code = registry_service::ESpecialWallet)]
fun test_add_wallet_special_wallet_fails() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);
    test_helpers::init_namespace_for_testing(&mut ts);

    // Add issuer wallet first (makes it a special wallet)
    add_issuer_wallet(&mut ts, WALLET1);

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

    let mut namespace = ts.take_shared<Namespace>();

    // Try to add special wallet as investor wallet - should fail
    registry_service::add_wallet<TEST_VOLORO>(
        &mut registry,
        &auth,
        &mut namespace,
        b"INV001".to_string(),
        WALLET1,
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
fun test_add_wallet_investor_not_found() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);
    test_helpers::init_namespace_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let mut namespace = ts.take_shared<Namespace>();

    // Try to add wallet to non-existent investor - should fail
    registry_service::add_wallet<TEST_VOLORO>(
        &mut registry,
        &auth,
        &mut namespace,
        b"INV001".to_string(),
        WALLET1,
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
#[expected_failure(abort_code = registry_service::EWalletAlreadyExists)]
fun test_add_wallet_already_exists() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);
    test_helpers::init_namespace_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let mut namespace = ts.take_shared<Namespace>();

    // Register an investor and add a wallet
    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    registry_service::add_wallet<TEST_VOLORO>(
        &mut registry,
        &auth,
        &mut namespace,
        b"INV001".to_string(),
        WALLET1,
        &version,
        ts.ctx(),
    );

    // Try to add the same wallet again - should fail
    registry_service::add_wallet<TEST_VOLORO>(
        &mut registry,
        &auth,
        &mut namespace,
        b"INV001".to_string(),
        WALLET1,
        &version,
        ts.ctx(),
    );

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts::return_shared(namespace);
    ts.end();
}

// ==================== Group 2: remove_wallet Error Conditions ====================

#[test]
#[expected_failure(abort_code = registry_service::ENotAuthorized)]
fun test_remove_wallet_unauthorized() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);
    test_helpers::init_namespace_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let mut namespace = ts.take_shared<Namespace>();

    // Register an investor and add a wallet
    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    registry_service::add_wallet<TEST_VOLORO>(
        &mut registry,
        &auth,
        &mut namespace,
        b"INV001".to_string(),
        WALLET1,
        &version,
        ts.ctx(),
    );

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts::return_shared(namespace);

    // Try to remove wallet from unauthorized address
    ts.next_tx(UNAUTHORIZED);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    registry_service::remove_wallet<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        WALLET1,
        &version,
        ts.ctx(),
    );

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = registry_service::EWalletNotFound)]
fun test_remove_wallet_not_found() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);
    test_helpers::init_namespace_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    // Register an investor (no wallet added)
    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    // Try to remove non-existent wallet - should fail
    registry_service::remove_wallet<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        WALLET1,
        &version,
        ts.ctx(),
    );

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = registry_service::EWalletDoesNotBelongToInvestor)]
fun test_remove_wallet_wrong_investor() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);
    test_helpers::init_namespace_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let mut namespace = ts.take_shared<Namespace>();

    // Register two investors
    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );
    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV002".to_string(),
        &version,
        ts.ctx(),
    );

    // Add wallet to INV001
    registry_service::add_wallet<TEST_VOLORO>(
        &mut registry,
        &auth,
        &mut namespace,
        b"INV001".to_string(),
        WALLET1,
        &version,
        ts.ctx(),
    );

    // Try to remove INV001's wallet specifying INV002 - should fail
    registry_service::remove_wallet<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV002".to_string(),
        WALLET1,
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
#[expected_failure(abort_code = registry_service::EWalletNotEmpty)]
fun test_remove_wallet_not_empty() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);
    test_helpers::init_namespace_for_testing(&mut ts);

    // Register investor and add wallet (creates PAS account)
    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let mut namespace = ts.take_shared<Namespace>();

    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    registry_service::add_wallet<TEST_VOLORO>(
        &mut registry,
        &auth,
        &mut namespace,
        b"INV001".to_string(),
        WALLET1,
        &version,
        ts.ctx(),
    );

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts::return_shared(namespace);

    // Issue tokens to give the wallet a non-zero balance
    ts.next_tx(ADMIN);
    let mut treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let account = ts.take_shared<Account>();
    let clock = clock::create_for_testing(ts.ctx());

    ds_token::issue_tokens(
        &mut treasury,
        &auth,
        &mut investor_info,
        &mut compliance,
        &account,
        WALLET1,
        100,
        0,
        b"".to_string(),
        &version,
        vector[],
        vector[],
        clock.timestamp_ms(),
        &clock,
        ts.ctx(),
    );

    clock.destroy_for_testing();
    ts::return_shared(treasury);
    ts::return_shared(auth);
    ts::return_shared(investor_info);
    ts::return_shared(compliance);
    ts::return_shared(version);
    ts::return_shared(account);

    // Try to remove wallet with non-zero balance — should fail
    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    registry_service::remove_wallet<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        WALLET1,
        &version,
        ts.ctx(),
    );

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

// ==================== Group 3: set_attribute Error Conditions ====================

#[test]
#[expected_failure(abort_code = registry_service::ENotAuthorized)]
fun test_set_attribute_unauthorized() {
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

    // Try to set attribute from unauthorized address
    ts.next_tx(UNAUTHORIZED);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    registry_service::set_attribute<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        ACCREDITED,
        APPROVED,
        9999999999,
        &version,
        ts.ctx(),
    );

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = registry_service::EInvestorNotFound)]
fun test_set_attribute_investor_not_found() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    // Try to set attribute for non-existent investor - should fail
    registry_service::set_attribute<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        ACCREDITED,
        APPROVED,
        9999999999,
        &version,
        ts.ctx(),
    );

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

// ==================== Group 4: set_country Error Condition ====================

#[test]
#[expected_failure(abort_code = registry_service::EInvestorNotFound)]
fun test_set_country_investor_not_found() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    // Try to set country for non-existent investor - should fail
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

// ==================== Group 5: View Function Error Conditions ====================

#[test]
#[expected_failure(abort_code = registry_service::EInvestorNotFound)]
fun test_get_investor_id_by_wallet_not_found() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();

    // Query non-existent wallet - should fail
    let _investor_id = registry_service::get_investor_id_by_wallet(&registry, WALLET1);

    ts::return_shared(registry);
    ts.end();
}

#[test]
#[expected_failure(abort_code = registry_service::EInvestorNotFound)]
fun test_investor_wallet_balance_total_not_found() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();

    // Query balance for non-existent investor - should fail
    let _balance = registry_service::investor_wallet_balance_total(
        &registry,
        b"INV001".to_string(),
    );

    ts::return_shared(registry);
    ts.end();
}

#[test]
#[expected_failure(abort_code = registry_service::EWalletNotFound)]
fun test_investor_wallet_balance_not_found() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();

    // Query balance for non-existent wallet - should fail
    let _balance = registry_service::investor_wallet_balance(&registry, WALLET1);

    ts::return_shared(registry);
    ts.end();
}

// ==================== Group 6: Getter Function Tests ====================

#[test]
fun test_get_total_investors_count() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    // Initially should be 0
    assert!(registry_service::get_total_investors_count(&registry) == 0, 0);

    // Register an investor (note: registration alone doesn't increment count,
    // count is managed via country/balance changes)
    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    // Test set_total_investors_count to verify getter/setter work together
    registry_service::set_total_investors_count(&mut registry, 5);
    assert!(registry_service::get_total_investors_count(&registry) == 5, 1);

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_get_accredited_investor_count() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();

    // Initially should be 0
    assert!(registry_service::get_accredited_investor_count(&registry) == 0, 0);

    ts::return_shared(registry);
    ts.end();
}

#[test]
fun test_get_us_investor_count() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();

    // Initially should be 0
    assert!(registry_service::get_us_investor_count(&registry) == 0, 0);

    ts::return_shared(registry);
    ts.end();
}

#[test]
fun test_get_us_accredited_investor_count() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();

    // Initially should be 0
    assert!(registry_service::get_us_accredited_investor_count(&registry) == 0, 0);

    ts::return_shared(registry);
    ts.end();
}

#[test]
fun test_get_jp_investor_count() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();

    // Initially should be 0
    assert!(registry_service::get_jp_investor_count(&registry) == 0, 0);

    ts::return_shared(registry);
    ts.end();
}

#[test]
fun test_get_eu_retail_investor_count_none() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();

    // Non-configured country should return None
    let count = registry_service::get_eu_retail_investor_count(&registry, b"DEU".to_string());
    assert!(count.is_none(), 0);

    ts::return_shared(registry);
    ts.end();
}

#[test]
fun test_get_eu_retail_investor_count_some() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    // Set country compliance to EU
    test_helpers::set_country_compliance(&mut ts, b"DEU", COMPLIANCE_EU);

    ts.next_tx(ADMIN);
    let registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();

    // Configured EU country should return Some(0)
    let count = registry_service::get_eu_retail_investor_count(&registry, b"DEU".to_string());
    assert!(count.is_some(), 0);
    assert!(*count.borrow() == 0, 1);

    ts::return_shared(registry);
    ts.end();
}

// ==================== Group 7: Wallet-based Investor Checks ====================

#[test]
fun test_is_accredited_investor_by_wallet() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);
    test_helpers::init_namespace_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let mut namespace = ts.take_shared<Namespace>();

    // Register investor with wallet
    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    registry_service::add_wallet<TEST_VOLORO>(
        &mut registry,
        &auth,
        &mut namespace,
        b"INV001".to_string(),
        WALLET1,
        &version,
        ts.ctx(),
    );

    // Initially not accredited
    assert!(!registry_service::is_accredited_investor(&registry, WALLET1), 0);

    // Set ACCREDITED attribute to APPROVED
    registry_service::set_attribute<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        ACCREDITED,
        APPROVED,
        9999999999,
        &version,
        ts.ctx(),
    );

    // Now should be accredited
    assert!(registry_service::is_accredited_investor(&registry, WALLET1), 1);

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts::return_shared(namespace);
    ts.end();
}

#[test]
fun test_is_qualified_investor_by_wallet() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);
    test_helpers::init_namespace_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let mut namespace = ts.take_shared<Namespace>();

    // Register investor with wallet
    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    registry_service::add_wallet<TEST_VOLORO>(
        &mut registry,
        &auth,
        &mut namespace,
        b"INV001".to_string(),
        WALLET1,
        &version,
        ts.ctx(),
    );

    // Initially not qualified
    assert!(!registry_service::is_qualified_investor(&registry, WALLET1), 0);

    // Set QUALIFIED attribute to APPROVED
    registry_service::set_attribute<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        QUALIFIED,
        APPROVED,
        9999999999,
        &version,
        ts.ctx(),
    );

    // Now should be qualified
    assert!(registry_service::is_qualified_investor(&registry, WALLET1), 1);

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts::return_shared(namespace);
    ts.end();
}

// ==================== Group 8: set_country_compliance Branch Coverage ====================

#[test]
#[expected_failure(abort_code = registry_service::EComplianceUnchanged)]
fun test_set_country_compliance_unchanged_fails() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    // Set country compliance to US
    test_helpers::set_country_compliance(&mut ts, b"USA", COMPLIANCE_US);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    // Try to set the same compliance region again - should fail
    compliance_service::set_country_compliance<TEST_VOLORO>(
        &mut registry,
        b"USA".to_string(),
        COMPLIANCE_US,
        &auth,
        &version,
        ts.ctx(),
    );

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_set_country_compliance_to_none() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    // Set country compliance to US first
    test_helpers::set_country_compliance(&mut ts, b"USA", COMPLIANCE_US);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    // Verify it's US
    assert!(
        registry_service::get_country_compliance(&registry, b"USA".to_string()) == COMPLIANCE_US,
        0,
    );

    // Set to NONE (removes entry)
    compliance_service::set_country_compliance<TEST_VOLORO>(
        &mut registry,
        b"USA".to_string(),
        COMPLIANCE_NONE,
        &auth,
        &version,
        ts.ctx(),
    );

    // Should return NONE (0) now
    assert!(
        registry_service::get_country_compliance(&registry, b"USA".to_string()) == COMPLIANCE_NONE,
        1,
    );

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_set_country_compliance_to_eu() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    // Set country compliance to EU
    compliance_service::set_country_compliance<TEST_VOLORO>(
        &mut registry,
        b"DEU".to_string(),
        COMPLIANCE_EU,
        &auth,
        &version,
        ts.ctx(),
    );

    // Verify compliance is EU
    assert!(
        registry_service::get_country_compliance(&registry, b"DEU".to_string()) == COMPLIANCE_EU,
        0,
    );

    // Verify EU retail count is initialized
    let count = registry_service::get_eu_retail_investor_count(&registry, b"DEU".to_string());
    assert!(count.is_some(), 1);

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_set_country_compliance_update_existing() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    // Set country compliance to US first
    test_helpers::set_country_compliance(&mut ts, b"USA", COMPLIANCE_US);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    // Verify it's US
    assert!(
        registry_service::get_country_compliance(&registry, b"USA".to_string()) == COMPLIANCE_US,
        0,
    );

    // Update to JP
    compliance_service::set_country_compliance<TEST_VOLORO>(
        &mut registry,
        b"USA".to_string(),
        COMPLIANCE_JP,
        &auth,
        &version,
        ts.ctx(),
    );

    // Should now be JP
    assert!(
        registry_service::get_country_compliance(&registry, b"USA".to_string()) == COMPLIANCE_JP,
        1,
    );

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

// ==================== Group 9: Package Balance Update Functions ====================

#[test]
fun test_update_investor_total_balance() {
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
    assert!(
        registry_service::investor_wallet_balance_total(&registry, b"INV001".to_string()) == 0,
        0,
    );

    // Update total balance
    registry_service::update_investor_total_balance<TEST_VOLORO>(
        &mut registry,
        b"INV001".to_string(),
        1000,
    );

    // Verify balance is 1000
    assert!(
        registry_service::investor_wallet_balance_total(&registry, b"INV001".to_string()) == 1000,
        1,
    );

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_update_investor_total_balance_multiple_updates() {
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

    // Update balance to 1000
    registry_service::update_investor_total_balance<TEST_VOLORO>(
        &mut registry,
        b"INV001".to_string(),
        1000,
    );

    // Update balance to 500
    registry_service::update_investor_total_balance<TEST_VOLORO>(
        &mut registry,
        b"INV001".to_string(),
        500,
    );

    // Verify final balance is 500
    assert!(
        registry_service::investor_wallet_balance_total(&registry, b"INV001".to_string()) == 500,
        0,
    );

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_update_wallet_balance() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);
    test_helpers::init_namespace_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let mut namespace = ts.take_shared<Namespace>();

    // Register investor with wallet
    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    registry_service::add_wallet<TEST_VOLORO>(
        &mut registry,
        &auth,
        &mut namespace,
        b"INV001".to_string(),
        WALLET1,
        &version,
        ts.ctx(),
    );

    // Initial wallet balance should be 0
    assert!(registry_service::investor_wallet_balance(&registry, WALLET1) == 0, 0);

    // Update wallet balance
    registry_service::update_wallet_balance<TEST_VOLORO>(
        &mut registry,
        WALLET1,
        500,
    );

    // Verify balance is 500
    assert!(registry_service::investor_wallet_balance(&registry, WALLET1) == 500, 1);

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts::return_shared(namespace);
    ts.end();
}

#[test]
fun test_update_wallet_balance_multiple_updates() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);
    test_helpers::init_namespace_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let mut namespace = ts.take_shared<Namespace>();

    // Register investor with wallet
    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    registry_service::add_wallet<TEST_VOLORO>(
        &mut registry,
        &auth,
        &mut namespace,
        b"INV001".to_string(),
        WALLET1,
        &version,
        ts.ctx(),
    );

    // Update wallet balance to 500
    registry_service::update_wallet_balance<TEST_VOLORO>(
        &mut registry,
        WALLET1,
        500,
    );

    // Update wallet balance to 200
    registry_service::update_wallet_balance<TEST_VOLORO>(
        &mut registry,
        WALLET1,
        200,
    );

    // Verify final balance is 200
    assert!(registry_service::investor_wallet_balance(&registry, WALLET1) == 200, 0);

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts::return_shared(namespace);
    ts.end();
}

// ==================== Group 10: Investor Count Setters ====================

#[test]
fun test_set_us_investors_count() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();

    // Initially 0
    assert!(registry_service::get_us_investor_count(&registry) == 0, 0);

    // Set to 10
    registry_service::set_us_investors_count(&mut registry, 10);
    assert!(registry_service::get_us_investor_count(&registry) == 10, 1);

    ts::return_shared(registry);
    ts.end();
}

#[test]
fun test_set_us_accredited_investors_count() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();

    // Initially 0
    assert!(registry_service::get_us_accredited_investor_count(&registry) == 0, 0);

    // Set to 5
    registry_service::set_us_accredited_investors_count(&mut registry, 5);
    assert!(registry_service::get_us_accredited_investor_count(&registry) == 5, 1);

    ts::return_shared(registry);
    ts.end();
}

#[test]
fun test_set_accredited_investors_count() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();

    // Initially 0
    assert!(registry_service::get_accredited_investor_count(&registry) == 0, 0);

    // Set to 15
    registry_service::set_accredited_investors_count(&mut registry, 15);
    assert!(registry_service::get_accredited_investor_count(&registry) == 15, 1);

    ts::return_shared(registry);
    ts.end();
}

#[test]
fun test_set_jp_investors_count() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();

    // Initially 0
    assert!(registry_service::get_jp_investor_count(&registry) == 0, 0);

    // Set to 8
    registry_service::set_jp_investors_count(&mut registry, 8);
    assert!(registry_service::get_jp_investor_count(&registry) == 8, 1);

    ts::return_shared(registry);
    ts.end();
}

// ==================== Group 11: EU Retail Investors Country ====================

#[test]
fun test_set_eu_retail_investors_country_if_not_exists() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();

    // Initially country not configured
    let count = registry_service::get_eu_retail_investor_count(&registry, b"FRA".to_string());
    assert!(count.is_none(), 0);

    // Set EU retail country
    registry_service::set_eu_retail_investors_country_if_not_exists(
        &mut registry,
        b"FRA".to_string(),
    );

    // Now should return Some(0)
    let count = registry_service::get_eu_retail_investor_count(&registry, b"FRA".to_string());
    assert!(count.is_some(), 1);
    assert!(*count.borrow() == 0, 2);

    ts::return_shared(registry);
    ts.end();
}

#[test]
fun test_set_eu_retail_investors_country_if_not_exists_idempotent() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();

    // Set EU retail country twice (should be idempotent)
    registry_service::set_eu_retail_investors_country_if_not_exists(
        &mut registry,
        b"FRA".to_string(),
    );
    registry_service::set_eu_retail_investors_country_if_not_exists(
        &mut registry,
        b"FRA".to_string(),
    );

    // Should still return Some(0)
    let count = registry_service::get_eu_retail_investor_count(&registry, b"FRA".to_string());
    assert!(count.is_some(), 0);
    assert!(*count.borrow() == 0, 1);

    ts::return_shared(registry);
    ts.end();
}

// ==================== Group 12: Investor Issuances ====================

#[test]
fun test_get_investor_issuances() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    // Register investor (initializes issuances table entry)
    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    // Get issuances - should be empty vector initially
    let issuances = registry_service::get_investor_issuances(&registry, b"INV001".to_string());
    assert!(issuances.length() == 0, 0);

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_get_investor_issuances_mut_and_modify() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    // Register investor
    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    // Get mutable issuances and add one
    let issuances = registry_service::get_investor_issuances_mut(
        &mut registry,
        b"INV001".to_string(),
    );
    let issuance = registry_service::new_issuance(1000, 123456789);
    issuances.push_back(issuance);

    // Verify issuance was added
    let issuances_ref = registry_service::get_investor_issuances(&registry, b"INV001".to_string());
    assert!(issuances_ref.length() == 1, 0);

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure]
fun test_get_investor_issuances_not_found() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();

    // Try to get issuances for non-existent investor - should abort
    let _issuances = registry_service::get_investor_issuances(&registry, b"INV001".to_string());

    ts::return_shared(registry);
    ts.end();
}

#[test]
#[expected_failure]
fun test_get_investor_issuances_mut_not_found() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();

    // Try to get mutable issuances for non-existent investor - should abort
    let _issuances = registry_service::get_investor_issuances_mut(
        &mut registry,
        b"INV001".to_string(),
    );

    ts::return_shared(registry);
    ts.end();
}

// ==================== Group 13: Investor Locks Access ====================

#[test]
fun test_get_investor_locks() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    // Register investor (initializes lock state)
    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    // Get locks - should have initial state
    let lock_state = registry_service::get_investor_locks(&registry, b"INV001".to_string());
    assert!(!registry_service::is_fully_locked(lock_state), 0);
    assert!(!registry_service::is_liquidate_only(lock_state), 1);
    assert!(registry_service::locks_length(lock_state) == 0, 2);

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_get_investor_locks_mut_and_modify() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    // Register investor
    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    // Get mutable lock state and modify
    let lock_state = registry_service::get_investor_locks_mut(&mut registry, b"INV001".to_string());
    registry_service::set_fully_locked(lock_state, true);

    // Verify modification persisted
    let lock_state_ref = registry_service::get_investor_locks(&registry, b"INV001".to_string());
    assert!(registry_service::is_fully_locked(lock_state_ref), 0);

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure]
fun test_get_investor_locks_not_found() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();

    // Try to get locks for non-existent investor - should abort
    let _lock_state = registry_service::get_investor_locks(&registry, b"INV001".to_string());

    ts::return_shared(registry);
    ts.end();
}

#[test]
#[expected_failure]
fun test_get_investor_locks_mut_not_found() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();

    // Try to get mutable locks for non-existent investor - should abort
    let _lock_state = registry_service::get_investor_locks_mut(
        &mut registry,
        b"INV001".to_string(),
    );

    ts::return_shared(registry);
    ts.end();
}

// ==================== Group 14: Lock State Flags ====================

#[test]
fun test_is_fully_locked_initial() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    let lock_state = registry_service::get_investor_locks(&registry, b"INV001".to_string());
    assert!(!registry_service::is_fully_locked(lock_state), 0);

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_set_fully_locked() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    // Set fully locked to true
    let lock_state = registry_service::get_investor_locks_mut(&mut registry, b"INV001".to_string());
    registry_service::set_fully_locked(lock_state, true);

    // Verify
    let lock_state_ref = registry_service::get_investor_locks(&registry, b"INV001".to_string());
    assert!(registry_service::is_fully_locked(lock_state_ref), 0);

    // Set back to false
    let lock_state = registry_service::get_investor_locks_mut(&mut registry, b"INV001".to_string());
    registry_service::set_fully_locked(lock_state, false);

    let lock_state_ref = registry_service::get_investor_locks(&registry, b"INV001".to_string());
    assert!(!registry_service::is_fully_locked(lock_state_ref), 1);

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_is_liquidate_only_initial() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    let lock_state = registry_service::get_investor_locks(&registry, b"INV001".to_string());
    assert!(!registry_service::is_liquidate_only(lock_state), 0);

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_set_liquidate_only() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    // Set liquidate only to true
    let lock_state = registry_service::get_investor_locks_mut(&mut registry, b"INV001".to_string());
    registry_service::set_liquidate_only(lock_state, true);

    // Verify
    let lock_state_ref = registry_service::get_investor_locks(&registry, b"INV001".to_string());
    assert!(registry_service::is_liquidate_only(lock_state_ref), 0);

    // Set back to false
    let lock_state = registry_service::get_investor_locks_mut(&mut registry, b"INV001".to_string());
    registry_service::set_liquidate_only(lock_state, false);

    let lock_state_ref = registry_service::get_investor_locks(&registry, b"INV001".to_string());
    assert!(!registry_service::is_liquidate_only(lock_state_ref), 1);

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

// ==================== Group 15: Lock Management ====================

#[test]
fun test_locks_length_initial() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    let lock_state = registry_service::get_investor_locks(&registry, b"INV001".to_string());
    assert!(registry_service::locks_length(lock_state) == 0, 0);

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_add_lock() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    // Add a lock
    let lock_state = registry_service::get_investor_locks_mut(&mut registry, b"INV001".to_string());
    registry_service::add_lock(lock_state, 1000, 1, b"test lock".to_string(), 1000000000);

    // Verify
    let lock_state_ref = registry_service::get_investor_locks(&registry, b"INV001".to_string());
    assert!(registry_service::locks_length(lock_state_ref) == 1, 0);

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_add_multiple_locks() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    // Add 3 locks
    let lock_state = registry_service::get_investor_locks_mut(&mut registry, b"INV001".to_string());
    registry_service::add_lock(lock_state, 1000, 1, b"lock 1".to_string(), 1000000000);
    registry_service::add_lock(lock_state, 2000, 2, b"lock 2".to_string(), 2000000000);
    registry_service::add_lock(lock_state, 3000, 3, b"lock 3".to_string(), 3000000000);

    // Verify
    let lock_state_ref = registry_service::get_investor_locks(&registry, b"INV001".to_string());
    assert!(registry_service::locks_length(lock_state_ref) == 3, 0);

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_remove_lock_first_index() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    // Add 2 locks
    let lock_state = registry_service::get_investor_locks_mut(&mut registry, b"INV001".to_string());
    registry_service::add_lock(lock_state, 1000, 1, b"lock 1".to_string(), 1000000000);
    registry_service::add_lock(lock_state, 2000, 2, b"lock 2".to_string(), 2000000000);

    // Remove first lock (index 0)
    let lock_state = registry_service::get_investor_locks_mut(&mut registry, b"INV001".to_string());
    let removed_lock = registry_service::remove_lock(lock_state, 0);

    // Verify removed lock has correct value (swap-remove, so first lock should be 1000)
    assert!(registry_service::lock_value(&removed_lock) == 1000, 0);

    // Verify length is now 1
    let lock_state_ref = registry_service::get_investor_locks(&registry, b"INV001".to_string());
    assert!(registry_service::locks_length(lock_state_ref) == 1, 1);

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_remove_lock_last_index() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    // Add 2 locks
    let lock_state = registry_service::get_investor_locks_mut(&mut registry, b"INV001".to_string());
    registry_service::add_lock(lock_state, 1000, 1, b"lock 1".to_string(), 1000000000);
    registry_service::add_lock(lock_state, 2000, 2, b"lock 2".to_string(), 2000000000);

    // Remove last lock (index 1)
    let lock_state = registry_service::get_investor_locks_mut(&mut registry, b"INV001".to_string());
    let removed_lock = registry_service::remove_lock(lock_state, 1);

    // Verify removed lock has correct value
    assert!(registry_service::lock_value(&removed_lock) == 2000, 0);

    // Verify length is now 1
    let lock_state_ref = registry_service::get_investor_locks(&registry, b"INV001".to_string());
    assert!(registry_service::locks_length(lock_state_ref) == 1, 1);

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_lock_accessors() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    // Add a lock with known values
    let lock_state = registry_service::get_investor_locks_mut(&mut registry, b"INV001".to_string());
    registry_service::add_lock(lock_state, 5000, 42, b"reason string".to_string(), 9999999999);

    // Remove the lock to get it
    let lock_state = registry_service::get_investor_locks_mut(&mut registry, b"INV001".to_string());
    let lock = registry_service::remove_lock(lock_state, 0);

    // Verify all accessors
    assert!(registry_service::lock_value(&lock) == 5000, 0);
    assert!(registry_service::lock_reason_code(&lock) == 42, 1);
    assert!(registry_service::lock_reason_string(&lock) == b"reason string".to_string(), 2);
    assert!(registry_service::lock_release_time_ms(&lock) == 9999999999, 3);

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

// ==================== Group 16: add_wallet Account Condition ====================

#[test]
fun test_add_wallet_creates_account_when_not_exists() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);
    test_helpers::init_namespace_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let mut namespace = ts.take_shared<Namespace>();

    // Register investor
    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    // Account doesn't exist for WALLET1 initially - add_wallet should create it
    registry_service::add_wallet<TEST_VOLORO>(
        &mut registry,
        &auth,
        &mut namespace,
        b"INV001".to_string(),
        WALLET1,
        &version,
        ts.ctx(),
    );

    // Verify wallet was added
    assert!(registry_service::is_wallet(&registry, WALLET1), 0);

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts::return_shared(namespace);
    ts.end();
}

#[test]
fun test_add_wallet_when_account_already_exists() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);
    test_helpers::init_namespace_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let mut namespace = ts.take_shared<Namespace>();

    // Register two investors
    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );
    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV002".to_string(),
        &version,
        ts.ctx(),
    );

    // Add wallet to first investor (creates account)
    registry_service::add_wallet<TEST_VOLORO>(
        &mut registry,
        &auth,
        &mut namespace,
        b"INV001".to_string(),
        WALLET1,
        &version,
        ts.ctx(),
    );

    // Remove wallet from first investor
    registry_service::remove_wallet<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        WALLET1,
        &version,
        ts.ctx(),
    );

    // Now add the same wallet to second investor - account already exists
    registry_service::add_wallet<TEST_VOLORO>(
        &mut registry,
        &auth,
        &mut namespace,
        b"INV002".to_string(),
        WALLET1,
        &version,
        ts.ctx(),
    );

    // Verify wallet belongs to INV002
    let owner = registry_service::get_investor_id_by_wallet(&registry, WALLET1);
    assert!(owner == b"INV002".to_string(), 0);

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts::return_shared(namespace);
    ts.end();
}

// ==================== Group 17: remove_wallet Success Flow ====================

#[test]
fun test_remove_wallet_success() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);
    test_helpers::init_namespace_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let mut namespace = ts.take_shared<Namespace>();

    // Register investor and add wallet
    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    registry_service::add_wallet<TEST_VOLORO>(
        &mut registry,
        &auth,
        &mut namespace,
        b"INV001".to_string(),
        WALLET1,
        &version,
        ts.ctx(),
    );

    // Verify wallet exists
    assert!(registry_service::is_wallet(&registry, WALLET1), 0);

    // Remove wallet (balance is 0)
    registry_service::remove_wallet<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        WALLET1,
        &version,
        ts.ctx(),
    );

    // Verify wallet no longer exists
    assert!(!registry_service::is_wallet(&registry, WALLET1), 1);

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts::return_shared(namespace);
    ts.end();
}

// ==================== Group 18: get_investor_id_by_wallet Success ====================

#[test]
fun test_get_investor_id_by_wallet_success() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);
    test_helpers::init_namespace_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let mut namespace = ts.take_shared<Namespace>();

    // Register investor and add wallet
    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    registry_service::add_wallet<TEST_VOLORO>(
        &mut registry,
        &auth,
        &mut namespace,
        b"INV001".to_string(),
        WALLET1,
        &version,
        ts.ctx(),
    );

    // Get investor ID by wallet
    let investor_id = registry_service::get_investor_id_by_wallet(&registry, WALLET1);
    assert!(investor_id == b"INV001".to_string(), 0);

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts::return_shared(namespace);
    ts.end();
}

// ==================== Group 19: compute_locked_sum ====================

#[test]
fun test_compute_locked_sum_empty() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    // No locks - sum should be 0
    let lock_state = registry_service::get_investor_locks(&registry, b"INV001".to_string());
    let sum = registry_service::compute_locked_sum(lock_state, 1000000);
    assert!(sum == 0, 0);

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_compute_locked_sum_permanent_lock() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    // Add permanent lock (release_time_ms = 0)
    let lock_state = registry_service::get_investor_locks_mut(&mut registry, b"INV001".to_string());
    registry_service::add_lock(lock_state, 1000, 1, b"permanent".to_string(), 0);

    // Permanent lock should always be counted regardless of now_ms
    let lock_state = registry_service::get_investor_locks(&registry, b"INV001".to_string());
    let sum = registry_service::compute_locked_sum(lock_state, 9999999999);
    assert!(sum == 1000, 0);

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_compute_locked_sum_unreleased_lock() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    // Add lock with release_time_ms in future
    let lock_state = registry_service::get_investor_locks_mut(&mut registry, b"INV001".to_string());
    registry_service::add_lock(lock_state, 2000, 1, b"future".to_string(), 5000000);

    // Lock release time > now_ms, should be counted
    let lock_state = registry_service::get_investor_locks(&registry, b"INV001".to_string());
    let sum = registry_service::compute_locked_sum(lock_state, 1000000);
    assert!(sum == 2000, 0);

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_compute_locked_sum_released_lock() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    // Add lock with release_time_ms in past
    let lock_state = registry_service::get_investor_locks_mut(&mut registry, b"INV001".to_string());
    registry_service::add_lock(lock_state, 3000, 1, b"past".to_string(), 500000);

    // Lock release time <= now_ms, should NOT be counted
    let lock_state = registry_service::get_investor_locks(&registry, b"INV001".to_string());
    let sum = registry_service::compute_locked_sum(lock_state, 1000000);
    assert!(sum == 0, 0);

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_compute_locked_sum_mixed_locks() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    // Add mixed locks
    let lock_state = registry_service::get_investor_locks_mut(&mut registry, b"INV001".to_string());
    registry_service::add_lock(lock_state, 1000, 1, b"permanent".to_string(), 0); // counted
    registry_service::add_lock(lock_state, 2000, 2, b"future".to_string(), 5000000); // counted
    registry_service::add_lock(lock_state, 3000, 3, b"past".to_string(), 500000); // NOT counted

    // Sum should be 1000 + 2000 = 3000 (excluding released lock)
    let lock_state = registry_service::get_investor_locks(&registry, b"INV001".to_string());
    let sum = registry_service::compute_locked_sum(lock_state, 1000000);
    assert!(sum == 3000, 0);

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

// ==================== Group 20: apply_change ====================

#[test]
fun test_apply_change_increase() {
    let mut counter: u64 = 5;
    registry_service::apply_change(&mut counter, true);
    assert!(counter == 6, 0);
}

#[test]
fun test_apply_change_decrease() {
    let mut counter: u64 = 5;
    registry_service::apply_change(&mut counter, false);
    assert!(counter == 4, 0);
}

#[test]
#[expected_failure]
fun test_apply_change_decrease_underflow() {
    let mut counter: u64 = 0;
    registry_service::apply_change(&mut counter, false);
}

// ==================== Group 21: adjust_investors_counts_by_country ====================

#[test]
fun test_adjust_investors_counts_accredited_us_investor() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    // Set USA as US compliance region
    test_helpers::set_country_compliance(&mut ts, b"USA", COMPLIANCE_US);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    // Register investor
    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    // Set investor as accredited
    registry_service::set_attribute<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        ACCREDITED,
        APPROVED,
        9999999999,
        &version,
        ts.ctx(),
    );

    // Initial counts
    assert!(registry_service::get_accredited_investor_count(&registry) == 0, 0);
    assert!(registry_service::get_us_accredited_investor_count(&registry) == 0, 1);
    assert!(registry_service::get_us_investor_count(&registry) == 0, 2);

    // Adjust counts (increase)
    registry_service::adjust_investors_counts_by_country(
        &mut registry,
        b"INV001".to_string(),
        b"USA".to_string(),
        true,
    );

    // Verify all counters increased
    assert!(registry_service::get_accredited_investor_count(&registry) == 1, 3);
    assert!(registry_service::get_us_accredited_investor_count(&registry) == 1, 4);
    assert!(registry_service::get_us_investor_count(&registry) == 1, 5);

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_adjust_investors_counts_non_accredited_us_investor() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    // Set USA as US compliance region
    test_helpers::set_country_compliance(&mut ts, b"USA", COMPLIANCE_US);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    // Register investor (non-accredited by default)
    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    // Adjust counts (increase)
    registry_service::adjust_investors_counts_by_country(
        &mut registry,
        b"INV001".to_string(),
        b"USA".to_string(),
        true,
    );

    // Only us_investors_count should increase
    assert!(registry_service::get_accredited_investor_count(&registry) == 0, 0);
    assert!(registry_service::get_us_accredited_investor_count(&registry) == 0, 1);
    assert!(registry_service::get_us_investor_count(&registry) == 1, 2);

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_adjust_investors_counts_eu_non_qualified_investor() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    // Set DEU as EU compliance region
    test_helpers::set_country_compliance(&mut ts, b"DEU", COMPLIANCE_EU);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    // Register investor (non-qualified by default)
    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    // Initial EU retail count
    let count = registry_service::get_eu_retail_investor_count(&registry, b"DEU".to_string());
    assert!(count.is_some() && *count.borrow() == 0, 0);

    // Adjust counts (increase)
    registry_service::adjust_investors_counts_by_country(
        &mut registry,
        b"INV001".to_string(),
        b"DEU".to_string(),
        true,
    );

    // EU retail count should increase
    let count = registry_service::get_eu_retail_investor_count(&registry, b"DEU".to_string());
    assert!(count.is_some() && *count.borrow() == 1, 1);

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_adjust_investors_counts_eu_qualified_investor() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    // Set DEU as EU compliance region
    test_helpers::set_country_compliance(&mut ts, b"DEU", COMPLIANCE_EU);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    // Register investor
    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    // Set investor as qualified
    registry_service::set_attribute<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        QUALIFIED,
        APPROVED,
        9999999999,
        &version,
        ts.ctx(),
    );

    // Initial EU retail count
    let count = registry_service::get_eu_retail_investor_count(&registry, b"DEU".to_string());
    assert!(count.is_some() && *count.borrow() == 0, 0);

    // Adjust counts (increase)
    registry_service::adjust_investors_counts_by_country(
        &mut registry,
        b"INV001".to_string(),
        b"DEU".to_string(),
        true,
    );

    // EU retail count should NOT increase (investor is qualified, not retail)
    let count = registry_service::get_eu_retail_investor_count(&registry, b"DEU".to_string());
    assert!(count.is_some() && *count.borrow() == 0, 1);

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_adjust_investors_counts_jp_investor() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    // Set JPN as JP compliance region
    test_helpers::set_country_compliance(&mut ts, b"JPN", COMPLIANCE_JP);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    // Register investor
    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    // Initial JP count
    assert!(registry_service::get_jp_investor_count(&registry) == 0, 0);

    // Adjust counts (increase)
    registry_service::adjust_investors_counts_by_country(
        &mut registry,
        b"INV001".to_string(),
        b"JPN".to_string(),
        true,
    );

    // JP count should increase
    assert!(registry_service::get_jp_investor_count(&registry) == 1, 1);

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_adjust_investors_counts_decrease() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    // Set USA as US compliance region
    test_helpers::set_country_compliance(&mut ts, b"USA", COMPLIANCE_US);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    // Register investor
    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    // First increase
    registry_service::adjust_investors_counts_by_country(
        &mut registry,
        b"INV001".to_string(),
        b"USA".to_string(),
        true,
    );

    assert!(registry_service::get_us_investor_count(&registry) == 1, 0);

    // Then decrease
    registry_service::adjust_investors_counts_by_country(
        &mut registry,
        b"INV001".to_string(),
        b"USA".to_string(),
        false,
    );

    assert!(registry_service::get_us_investor_count(&registry) == 0, 1);

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

// ==================== Group 22: adjust_investor_counts_after_country_change ====================

#[test]
fun test_adjust_investor_counts_after_country_change_with_balance() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);
    test_helpers::init_namespace_for_testing(&mut ts);

    // Set USA and JPN compliance regions
    test_helpers::set_country_compliance(&mut ts, b"USA", COMPLIANCE_US);
    test_helpers::set_country_compliance(&mut ts, b"JPN", COMPLIANCE_JP);

    // Register investor with wallet (creates PAS account)
    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let mut namespace = ts.take_shared<Namespace>();

    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    registry_service::add_wallet<TEST_VOLORO>(
        &mut registry,
        &auth,
        &mut namespace,
        b"INV001".to_string(),
        WALLET1,
        &version,
        ts.ctx(),
    );

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts::return_shared(namespace);

    // Issue tokens to give the investor a non-zero balance
    ts.next_tx(ADMIN);
    let mut treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let account = ts.take_shared<Account>();
    let clock = clock::create_for_testing(ts.ctx());

    ds_token::issue_tokens(
        &mut treasury,
        &auth,
        &mut investor_info,
        &mut compliance,
        &account,
        WALLET1,
        1000,
        0,
        b"".to_string(),
        &version,
        vector[],
        vector[],
        clock.timestamp_ms(),
        &clock,
        ts.ctx(),
    );

    clock.destroy_for_testing();
    ts::return_shared(treasury);
    ts::return_shared(auth);
    ts::return_shared(investor_info);
    ts::return_shared(compliance);
    ts::return_shared(version);
    ts::return_shared(account);

    // Set initial country to USA and verify counts
    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    registry_service::set_country<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        b"USA".to_string(),
        &version,
        ts.ctx(),
    );

    assert!(registry_service::get_us_investor_count(&registry) == 1, 0);
    assert!(registry_service::get_jp_investor_count(&registry) == 0, 1);

    // Change country to JPN (triggers adjust_investor_counts_after_country_change)
    registry_service::set_country<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        b"JPN".to_string(),
        &version,
        ts.ctx(),
    );

    assert!(registry_service::get_us_investor_count(&registry) == 0, 2);
    assert!(registry_service::get_jp_investor_count(&registry) == 1, 3);

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_adjust_investor_counts_after_country_change_no_balance() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    // Set USA and JPN compliance regions
    test_helpers::set_country_compliance(&mut ts, b"USA", COMPLIANCE_US);
    test_helpers::set_country_compliance(&mut ts, b"JPN", COMPLIANCE_JP);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    // Register investor (no wallet, balance = 0)
    registry_service::register_investor<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        &version,
        ts.ctx(),
    );

    // Set initial country to USA
    registry_service::set_country<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        b"USA".to_string(),
        &version,
        ts.ctx(),
    );

    // Since balance is 0, counts should NOT be adjusted
    assert!(registry_service::get_us_investor_count(&registry) == 0, 0);

    // Change country to JPN
    registry_service::set_country<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        b"JPN".to_string(),
        &version,
        ts.ctx(),
    );

    // Counts should still be 0 since balance is 0
    assert!(registry_service::get_us_investor_count(&registry) == 0, 1);
    assert!(registry_service::get_jp_investor_count(&registry) == 0, 2);

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}
