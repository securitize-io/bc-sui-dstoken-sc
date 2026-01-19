#[test_only]
module securitize::compliance_service_tests;

use securitize::{
    accredited_only::{Self, AccreditedOnly},
    compliance_service::{Self, ComplianceConfig},
    registry_service::{InvestorInfo},
    test_helpers::{TEST_VOLORO},
    trust_service::{Auth},
    version::{Version}
};
use sui::{test_scenario::{Self as ts, Scenario}};
use securitize::test_helpers::setup_with_treasury;

const ADMIN: address = @0x001;
const UNAUTHORIZED: address = @0x002;


fun setup_for_testing(ts: &mut Scenario) {
    ts.next_tx(ADMIN);
    setup_with_treasury(ts);
}

#[test]
fun test_compliance_config_initialization() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();

    // Initially, no rules should be registered
    assert!(!compliance_service::has_rule<TEST_VOLORO, AccreditedOnly>(&compliance), 0);

    ts::return_shared(compliance);
    ts.end();
}

#[test]
fun test_register_rule() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    // Create and register a rule
    let rule = accredited_only::new<TEST_VOLORO>(
        &auth,
        true,
        false,
        &version,
        ts.ctx(),
    );

    compliance_service::register_rule<TEST_VOLORO, AccreditedOnly>(
        &mut compliance,
        &auth,
        rule,
        &version,
        ts.ctx(),
    );

    assert!(compliance_service::has_rule<TEST_VOLORO, AccreditedOnly>(&compliance), 0);

    ts::return_shared(compliance);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = compliance_service::ENotAuthorized)]
fun test_register_rule_unauthorized() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    // Create a rule (admin can do this)
    let rule = accredited_only::new<TEST_VOLORO>(
        &auth,
        true,
        false,
        &version,
        ts.ctx(),
    );
    ts::return_shared(auth);
    ts::return_shared(version);

    // Try to register as unauthorized user
    ts.next_tx(UNAUTHORIZED);
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    compliance_service::register_rule<TEST_VOLORO, AccreditedOnly>(
        &mut compliance,
        &auth,
        rule,
        &version,
        ts.ctx(),
    );

    ts::return_shared(compliance);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = compliance_service::ERuleAlreadyExists)]
fun test_register_rule_already_exists() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    // Register first rule
    let rule1 = accredited_only::new<TEST_VOLORO>(
        &auth,
        true,
        false,
        &version,
        ts.ctx(),
    );

    compliance_service::register_rule<TEST_VOLORO, AccreditedOnly>(
        &mut compliance,
        &auth,
        rule1,
        &version,
        ts.ctx(),
    );

    // Try to register same rule type again
    let rule2 = accredited_only::new<TEST_VOLORO>(
        &auth,
        false,
        true,
        &version,
        ts.ctx(),
    );

    compliance_service::register_rule<TEST_VOLORO, AccreditedOnly>(
        &mut compliance,
        &auth,
        rule2,
        &version,
        ts.ctx(),
    );

    ts::return_shared(compliance);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_unregister_rule() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    // Register a rule
    let rule = accredited_only::new<TEST_VOLORO>(
        &auth,
        true,
        false,
        &version,
        ts.ctx(),
    );

    compliance_service::register_rule<TEST_VOLORO, AccreditedOnly>(
        &mut compliance,
        &auth,
        rule,
        &version,
        ts.ctx(),
    );

    assert!(compliance_service::has_rule<TEST_VOLORO, AccreditedOnly>(&compliance), 0);

    // Unregister the rule
    compliance_service::unregister_rule<TEST_VOLORO, AccreditedOnly>(
        &mut compliance,
        &auth,
        &version,
        ts.ctx(),
    );

    assert!(!compliance_service::has_rule<TEST_VOLORO, AccreditedOnly>(&compliance), 1);

    ts::return_shared(compliance);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = compliance_service::ERuleNotFound)]
fun test_unregister_rule_not_found() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    // Try to unregister a rule that doesn't exist
    compliance_service::unregister_rule<TEST_VOLORO, AccreditedOnly>(
        &mut compliance,
        &auth,
        &version,
        ts.ctx(),
    );

    ts::return_shared(compliance);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_set_country_compliance() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    // Set country compliance for "US" to region 1
    compliance_service::set_country_compliance<TEST_VOLORO>(
        &mut registry,
        b"USA".to_string(),
        1,
        &auth,
        &version,
        ts.ctx(),
    );

    // Verify
    let region = compliance_service::get_country_compliance<TEST_VOLORO>(&registry, b"USA".to_string());
    assert!(region == 1, 0);

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = compliance_service::ENotAuthorized)]
fun test_set_country_compliance_unauthorized() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(UNAUTHORIZED);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    // Should fail - UNAUTHORIZED has no SetCountryCompliance ability
    compliance_service::set_country_compliance<TEST_VOLORO>(
        &mut registry,
        b"USA".to_string(),
        1,
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
fun test_get_rule_and_modify() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    // Register a rule
    let rule = accredited_only::new<TEST_VOLORO>(
        &auth,
        false, // initial: not forcing accreditation
        false,
        &version,
        ts.ctx(),
    );

    compliance_service::register_rule<TEST_VOLORO, AccreditedOnly>(
        &mut compliance,
        &auth,
        rule,
        &version,
        ts.ctx(),
    );

    // Get rule wrapper (hot potato) and modify
    let mut wrapper = compliance_service::get_rule<TEST_VOLORO, AccreditedOnly>(
        &mut compliance,
        &auth,
        &version,
        ts.ctx(),
    );

    accredited_only::set_force_accredited<TEST_VOLORO>(
        &auth,
        &mut wrapper,
        true,
        &version,
        ts.ctx(),
    );

    // Return the rule back to compliance config
    compliance_service::return_rule<TEST_VOLORO, AccreditedOnly>(
        &mut compliance,
        &auth,
        wrapper,
        &version,
        ts.ctx(),
    );

    ts::return_shared(compliance);
    ts::return_shared(auth);
    ts::return_shared(version);

    ts.next_tx(ADMIN);

    // Verify the change persisted using borrow_rule
    let compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();

    let rule = compliance_service::borrow_rule<TEST_VOLORO, AccreditedOnly>(&compliance);
    assert!(accredited_only::is_force_accredited(rule), 0);

    ts::return_shared(compliance);
    ts.end();
}

#[test]
fun test_has_rule() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    assert!(!compliance_service::has_rule<TEST_VOLORO, AccreditedOnly>(&compliance), 0);

    let rule = accredited_only::new<TEST_VOLORO>(
        &auth,
        true,
        false,
        &version,
        ts.ctx(),
    );

    compliance_service::register_rule<TEST_VOLORO, AccreditedOnly>(
        &mut compliance,
        &auth,
        rule,
        &version,
        ts.ctx(),
    );

    assert!(compliance_service::has_rule<TEST_VOLORO, AccreditedOnly>(&compliance), 1);

    ts::return_shared(compliance);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}