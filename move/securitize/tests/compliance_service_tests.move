#[test_only]
module securitize::compliance_service_tests;

use pas::{chest::{Self, Chest}, policy::Policy, transfer_funds};
use securitize::{
    accredited_only::{Self, AccreditedOnly},
    authorized_securities::{Self, AuthorizedSecurities},
    backdating_issuance::{Self, BackdatingIssuance},
    compliance_service::{Self, ComplianceConfig},
    ds_token::{Self, Treasury},
    flowback_restriction::{Self, FlowbackRestriction},
    force_full_transfer::{Self, ForceFullTransfer},
    holding_limits::{Self, HoldingLimits},
    investor_limits::{Self, InvestorLimits},
    lock_manager,
    lockup_restriction::{Self, LockupRestriction},
    registry_service::{Self, InvestorInfo},
    test_helpers::{Self, TEST_VOLORO, setup_with_treasury},
    trust_service::Auth,
    version::Version
};
use sui::{clock, test_scenario::{Self as ts, Scenario}};

const ADMIN: address = @0x001;
const UNAUTHORIZED: address = @0x002;
const INVESTOR1: address = @0x101;
const INVESTOR2: address = @0x102;
const INVESTOR1_WALLET2: address = @0x103;
const ISSUER_WALLET: address = @0x201;

fun setup_for_testing(ts: &mut Scenario) {
    ts.next_tx(ADMIN);
    setup_with_treasury(ts);
}

// ==================== ComplianceConfig Management ====================

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

/// unregister_rule with unauthorized caller → ENotAuthorized
#[test]
#[expected_failure(abort_code = compliance_service::ENotAuthorized)]
fun test_unregister_rule_unauthorized() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    // Register a rule as admin
    ts.next_tx(ADMIN);
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let rule = accredited_only::new<TEST_VOLORO>(&auth, true, false, &version, ts.ctx());
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

    // Try to unregister as unauthorized
    ts.next_tx(UNAUTHORIZED);
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

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
    let region = compliance_service::get_country_compliance<TEST_VOLORO>(
        &registry,
        b"USA".to_string(),
    );
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

/// get_rule with unauthorized caller → ENotAuthorized
#[test]
#[expected_failure(abort_code = compliance_service::ENotAuthorized)]
fun test_get_rule_unauthorized() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    // Register a rule as admin
    ts.next_tx(ADMIN);
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let rule = accredited_only::new<TEST_VOLORO>(&auth, true, false, &version, ts.ctx());
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

    // Try to get_rule as unauthorized
    ts.next_tx(UNAUTHORIZED);
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let wrapper = compliance_service::get_rule<TEST_VOLORO, AccreditedOnly>(
        &mut compliance,
        &auth,
        &version,
        ts.ctx(),
    );
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
    ts.end();
}

/// return_rule with unauthorized caller → ENotAuthorized
#[test]
#[expected_failure(abort_code = compliance_service::ENotAuthorized)]
fun test_return_rule_unauthorized() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    // Register a rule as admin
    ts.next_tx(ADMIN);
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let rule = accredited_only::new<TEST_VOLORO>(&auth, true, false, &version, ts.ctx());
    compliance_service::register_rule<TEST_VOLORO, AccreditedOnly>(
        &mut compliance,
        &auth,
        rule,
        &version,
        ts.ctx(),
    );

    // Get rule as admin (succeeds)
    let wrapper = compliance_service::get_rule<TEST_VOLORO, AccreditedOnly>(
        &mut compliance,
        &auth,
        &version,
        ts.ctx(),
    );

    ts::return_shared(compliance);
    ts::return_shared(auth);
    ts::return_shared(version);

    // Try to return_rule as unauthorized
    ts.next_tx(UNAUTHORIZED);
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

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

/// Helper: setup investor with country and compliance region
fun setup_investor(
    ts: &mut Scenario,
    investor_id: vector<u8>,
    wallet: address,
    country: vector<u8>,
) {
    test_helpers::register_investor_with_wallet(ts, investor_id, wallet);
    test_helpers::set_investor_country(ts, investor_id, country);
}

// ==================== validate_issue Tests ====================

/// 1. Happy path: issue to a registered investor with no rules registered
#[test]
fun test_validate_issue_basic() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);
    setup_investor(&mut ts, b"INV001", INVESTOR1, b"US");

    ts.next_tx(ADMIN);
    let compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    compliance_service::validate_issue<TEST_VOLORO>(
        &compliance,
        &mut registry,
        INVESTOR1,
        500, // amount
        0, // total_supply
        1000, // issuance_time_ms
        1000, // current_time_ms
        &version,
    );

    ts::return_shared(compliance);
    ts::return_shared(registry);
    ts::return_shared(version);
    ts.end();
}

/// 2. Issue to an address that is not a registered wallet -> ENotWhitelisted
#[test]
#[expected_failure(abort_code = compliance_service::ENotWhitelisted)]
fun test_validate_issue_not_whitelisted() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    // Do NOT register any investor — INVESTOR1 is unknown
    ts.next_tx(ADMIN);
    let compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    compliance_service::validate_issue<TEST_VOLORO>(
        &compliance,
        &mut registry,
        INVESTOR1,
        500,
        0,
        1000,
        1000,
        &version,
    );

    ts::return_shared(compliance);
    ts::return_shared(registry);
    ts::return_shared(version);
    ts.end();
}

/// 3. Issue to investor whose country is in FORBIDDEN region -> EDestinationRestricted
#[test]
#[expected_failure(abort_code = compliance_service::EDestinationRestricted)]
fun test_validate_issue_forbidden_region() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);
    setup_investor(&mut ts, b"INV001", INVESTOR1, b"NK");

    // Set NK country to FORBIDDEN region (4)
    test_helpers::set_country_compliance(&mut ts, b"NK", 4);

    ts.next_tx(ADMIN);
    let compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    compliance_service::validate_issue<TEST_VOLORO>(
        &compliance,
        &mut registry,
        INVESTOR1,
        500,
        0,
        1000,
        1000,
        &version,
    );

    ts::return_shared(compliance);
    ts::return_shared(registry);
    ts::return_shared(version);
    ts.end();
}

/// 4. Issue to special wallet with AuthorizedSecurities: passes within limit, then aborts when exceeding max
#[test]
#[expected_failure(abort_code = authorized_securities::EMaxAuthorizedSecuritiesExceeded)]
fun test_validate_issue_to_special_wallet_authorized_securities() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);
    test_helpers::add_issuer_wallet(&mut ts, ISSUER_WALLET);

    // Register AuthorizedSecurities rule with max_supply = 1000
    ts.next_tx(ADMIN);
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let rule = authorized_securities::new<TEST_VOLORO>(
        &auth,
        1000, // max_supply
        &version,
        ts.ctx(),
    );
    compliance_service::register_rule<TEST_VOLORO, AuthorizedSecurities>(
        &mut compliance,
        &auth,
        rule,
        &version,
        ts.ctx(),
    );

    ts::return_shared(compliance);
    ts::return_shared(auth);
    ts::return_shared(version);

    // First: issue to special wallet within limit — should succeed
    ts.next_tx(ADMIN);
    let compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    compliance_service::validate_issue<TEST_VOLORO>(
        &compliance,
        &mut registry,
        ISSUER_WALLET,
        500, // amount
        400, // total_supply (400 + 500 = 900 <= 1000)
        1000,
        1000,
        &version,
    );

    ts::return_shared(compliance);
    ts::return_shared(registry);
    ts::return_shared(version);

    // Then: issue to special wallet exceeding limit — should abort
    ts.next_tx(ADMIN);
    let compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    compliance_service::validate_issue<TEST_VOLORO>(
        &compliance,
        &mut registry,
        ISSUER_WALLET,
        600, // amount
        500, // total_supply (500 + 600 = 1100 > 1000)
        1000,
        1000,
        &version,
    );

    ts::return_shared(compliance);
    ts::return_shared(registry);
    ts::return_shared(version);
    ts.end();
}

/// 5. Issue to an investor in liquidate-only mode -> EInvestorLiquidateOnly
#[test]
#[expected_failure(abort_code = compliance_service::EInvestorLiquidateOnly)]
fun test_validate_issue_liquidate_only() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);
    setup_investor(&mut ts, b"INV001", INVESTOR1, b"US");

    // Set investor to liquidate-only mode
    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    lock_manager::set_liquidate_only<TEST_VOLORO>(
        &mut registry,
        b"INV001".to_string(),
        true,
        &auth,
        &version,
        ts.ctx(),
    );

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);

    // Now try to issue to them
    ts.next_tx(ADMIN);
    let compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    compliance_service::validate_issue<TEST_VOLORO>(
        &compliance,
        &mut registry,
        INVESTOR1,
        500,
        0,
        1000,
        1000,
        &version,
    );

    ts::return_shared(compliance);
    ts::return_shared(registry);
    ts::return_shared(version);
    ts.end();
}

/// 6. Issue to new investor increments count; second issuance to same investor does not.
#[test]
fun test_validate_issue_investor_count_tracking() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);
    setup_investor(&mut ts, b"INV001", INVESTOR1, b"US");

    // Check count before issuance
    ts.next_tx(ADMIN);
    let registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    assert!(registry_service::get_total_investors_count(&registry) == 0, 0);
    ts::return_shared(registry);

    // First issuance — investor is new (balance == 0), count should go from 0 to 1
    issue_to_investor(&mut ts, INVESTOR1, 500);

    ts.next_tx(ADMIN);
    let registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    assert!(registry_service::get_total_investors_count(&registry) == 1, 1);
    ts::return_shared(registry);

    // Second issuance — investor already has balance of 500, count should stay at 1
    issue_to_investor(&mut ts, INVESTOR1, 200);

    ts.next_tx(ADMIN);
    let registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    assert!(registry_service::get_total_investors_count(&registry) == 1, 2);
    ts::return_shared(registry);
    ts.end();
}

/// 7. AccreditedOnly rule: issue to accredited investor passes, then issue to non-accredited aborts
#[test]
#[expected_failure(abort_code = accredited_only::ENotAccredited)]
fun test_validate_issue_with_accredited_only_rule() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    // Register two investors
    setup_investor(&mut ts, b"INV001", INVESTOR1, b"US"); // will be accredited
    setup_investor(&mut ts, b"INV002", INVESTOR2, b"US"); // will NOT be accredited

    // Set INV001 as accredited (attribute_id=2 ACCREDITED, value=1 APPROVED, expiration=0)
    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    registry_service::set_attribute<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        2, // ACCREDITED
        1, // APPROVED
        0, // no expiration
        &version,
        ts.ctx(),
    );

    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);

    // Register AccreditedOnly rule with force_accredited = true
    ts.next_tx(ADMIN);
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let rule = accredited_only::new<TEST_VOLORO>(
        &auth,
        true, // force_accredited globally
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

    ts::return_shared(compliance);
    ts::return_shared(auth);
    ts::return_shared(version);

    // Issue to accredited investor (INV001) — should pass
    ts.next_tx(ADMIN);
    let compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    compliance_service::validate_issue<TEST_VOLORO>(
        &compliance,
        &mut registry,
        INVESTOR1,
        500,
        0,
        1000,
        1000,
        &version,
    );

    ts::return_shared(compliance);
    ts::return_shared(registry);
    ts::return_shared(version);

    // Issue to non-accredited investor (INV002) — should abort
    ts.next_tx(ADMIN);
    let compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    compliance_service::validate_issue<TEST_VOLORO>(
        &compliance,
        &mut registry,
        INVESTOR2,
        500,
        500,
        1000,
        1000,
        &version,
    );

    ts::return_shared(compliance);
    ts::return_shared(registry);
    ts::return_shared(version);
    ts.end();
}

/// 8. AuthorizedSecurities rule, issuance exceeds max_supply -> abort
#[test]
#[expected_failure(abort_code = authorized_securities::EMaxAuthorizedSecuritiesExceeded)]
fun test_validate_issue_with_authorized_securities_exceeds_max() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);
    setup_investor(&mut ts, b"INV001", INVESTOR1, b"US");

    // Register AuthorizedSecurities rule with max_supply = 1000
    ts.next_tx(ADMIN);
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let rule = authorized_securities::new<TEST_VOLORO>(
        &auth,
        1000,
        &version,
        ts.ctx(),
    );
    compliance_service::register_rule<TEST_VOLORO, AuthorizedSecurities>(
        &mut compliance,
        &auth,
        rule,
        &version,
        ts.ctx(),
    );

    ts::return_shared(compliance);
    ts::return_shared(auth);
    ts::return_shared(version);

    // Issue with total_supply + amount > max_supply
    ts.next_tx(ADMIN);
    let compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    compliance_service::validate_issue<TEST_VOLORO>(
        &compliance,
        &mut registry,
        INVESTOR1,
        600, // amount
        500, // total_supply (500 + 600 = 1100 > 1000)
        1000,
        1000,
        &version,
    );

    ts::return_shared(compliance);
    ts::return_shared(registry);
    ts::return_shared(version);
    ts.end();
}

/// 9. AuthorizedSecurities rule, issuance within max_supply -> success
#[test]
fun test_validate_issue_with_authorized_securities_passes() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);
    setup_investor(&mut ts, b"INV001", INVESTOR1, b"US");

    // Register AuthorizedSecurities rule with max_supply = 1000
    ts.next_tx(ADMIN);
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let rule = authorized_securities::new<TEST_VOLORO>(
        &auth,
        1000,
        &version,
        ts.ctx(),
    );
    compliance_service::register_rule<TEST_VOLORO, AuthorizedSecurities>(
        &mut compliance,
        &auth,
        rule,
        &version,
        ts.ctx(),
    );

    ts::return_shared(compliance);
    ts::return_shared(auth);
    ts::return_shared(version);

    // Issue within limit
    ts.next_tx(ADMIN);
    let compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    compliance_service::validate_issue<TEST_VOLORO>(
        &compliance,
        &mut registry,
        INVESTOR1,
        400, // amount
        500, // total_supply (500 + 400 = 900 <= 1000)
        1000,
        1000,
        &version,
    );

    ts::return_shared(compliance);
    ts::return_shared(registry);
    ts::return_shared(version);
    ts.end();
}

/// HoldingLimits: issuance exceeds max holding → EAboveMaxHolding
#[test]
#[expected_failure(abort_code = holding_limits::EAboveMaxHolding)]
fun test_validate_issue_with_holding_limits_above_max() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    // Register HoldingLimits rule: max 300 per investor
    ts.next_tx(ADMIN);
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let rule = holding_limits::new<TEST_VOLORO>(
        &auth,
        0,
        300,
        vector[],
        vector[],
        &version,
        ts.ctx(),
    );
    compliance_service::register_rule<TEST_VOLORO, HoldingLimits>(
        &mut compliance,
        &auth,
        rule,
        &version,
        ts.ctx(),
    );
    ts::return_shared(compliance);
    ts::return_shared(auth);
    ts::return_shared(version);

    setup_investor(&mut ts, b"INV001", INVESTOR1, b"US");

    // Issue 500 > max 300 → should abort
    ts.next_tx(ADMIN);
    let compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    compliance_service::validate_issue<TEST_VOLORO>(
        &compliance,
        &mut registry,
        INVESTOR1,
        500,
        0,
        1000,
        1000,
        &version,
    );

    ts::return_shared(compliance);
    ts::return_shared(registry);
    ts::return_shared(version);
    ts.end();
}

/// HoldingLimits: issuance within limits → success
#[test]
fun test_validate_issue_with_holding_limits_passes() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    // Register HoldingLimits rule: min 100, max 1000
    ts.next_tx(ADMIN);
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let rule = holding_limits::new<TEST_VOLORO>(
        &auth,
        100,
        1000,
        vector[],
        vector[],
        &version,
        ts.ctx(),
    );
    compliance_service::register_rule<TEST_VOLORO, HoldingLimits>(
        &mut compliance,
        &auth,
        rule,
        &version,
        ts.ctx(),
    );
    ts::return_shared(compliance);
    ts::return_shared(auth);
    ts::return_shared(version);

    setup_investor(&mut ts, b"INV001", INVESTOR1, b"US");

    // Issue 500 (within 100..1000) → should pass
    ts.next_tx(ADMIN);
    let compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    compliance_service::validate_issue<TEST_VOLORO>(
        &compliance,
        &mut registry,
        INVESTOR1,
        500,
        0,
        1000,
        1000,
        &version,
    );

    ts::return_shared(compliance);
    ts::return_shared(registry);
    ts::return_shared(version);
    ts.end();
}

/// InvestorLimits: issuance to new investor exceeds total limit → EMaxInvestorsExceeded
#[test]
#[expected_failure(abort_code = investor_limits::EMaxInvestorsExceeded)]
fun test_validate_issue_with_investor_limits_max_total() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    // Register InvestorLimits: max 1 total investor
    ts.next_tx(ADMIN);
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let rule = investor_limits::new<TEST_VOLORO>(
        &auth,
        1, // total_investors_limit = 1
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        &version,
        ts.ctx(),
    );
    compliance_service::register_rule<TEST_VOLORO, InvestorLimits>(
        &mut compliance,
        &auth,
        rule,
        &version,
        ts.ctx(),
    );
    ts::return_shared(compliance);
    ts::return_shared(auth);
    ts::return_shared(version);

    // Register and issue to INVESTOR1 (1 chest only at this point)
    setup_investor(&mut ts, b"INV001", INVESTOR1, b"US");
    issue_to_investor(&mut ts, INVESTOR1, 500);

    // Register INVESTOR2
    setup_investor(&mut ts, b"INV002", INVESTOR2, b"FR");

    // Second issuance to INVESTOR2 → count would go to 2 > limit=1
    ts.next_tx(ADMIN);
    let compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    compliance_service::validate_issue<TEST_VOLORO>(
        &compliance,
        &mut registry,
        INVESTOR2,
        300,
        500,
        1000,
        1000,
        &version,
    );

    ts::return_shared(compliance);
    ts::return_shared(registry);
    ts::return_shared(version);
    ts.end();
}

/// AuthorizedSecurities: issuance to special wallet exceeding max supply → EMaxAuthorizedSecuritiesExceeded
#[test]
#[expected_failure(abort_code = authorized_securities::EMaxAuthorizedSecuritiesExceeded)]
fun test_issue_to_special_wallet_with_authorized_securities_exceeded() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    // Register AuthorizedSecurities rule: max supply = 500
    ts.next_tx(ADMIN);
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let rule = authorized_securities::new<TEST_VOLORO>(
        &auth,
        500,
        &version,
        ts.ctx(),
    );
    compliance_service::register_rule<TEST_VOLORO, AuthorizedSecurities>(
        &mut compliance,
        &auth,
        rule,
        &version,
        ts.ctx(),
    );
    ts::return_shared(compliance);
    ts::return_shared(auth);
    ts::return_shared(version);

    // Add issuer wallet (special wallet)
    test_helpers::add_issuer_wallet(&mut ts, ISSUER_WALLET);

    // Issue 600 to special wallet → total_supply(0) + 600 > max(500) → abort
    ts.next_tx(ADMIN);
    let mut treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let chest = ts.take_shared<Chest>();
    let clock = clock::create_for_testing(ts.ctx());

    ds_token::issue_tokens(
        &mut treasury,
        &auth,
        &mut investor_info,
        &mut compliance,
        &chest,
        ISSUER_WALLET,
        600,
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
    ts::return_shared(chest);
    ts.end();
}

/// Issuing 0 tokens aborts with EValueZero
#[test]
#[expected_failure(abort_code = ds_token::EValueZero)]
fun test_issue_zero_amount() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    setup_investor(&mut ts, b"INV001", INVESTOR1, b"US");

    ts.next_tx(ADMIN);
    let mut treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let chest = ts.take_shared<Chest>();
    let clock = clock::create_for_testing(ts.ctx());

    ds_token::issue_tokens(
        &mut treasury,
        &auth,
        &mut investor_info,
        &mut compliance,
        &chest,
        INVESTOR1,
        0,
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
    ts::return_shared(chest);
    ts.end();
}

/// Test record_investor_issuance: records issuances and verifies they are tracked
#[test]
fun test_record_investor_issuance() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);
    setup_investor(&mut ts, b"INV001", INVESTOR1, b"US");

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();

    // Record two issuances
    compliance_service::record_investor_issuance<TEST_VOLORO>(
        &mut registry,
        b"INV001".to_string(),
        500,
        1000,
    );
    compliance_service::record_investor_issuance<TEST_VOLORO>(
        &mut registry,
        b"INV001".to_string(),
        300,
        2000,
    );

    // Verify issuances are recorded
    let issuances = registry_service::get_investor_issuances<TEST_VOLORO>(
        &registry,
        b"INV001".to_string(),
    );
    assert!(issuances.length() == 2, 0);
    assert!(issuances[0].issuance_amount() == 500, 1);
    assert!(issuances[0].issuance_time_ms() == 1000, 2);
    assert!(issuances[1].issuance_amount() == 300, 3);
    assert!(issuances[1].issuance_time_ms() == 2000, 4);

    // Record zero-amount issuance → should be skipped
    compliance_service::record_investor_issuance<TEST_VOLORO>(
        &mut registry,
        b"INV001".to_string(),
        0,
        3000,
    );
    let issuances = registry_service::get_investor_issuances<TEST_VOLORO>(
        &registry,
        b"INV001".to_string(),
    );
    assert!(issuances.length() == 2, 5);

    ts::return_shared(registry);
    ts.end();
}

// ==================== validate_burn Tests ====================

/// 1. Partial burn keeps investor count; full burn (exit) decrements it
#[test]
fun test_validate_burn_lifecycle() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);
    setup_investor(&mut ts, b"INV001", INVESTOR1, b"US");

    // Issue 500 to investor — count goes from 0 to 1
    issue_to_investor(&mut ts, INVESTOR1, 500);

    ts.next_tx(ADMIN);
    let registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    assert!(registry_service::get_total_investors_count(&registry) == 1, 0);
    ts::return_shared(registry);

    // Partial burn: 200 out of 500 — not an exit, count stays 1
    burn_from_investor(&mut ts, 200);

    ts.next_tx(ADMIN);
    let registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    assert!(registry_service::get_total_investors_count(&registry) == 1, 1);
    ts::return_shared(registry);

    // Full burn: 300 out of 300 — exit investor, count decrements to 0
    burn_from_investor(&mut ts, 300);

    ts.next_tx(ADMIN);
    let registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    assert!(registry_service::get_total_investors_count(&registry) == 0, 2);
    ts::return_shared(registry);
    ts.end();
}

/// 2. Burn with zero amount is a no-op
#[test]
fun test_validate_burn_zero_amount() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);
    setup_investor(&mut ts, b"INV001", INVESTOR1, b"US");

    // Issue 500 to investor
    issue_to_investor(&mut ts, INVESTOR1, 500);

    // Burn zero — should be a no-op
    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();

    compliance_service::validate_burn<TEST_VOLORO>(
        &mut registry,
        INVESTOR1,
        0,
    );

    // Count should still be 1
    let count = registry_service::get_total_investors_count(&registry);
    assert!(count == 1, 0);

    ts::return_shared(registry);
    ts.end();
}

// ==================== validate_seize Tests ====================

/// 1. Partial seize keeps investor count; full seize (exit) decrements it.
///    Seize must target an issuer wallet.
#[test]
fun test_validate_seize_lifecycle() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);
    setup_investor(&mut ts, b"INV001", INVESTOR1, b"US");
    ts.next_tx(ADMIN);
    let inv1_chest_id = ts::most_recent_id_shared<Chest>().destroy_some();

    // Issue 500 to investor (only 1 chest in shared state)
    issue_to_investor(&mut ts, INVESTOR1, 500);

    // Add issuer wallet (creates 2nd chest)
    test_helpers::add_issuer_wallet(&mut ts, ISSUER_WALLET);
    ts.next_tx(ADMIN);
    let issuer_chest_id = ts::most_recent_id_shared<Chest>().destroy_some();

    ts.next_tx(ADMIN);
    let registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    assert!(registry_service::get_total_investors_count(&registry) == 1, 0);
    ts::return_shared(registry);

    // Partial seize: 200 out of 500 — not an exit, count stays 1
    seize_from_to(&mut ts, inv1_chest_id, ISSUER_WALLET, issuer_chest_id, 200);

    ts.next_tx(ADMIN);
    let registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    assert!(registry_service::get_total_investors_count(&registry) == 1, 1);
    ts::return_shared(registry);

    // Full seize: 300 out of 300 — exit investor, count decrements to 0
    seize_from_to(&mut ts, inv1_chest_id, ISSUER_WALLET, issuer_chest_id, 300);

    ts.next_tx(ADMIN);
    let registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    assert!(registry_service::get_total_investors_count(&registry) == 0, 2);
    ts::return_shared(registry);
    ts.end();
}

/// 2. Seize to a non-issuer wallet aborts with ENotIssuerWallet
#[test]
#[expected_failure(abort_code = compliance_service::ENotIssuerWallet)]
fun test_validate_seize_not_issuer_wallet() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);
    setup_investor(&mut ts, b"INV001", INVESTOR1, b"US");

    // Issue tokens while only 1 chest exists
    issue_to_investor(&mut ts, INVESTOR1, 500);

    setup_investor(&mut ts, b"INV002", INVESTOR2, b"US");

    // Seize to INVESTOR2 (a regular investor wallet, not an issuer wallet) — should abort
    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();

    compliance_service::validate_seize<TEST_VOLORO>(
        &mut registry,
        INVESTOR1,
        INVESTOR2,
        200,
    );

    ts::return_shared(registry);
    ts.end();
}

// ==================== Transfer Validation Tests ====================

/// Helper: issue tokens to an investor. Must be called when only that
/// investor's chest exists (i.e., before registering other investors).
fun issue_to_investor(ts: &mut Scenario, wallet: address, amount: u64) {
    ts.next_tx(ADMIN);
    let mut treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let chest = ts.take_shared<Chest>();
    let clock = clock::create_for_testing(ts.ctx());

    ds_token::issue_tokens(
        &mut treasury,
        &auth,
        &mut investor_info,
        &mut compliance,
        &chest,
        wallet,
        amount,
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
    ts::return_shared(chest);
}

/// Helper: burn tokens from an investor's chest. Must be called when only that
/// investor's chest exists (i.e., the only Chest in shared state).
fun burn_from_investor(ts: &mut Scenario, amount: u64) {
    ts.next_tx(ADMIN);
    let mut treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let policy = ts.take_shared<Policy<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let mut chest = ts.take_shared<Chest>();

    let request = chest.clawback_funds<TEST_VOLORO>(amount, ts.ctx());
    ds_token::burn(
        &mut treasury,
        &auth,
        &mut investor_info,
        &policy,
        request,
        b"".to_string(),
        &version,
        ts.ctx(),
    );

    ts::return_shared(treasury);
    ts::return_shared(auth);
    ts::return_shared(investor_info);
    ts::return_shared(policy);
    ts::return_shared(version);
    ts::return_shared(chest);
}

/// Helper: seize tokens from one chest to another using chest IDs.
fun seize_from_to(
    ts: &mut Scenario,
    from_chest_id: ID,
    to_wallet: address,
    to_chest_id: ID,
    amount: u64,
) {
    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let policy = ts.take_shared<Policy<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let mut from_chest = ts.take_shared_by_id<Chest>(from_chest_id);
    let to_chest = ts.take_shared_by_id<Chest>(to_chest_id);

    let request = from_chest.clawback_funds<TEST_VOLORO>(amount, ts.ctx());
    ds_token::seize(
        &auth,
        &mut investor_info,
        &policy,
        request,
        &to_chest,
        to_wallet,
        b"".to_string(),
        &version,
        ts.ctx(),
    );

    ts::return_shared(auth);
    ts::return_shared(investor_info);
    ts::return_shared(policy);
    ts::return_shared(version);
    ts::return_shared(from_chest);
    ts::return_shared(to_chest);
}

/// Happy path: transfer between two registered investors
#[test]
fun test_validate_transfer_basic() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    setup_investor(&mut ts, b"INV001", INVESTOR1, b"US");
    ts.next_tx(ADMIN);
    let inv1_chest_id = ts::most_recent_id_shared<Chest>().destroy_some();
    issue_to_investor(&mut ts, INVESTOR1, 500);
    setup_investor(&mut ts, b"INV002", INVESTOR2, b"FR");
    ts.next_tx(ADMIN);
    let inv2_chest_id = ts::most_recent_id_shared<Chest>().destroy_some();

    ts.next_tx(INVESTOR1);
    let treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let policy = ts.take_shared<Policy<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let clock = clock::create_for_testing(ts.ctx());

    let mut from_chest = ts.take_shared_by_id<Chest>(inv1_chest_id);
    let to_chest = ts.take_shared_by_id<Chest>(inv2_chest_id);

    let pas_auth = chest::new_auth(ts.ctx());
    let mut request = chest::transfer_funds<TEST_VOLORO>(
        &mut from_chest,
        &pas_auth,
        &to_chest,
        200,
        ts.ctx(),
    );

    ds_token::transfer(
        &treasury,
        &mut investor_info,
        &compliance,
        &mut request,
        &version,
        &clock,
    );

    transfer_funds::resolve(request, &policy);

    clock.destroy_for_testing();
    ts::return_shared(treasury);
    ts::return_shared(investor_info);
    ts::return_shared(compliance);
    ts::return_shared(policy);
    ts::return_shared(version);
    ts::return_shared(from_chest);
    ts::return_shared(to_chest);

    // Verify balances
    ts.next_tx(ADMIN);
    let investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    assert!(
        registry_service::investor_wallet_balance<TEST_VOLORO>(&investor_info, INVESTOR1) == 300,
        0,
    );
    assert!(
        registry_service::investor_wallet_balance<TEST_VOLORO>(&investor_info, INVESTOR2) == 200,
        1,
    );
    ts::return_shared(investor_info);

    ts.end();
}

/// Transfer to FORBIDDEN region → EDestinationRestricted
#[test]
#[expected_failure(abort_code = compliance_service::EDestinationRestricted)]
fun test_validate_transfer_to_forbidden_region() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    setup_investor(&mut ts, b"INV001", INVESTOR1, b"US");
    ts.next_tx(ADMIN);
    let inv1_chest_id = ts::most_recent_id_shared<Chest>().destroy_some();
    issue_to_investor(&mut ts, INVESTOR1, 500);

    // Register INVESTOR2 in a forbidden country
    setup_investor(&mut ts, b"INV002", INVESTOR2, b"NK");
    ts.next_tx(ADMIN);
    let inv2_chest_id = ts::most_recent_id_shared<Chest>().destroy_some();
    test_helpers::set_country_compliance(&mut ts, b"NK", 4); // FORBIDDEN = 4

    ts.next_tx(INVESTOR1);
    let treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let policy = ts.take_shared<Policy<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let clock = clock::create_for_testing(ts.ctx());

    let mut from_chest = ts.take_shared_by_id<Chest>(inv1_chest_id);
    let to_chest = ts.take_shared_by_id<Chest>(inv2_chest_id);

    let pas_auth = chest::new_auth(ts.ctx());
    let mut request = chest::transfer_funds<TEST_VOLORO>(
        &mut from_chest,
        &pas_auth,
        &to_chest,
        200,
        ts.ctx(),
    );

    ds_token::transfer(
        &treasury,
        &mut investor_info,
        &compliance,
        &mut request,
        &version,
        &clock,
    );

    transfer_funds::resolve(request, &policy);

    clock.destroy_for_testing();
    ts::return_shared(treasury);
    ts::return_shared(investor_info);
    ts::return_shared(compliance);
    ts::return_shared(policy);
    ts::return_shared(version);
    ts::return_shared(from_chest);
    ts::return_shared(to_chest);

    ts.end();
}

/// Transfer from fully locked sender → ETokensLocked
#[test]
#[expected_failure(abort_code = compliance_service::ETokensLocked)]
fun test_validate_transfer_sender_fully_locked() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    setup_investor(&mut ts, b"INV001", INVESTOR1, b"US");
    ts.next_tx(ADMIN);
    let inv1_chest_id = ts::most_recent_id_shared<Chest>().destroy_some();
    issue_to_investor(&mut ts, INVESTOR1, 500);

    // Fully lock INVESTOR1
    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    lock_manager::lock_investor<TEST_VOLORO>(
        &mut registry,
        b"INV001".to_string(),
        &auth,
        &version,
        ts.ctx(),
    );
    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);

    setup_investor(&mut ts, b"INV002", INVESTOR2, b"FR");
    ts.next_tx(ADMIN);
    let inv2_chest_id = ts::most_recent_id_shared<Chest>().destroy_some();

    ts.next_tx(INVESTOR1);
    let treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let policy = ts.take_shared<Policy<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let clock = clock::create_for_testing(ts.ctx());

    let mut from_chest = ts.take_shared_by_id<Chest>(inv1_chest_id);
    let to_chest = ts.take_shared_by_id<Chest>(inv2_chest_id);

    let pas_auth = chest::new_auth(ts.ctx());
    let mut request = chest::transfer_funds<TEST_VOLORO>(
        &mut from_chest,
        &pas_auth,
        &to_chest,
        200,
        ts.ctx(),
    );

    ds_token::transfer(
        &treasury,
        &mut investor_info,
        &compliance,
        &mut request,
        &version,
        &clock,
    );

    transfer_funds::resolve(request, &policy);

    clock.destroy_for_testing();
    ts::return_shared(treasury);
    ts::return_shared(investor_info);
    ts::return_shared(compliance);
    ts::return_shared(policy);
    ts::return_shared(version);
    ts::return_shared(from_chest);
    ts::return_shared(to_chest);

    ts.end();
}

/// Transfer to investor in liquidate-only mode → EInvestorLiquidateOnly
#[test]
#[expected_failure(abort_code = compliance_service::EInvestorLiquidateOnly)]
fun test_validate_transfer_to_liquidate_only() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    setup_investor(&mut ts, b"INV001", INVESTOR1, b"US");
    ts.next_tx(ADMIN);
    let inv1_chest_id = ts::most_recent_id_shared<Chest>().destroy_some();
    issue_to_investor(&mut ts, INVESTOR1, 500);

    setup_investor(&mut ts, b"INV002", INVESTOR2, b"FR");
    ts.next_tx(ADMIN);
    let inv2_chest_id = ts::most_recent_id_shared<Chest>().destroy_some();

    // Set INVESTOR2 to liquidate-only
    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    lock_manager::set_liquidate_only<TEST_VOLORO>(
        &mut registry,
        b"INV002".to_string(),
        true,
        &auth,
        &version,
        ts.ctx(),
    );
    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);

    ts.next_tx(INVESTOR1);
    let treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let policy = ts.take_shared<Policy<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let clock = clock::create_for_testing(ts.ctx());

    let mut from_chest = ts.take_shared_by_id<Chest>(inv1_chest_id);
    let to_chest = ts.take_shared_by_id<Chest>(inv2_chest_id);

    let pas_auth = chest::new_auth(ts.ctx());
    let mut request = chest::transfer_funds<TEST_VOLORO>(
        &mut from_chest,
        &pas_auth,
        &to_chest,
        200,
        ts.ctx(),
    );

    ds_token::transfer(
        &treasury,
        &mut investor_info,
        &compliance,
        &mut request,
        &version,
        &clock,
    );

    transfer_funds::resolve(request, &policy);

    clock.destroy_for_testing();
    ts::return_shared(treasury);
    ts::return_shared(investor_info);
    ts::return_shared(compliance);
    ts::return_shared(policy);
    ts::return_shared(version);
    ts::return_shared(from_chest);
    ts::return_shared(to_chest);

    ts.end();
}

/// Transfer to a non-whitelisted address → ENotWhitelisted
/// Register INVESTOR2 with wallet, then remove wallet so chest remains but wallet is unregistered.
#[test]
#[expected_failure(abort_code = compliance_service::ENotWhitelisted)]
fun test_validate_transfer_not_whitelisted() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    setup_investor(&mut ts, b"INV001", INVESTOR1, b"US");
    ts.next_tx(ADMIN);
    let inv1_chest_id = ts::most_recent_id_shared<Chest>().destroy_some();
    issue_to_investor(&mut ts, INVESTOR1, 500);

    // Register INVESTOR2 to create the chest, then remove wallet
    setup_investor(&mut ts, b"INV002", INVESTOR2, b"FR");
    ts.next_tx(ADMIN);
    let inv2_chest_id = ts::most_recent_id_shared<Chest>().destroy_some();

    // Remove INVESTOR2's wallet from registry (chest still exists as shared object)
    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    registry_service::remove_wallet<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV002".to_string(),
        INVESTOR2,
        &version,
        ts.ctx(),
    );
    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);

    // Transfer to INVESTOR2 whose wallet is no longer registered → ENotWhitelisted
    ts.next_tx(INVESTOR1);
    let treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let policy = ts.take_shared<Policy<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let clock = clock::create_for_testing(ts.ctx());

    let mut from_chest = ts.take_shared_by_id<Chest>(inv1_chest_id);
    let to_chest = ts.take_shared_by_id<Chest>(inv2_chest_id);

    let pas_auth = chest::new_auth(ts.ctx());
    let mut request = chest::transfer_funds<TEST_VOLORO>(
        &mut from_chest,
        &pas_auth,
        &to_chest,
        200,
        ts.ctx(),
    );

    ds_token::transfer(
        &treasury,
        &mut investor_info,
        &compliance,
        &mut request,
        &version,
        &clock,
    );

    transfer_funds::resolve(request, &policy);

    clock.destroy_for_testing();
    ts::return_shared(treasury);
    ts::return_shared(investor_info);
    ts::return_shared(compliance);
    ts::return_shared(policy);
    ts::return_shared(version);
    ts::return_shared(to_chest);
    ts::return_shared(from_chest);
    ts.end();
}

#[test]
#[expected_failure(abort_code = registry_service::EInvestorNotFound)]
fun test_validate_transfer_from_not_whitelisted() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    // Register INVESTOR1 and issue tokens
    setup_investor(&mut ts, b"INV001", INVESTOR1, b"US");
    ts.next_tx(ADMIN);
    let inv1_chest_id = ts::most_recent_id_shared<Chest>().destroy_some();
    issue_to_investor(&mut ts, INVESTOR1, 500);

    // Register INVESTOR2
    setup_investor(&mut ts, b"INV002", INVESTOR2, b"FR");
    ts.next_tx(ADMIN);
    let inv2_chest_id = ts::most_recent_id_shared<Chest>().destroy_some();

    // Zero out INVESTOR1's wallet balance in registry and remove wallet
    // The PAS chest still holds the tokens, but the registry no longer recognizes the wallet
    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    registry_service::update_wallet_balance<TEST_VOLORO>(&mut registry, INVESTOR1, 0);
    registry_service::remove_wallet<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        INVESTOR1,
        &version,
        ts.ctx(),
    );
    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);

    // INVESTOR1 tries to transfer — chest still has PAS tokens but wallet is unregistered
    ts.next_tx(INVESTOR1);
    let treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let policy = ts.take_shared<Policy<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let clock = clock::create_for_testing(ts.ctx());

    let mut from_chest = ts.take_shared_by_id<Chest>(inv1_chest_id);
    let to_chest = ts.take_shared_by_id<Chest>(inv2_chest_id);

    let pas_auth = chest::new_auth(ts.ctx());
    let mut request = chest::transfer_funds<TEST_VOLORO>(
        &mut from_chest,
        &pas_auth,
        &to_chest,
        100,
        ts.ctx(),
    );

    ds_token::transfer(
        &treasury,
        &mut investor_info,
        &compliance,
        &mut request,
        &version,
        &clock,
    );

    transfer_funds::resolve(request, &policy);

    clock.destroy_for_testing();
    ts::return_shared(treasury);
    ts::return_shared(investor_info);
    ts::return_shared(compliance);
    ts::return_shared(policy);
    ts::return_shared(version);
    ts::return_shared(from_chest);
    ts::return_shared(to_chest);
    ts.end();
}

/// Full transfer: exit investor decrements count, new investor increments count
#[test]
fun test_validate_transfer_investor_count_tracking() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    setup_investor(&mut ts, b"INV001", INVESTOR1, b"US");
    ts.next_tx(ADMIN);
    let inv1_chest_id = ts::most_recent_id_shared<Chest>().destroy_some();
    issue_to_investor(&mut ts, INVESTOR1, 500);
    setup_investor(&mut ts, b"INV002", INVESTOR2, b"FR");
    ts.next_tx(ADMIN);
    let inv2_chest_id = ts::most_recent_id_shared<Chest>().destroy_some();

    // Verify count before: 1 (only INVESTOR1 has tokens)
    ts.next_tx(ADMIN);
    let investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    assert!(registry_service::get_total_investors_count(&investor_info) == 1, 0);
    ts::return_shared(investor_info);

    // Transfer ALL tokens (INVESTOR1 exits, INVESTOR2 enters)
    ts.next_tx(INVESTOR1);
    let treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let policy = ts.take_shared<Policy<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let clock = clock::create_for_testing(ts.ctx());

    let mut from_chest = ts.take_shared_by_id<Chest>(inv1_chest_id);
    let to_chest = ts.take_shared_by_id<Chest>(inv2_chest_id);

    let pas_auth = chest::new_auth(ts.ctx());
    let mut request = chest::transfer_funds<TEST_VOLORO>(
        &mut from_chest,
        &pas_auth,
        &to_chest,
        500,
        ts.ctx(),
    );

    ds_token::transfer(
        &treasury,
        &mut investor_info,
        &compliance,
        &mut request,
        &version,
        &clock,
    );

    transfer_funds::resolve(request, &policy);

    clock.destroy_for_testing();
    ts::return_shared(treasury);
    ts::return_shared(investor_info);
    ts::return_shared(compliance);
    ts::return_shared(policy);
    ts::return_shared(version);
    ts::return_shared(from_chest);
    ts::return_shared(to_chest);

    // Verify count after: still 1 (one exited, one entered)
    ts.next_tx(ADMIN);
    let investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    assert!(registry_service::get_total_investors_count(&investor_info) == 1, 1);
    assert!(
        registry_service::investor_wallet_balance<TEST_VOLORO>(&investor_info, INVESTOR1) == 0,
        2,
    );
    assert!(
        registry_service::investor_wallet_balance<TEST_VOLORO>(&investor_info, INVESTOR2) == 500,
        3,
    );
    ts::return_shared(investor_info);

    ts.end();
}

/// Different investors: sender exits (transfers all), count decrements.
/// INVESTOR1 and INVESTOR2 both have tokens. INVESTOR1 transfers all to INVESTOR2.
/// INVESTOR2 is not a new investor → count only decrements (no increment).
#[test]
fun test_exit_investor_decrements_count() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    setup_investor(&mut ts, b"INV001", INVESTOR1, b"US");
    ts.next_tx(ADMIN);
    let inv1_chest_id = ts::most_recent_id_shared<Chest>().destroy_some();
    issue_to_investor(&mut ts, INVESTOR1, 500);
    setup_investor(&mut ts, b"INV002", INVESTOR2, b"FR");
    ts.next_tx(ADMIN);
    let inv2_chest_id = ts::most_recent_id_shared<Chest>().destroy_some();
    issue_to_investor(&mut ts, INVESTOR2, 300);

    // Both have tokens → count = 2
    ts.next_tx(ADMIN);
    let investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    assert!(registry_service::get_total_investors_count(&investor_info) == 2, 0);
    ts::return_shared(investor_info);

    // Transfer ALL from INVESTOR1 to INVESTOR2
    // !is_same_investor && from.is_exit_investor → count decrements
    // INVESTOR2 already has tokens (not new) → no increment
    ts.next_tx(INVESTOR1);
    let treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let policy = ts.take_shared<Policy<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let clock = clock::create_for_testing(ts.ctx());

    let mut from_chest = ts.take_shared_by_id<Chest>(inv1_chest_id);
    let to_chest = ts.take_shared_by_id<Chest>(inv2_chest_id);

    let pas_auth = chest::new_auth(ts.ctx());
    let mut request = chest::transfer_funds<TEST_VOLORO>(
        &mut from_chest,
        &pas_auth,
        &to_chest,
        500,
        ts.ctx(),
    );

    ds_token::transfer(
        &treasury,
        &mut investor_info,
        &compliance,
        &mut request,
        &version,
        &clock,
    );

    transfer_funds::resolve(request, &policy);

    clock.destroy_for_testing();
    ts::return_shared(treasury);
    ts::return_shared(investor_info);
    ts::return_shared(compliance);
    ts::return_shared(policy);
    ts::return_shared(version);
    ts::return_shared(from_chest);
    ts::return_shared(to_chest);

    // Count should be 1 (only INVESTOR2 remains)
    ts.next_tx(ADMIN);
    let investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    assert!(registry_service::get_total_investors_count(&investor_info) == 1, 1);
    assert!(
        registry_service::investor_wallet_balance<TEST_VOLORO>(&investor_info, INVESTOR1) == 0,
        2,
    );
    assert!(
        registry_service::investor_wallet_balance<TEST_VOLORO>(&investor_info, INVESTOR2) == 800,
        3,
    );
    ts::return_shared(investor_info);

    ts.end();
}

/// Transfer to special wallet succeeds (early exit, skips compliance rules)
#[test]
fun test_validate_transfer_to_special_wallet() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    setup_investor(&mut ts, b"INV001", INVESTOR1, b"US");
    ts.next_tx(ADMIN);
    let inv1_chest_id = ts::most_recent_id_shared<Chest>().destroy_some();
    issue_to_investor(&mut ts, INVESTOR1, 500);
    test_helpers::add_issuer_wallet(&mut ts, ISSUER_WALLET);
    ts.next_tx(ADMIN);
    let issuer_chest_id = ts::most_recent_id_shared<Chest>().destroy_some();

    // Transfer to issuer wallet
    ts.next_tx(INVESTOR1);
    let treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let policy = ts.take_shared<Policy<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let clock = clock::create_for_testing(ts.ctx());

    let issuer_chest = ts.take_shared_by_id<Chest>(issuer_chest_id);
    let mut investor_chest = ts.take_shared_by_id<Chest>(inv1_chest_id);

    let pas_auth = chest::new_auth(ts.ctx());
    let mut request = chest::transfer_funds<TEST_VOLORO>(
        &mut investor_chest,
        &pas_auth,
        &issuer_chest,
        200,
        ts.ctx(),
    );

    ds_token::transfer(
        &treasury,
        &mut investor_info,
        &compliance,
        &mut request,
        &version,
        &clock,
    );

    transfer_funds::resolve(request, &policy);

    // Verify balances
    assert!(
        registry_service::investor_wallet_balance<TEST_VOLORO>(&investor_info, INVESTOR1) == 300,
        0,
    );

    clock.destroy_for_testing();
    ts::return_shared(treasury);
    ts::return_shared(investor_info);
    ts::return_shared(compliance);
    ts::return_shared(policy);
    ts::return_shared(version);
    ts::return_shared(issuer_chest);
    ts::return_shared(investor_chest);
    ts.end();
}

/// Transfer from special wallet (issuer) to regular investor succeeds,
/// exercising the assert_and_compute_transferable_balance early return path
#[test]
fun test_validate_transfer_from_special_wallet() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    // Add issuer wallet (creates issuer's chest)
    test_helpers::add_issuer_wallet(&mut ts, ISSUER_WALLET);
    ts.next_tx(ADMIN);
    let issuer_chest_id = ts::most_recent_id_shared<Chest>().destroy_some();

    // Issue tokens to the issuer wallet
    ts.next_tx(ADMIN);
    let mut treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let chest = ts.take_shared<Chest>(); // only issuer chest exists
    let clock = clock::create_for_testing(ts.ctx());

    ds_token::issue_tokens(
        &mut treasury,
        &auth,
        &mut investor_info,
        &mut compliance,
        &chest,
        ISSUER_WALLET,
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
    ts::return_shared(chest);

    // Register a regular investor (creates investor's chest)
    setup_investor(&mut ts, b"INV001", INVESTOR1, b"US");
    ts.next_tx(ADMIN);
    let inv1_chest_id = ts::most_recent_id_shared<Chest>().destroy_some();

    // Transfer from issuer wallet to INVESTOR1
    ts.next_tx(ISSUER_WALLET);
    let treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let policy = ts.take_shared<Policy<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let clock = clock::create_for_testing(ts.ctx());

    let to_chest = ts.take_shared_by_id<Chest>(inv1_chest_id);
    let mut from_chest = ts.take_shared_by_id<Chest>(issuer_chest_id);

    let pas_auth = chest::new_auth(ts.ctx());
    let mut request = chest::transfer_funds<TEST_VOLORO>(
        &mut from_chest,
        &pas_auth,
        &to_chest,
        300,
        ts.ctx(),
    );

    ds_token::transfer(
        &treasury,
        &mut investor_info,
        &compliance,
        &mut request,
        &version,
        &clock,
    );

    transfer_funds::resolve(request, &policy);

    assert!(
        registry_service::investor_wallet_balance<TEST_VOLORO>(&investor_info, INVESTOR1) == 300,
        0,
    );

    clock.destroy_for_testing();
    ts::return_shared(treasury);
    ts::return_shared(investor_info);
    ts::return_shared(compliance);
    ts::return_shared(policy);
    ts::return_shared(version);
    ts::return_shared(to_chest);
    ts::return_shared(from_chest);
    ts.end();
}

/// Same investor transfer between two wallets: skips all compliance rules
#[test]
fun test_validate_transfer_same_investor() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    // Register a strict rule to prove it gets skipped
    ts.next_tx(ADMIN);
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let rule = force_full_transfer::new<TEST_VOLORO>(
        &auth,
        false,
        true,
        &version,
        ts.ctx(),
    );
    compliance_service::register_rule<TEST_VOLORO, ForceFullTransfer>(
        &mut compliance,
        &auth,
        rule,
        &version,
        ts.ctx(),
    );
    ts::return_shared(compliance);
    ts::return_shared(auth);
    ts::return_shared(version);

    // Register INVESTOR1 with first wallet and issue tokens
    setup_investor(&mut ts, b"INV001", INVESTOR1, b"US");
    ts.next_tx(ADMIN);
    let inv1_chest_id = ts::most_recent_id_shared<Chest>().destroy_some();
    issue_to_investor(&mut ts, INVESTOR1, 500);

    // Add a second wallet to the SAME investor
    test_helpers::add_investor_wallet(&mut ts, b"INV001", INVESTOR1_WALLET2);
    ts.next_tx(ADMIN);
    let wallet2_chest_id = ts::most_recent_id_shared<Chest>().destroy_some();

    // Partial transfer between same investor's wallets → should succeed
    // despite ForceFullTransfer rule (same investor exit skips all rules)
    ts.next_tx(INVESTOR1);
    let treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let policy = ts.take_shared<Policy<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let clock = clock::create_for_testing(ts.ctx());

    let mut from_chest = ts.take_shared_by_id<Chest>(inv1_chest_id);
    let to_chest = ts.take_shared_by_id<Chest>(wallet2_chest_id);

    let pas_auth = chest::new_auth(ts.ctx());
    let mut request = chest::transfer_funds<TEST_VOLORO>(
        &mut from_chest,
        &pas_auth,
        &to_chest,
        200,
        ts.ctx(),
    );

    ds_token::transfer(
        &treasury,
        &mut investor_info,
        &compliance,
        &mut request,
        &version,
        &clock,
    );

    transfer_funds::resolve(request, &policy);

    // Verify wallet balances updated (same investor, just moved between wallets)
    assert!(
        registry_service::investor_wallet_balance<TEST_VOLORO>(&investor_info, INVESTOR1) == 300,
        0,
    );
    assert!(
        registry_service::investor_wallet_balance<TEST_VOLORO>(&investor_info, INVESTOR1_WALLET2) == 200,
        1,
    );

    clock.destroy_for_testing();
    ts::return_shared(treasury);
    ts::return_shared(investor_info);
    ts::return_shared(compliance);
    ts::return_shared(policy);
    ts::return_shared(version);
    ts::return_shared(to_chest);
    ts::return_shared(from_chest);
    ts.end();
}

/// Transfer with individual time-based lock → ETokensLocked
#[test]
#[expected_failure(abort_code = compliance_service::ETokensLocked)]
fun test_validate_transfer_with_time_lock() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    // Issue 500 tokens with 400 locked (release far in the future)
    setup_investor(&mut ts, b"INV001", INVESTOR1, b"US");
    ts.next_tx(ADMIN);
    let inv1_chest_id = ts::most_recent_id_shared<Chest>().destroy_some();

    ts.next_tx(ADMIN);
    let mut treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let chest = ts.take_shared<Chest>();
    let clock = clock::create_for_testing(ts.ctx());

    ds_token::issue_tokens(
        &mut treasury,
        &auth,
        &mut investor_info,
        &mut compliance,
        &chest,
        INVESTOR1,
        500,
        0,
        b"lock".to_string(),
        &version,
        vector[400], // lock 400 tokens
        vector[999_999_999_999], // release far in the future
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
    ts::return_shared(chest);

    setup_investor(&mut ts, b"INV002", INVESTOR2, b"FR");
    ts.next_tx(ADMIN);
    let inv2_chest_id = ts::most_recent_id_shared<Chest>().destroy_some();

    // Try to transfer 200 but only 100 is unlocked (500 - 400 = 100)
    ts.next_tx(INVESTOR1);
    let treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let policy = ts.take_shared<Policy<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let clock = clock::create_for_testing(ts.ctx());

    let mut from_chest = ts.take_shared_by_id<Chest>(inv1_chest_id);
    let to_chest = ts.take_shared_by_id<Chest>(inv2_chest_id);

    let pas_auth = chest::new_auth(ts.ctx());
    let mut request = chest::transfer_funds<TEST_VOLORO>(
        &mut from_chest,
        &pas_auth,
        &to_chest,
        200,
        ts.ctx(),
    );

    ds_token::transfer(
        &treasury,
        &mut investor_info,
        &compliance,
        &mut request,
        &version,
        &clock,
    );

    transfer_funds::resolve(request, &policy);

    clock.destroy_for_testing();
    ts::return_shared(treasury);
    ts::return_shared(investor_info);
    ts::return_shared(compliance);
    ts::return_shared(policy);
    ts::return_shared(version);
    ts::return_shared(from_chest);
    ts::return_shared(to_chest);

    ts.end();
}

/// LockupRestriction: transfer blocked when tokens are still under lockup → EUnderLockup
#[test]
#[expected_failure(abort_code = lockup_restriction::EUnderLockup)]
fun test_validate_transfer_with_lockup_restriction() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    // Register LockupRestriction rule: 1 year lock for both US and non-US
    ts.next_tx(ADMIN);
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let rule = lockup_restriction::new<TEST_VOLORO>(
        &auth,
        test_helpers::one_year_ms(),
        test_helpers::one_year_ms(),
        &version,
        ts.ctx(),
    );
    compliance_service::register_rule<TEST_VOLORO, LockupRestriction>(
        &mut compliance,
        &auth,
        rule,
        &version,
        ts.ctx(),
    );
    ts::return_shared(compliance);
    ts::return_shared(auth);
    ts::return_shared(version);

    setup_investor(&mut ts, b"INV001", INVESTOR1, b"US");
    ts.next_tx(ADMIN);
    let inv1_chest_id = ts::most_recent_id_shared<Chest>().destroy_some();
    issue_to_investor(&mut ts, INVESTOR1, 500);
    setup_investor(&mut ts, b"INV002", INVESTOR2, b"FR");
    ts.next_tx(ADMIN);
    let inv2_chest_id = ts::most_recent_id_shared<Chest>().destroy_some();

    // Transfer at time 0 → all 500 tokens locked (issuance at time 0, lock = 1 year)
    ts.next_tx(INVESTOR1);
    let treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let policy = ts.take_shared<Policy<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let clock = clock::create_for_testing(ts.ctx());

    let mut from_chest = ts.take_shared_by_id<Chest>(inv1_chest_id);
    let to_chest = ts.take_shared_by_id<Chest>(inv2_chest_id);

    let pas_auth = chest::new_auth(ts.ctx());
    let mut request = chest::transfer_funds<TEST_VOLORO>(
        &mut from_chest,
        &pas_auth,
        &to_chest,
        200,
        ts.ctx(),
    );

    ds_token::transfer(
        &treasury,
        &mut investor_info,
        &compliance,
        &mut request,
        &version,
        &clock,
    );

    transfer_funds::resolve(request, &policy);

    clock.destroy_for_testing();
    ts::return_shared(treasury);
    ts::return_shared(investor_info);
    ts::return_shared(compliance);
    ts::return_shared(policy);
    ts::return_shared(version);
    ts::return_shared(from_chest);
    ts::return_shared(to_chest);

    ts.end();
}

/// HoldingLimits: recipient would exceed max holding → EAboveMaxHolding
#[test]
#[expected_failure(abort_code = holding_limits::EAboveMaxHolding)]
fun test_validate_transfer_with_holding_limits_exceeds_max() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    // Register HoldingLimits rule: max 300 per investor
    ts.next_tx(ADMIN);
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let rule = holding_limits::new<TEST_VOLORO>(
        &auth,
        0,
        300,
        vector[],
        vector[],
        &version,
        ts.ctx(),
    );
    compliance_service::register_rule<TEST_VOLORO, HoldingLimits>(
        &mut compliance,
        &auth,
        rule,
        &version,
        ts.ctx(),
    );
    ts::return_shared(compliance);
    ts::return_shared(auth);
    ts::return_shared(version);

    setup_investor(&mut ts, b"INV001", INVESTOR1, b"US");
    ts.next_tx(ADMIN);
    let inv1_chest_id = ts::most_recent_id_shared<Chest>().destroy_some();
    issue_to_investor(&mut ts, INVESTOR1, 500);
    setup_investor(&mut ts, b"INV002", INVESTOR2, b"FR");
    ts.next_tx(ADMIN);
    let inv2_chest_id = ts::most_recent_id_shared<Chest>().destroy_some();

    // Transfer 400 → recipient would have 400 > max 300
    ts.next_tx(INVESTOR1);
    let treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let policy = ts.take_shared<Policy<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let clock = clock::create_for_testing(ts.ctx());

    let mut from_chest = ts.take_shared_by_id<Chest>(inv1_chest_id);
    let to_chest = ts.take_shared_by_id<Chest>(inv2_chest_id);

    let pas_auth = chest::new_auth(ts.ctx());
    let mut request = chest::transfer_funds<TEST_VOLORO>(
        &mut from_chest,
        &pas_auth,
        &to_chest,
        400,
        ts.ctx(),
    );

    ds_token::transfer(
        &treasury,
        &mut investor_info,
        &compliance,
        &mut request,
        &version,
        &clock,
    );

    transfer_funds::resolve(request, &policy);

    clock.destroy_for_testing();
    ts::return_shared(treasury);
    ts::return_shared(investor_info);
    ts::return_shared(compliance);
    ts::return_shared(policy);
    ts::return_shared(version);
    ts::return_shared(from_chest);
    ts::return_shared(to_chest);

    ts.end();
}

/// ForceFullTransfer worldwide: partial transfer → EPartialTransferNotAllowed
#[test]
#[expected_failure(abort_code = force_full_transfer::EPartialTransferNotAllowed)]
fun test_validate_transfer_with_force_full_transfer() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    // Register ForceFullTransfer rule (worldwide)
    ts.next_tx(ADMIN);
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let rule = force_full_transfer::new<TEST_VOLORO>(
        &auth,
        false,
        true,
        &version,
        ts.ctx(), // worldwide = true
    );
    compliance_service::register_rule<TEST_VOLORO, ForceFullTransfer>(
        &mut compliance,
        &auth,
        rule,
        &version,
        ts.ctx(),
    );
    ts::return_shared(compliance);
    ts::return_shared(auth);
    ts::return_shared(version);

    setup_investor(&mut ts, b"INV001", INVESTOR1, b"US");
    ts.next_tx(ADMIN);
    let inv1_chest_id = ts::most_recent_id_shared<Chest>().destroy_some();
    issue_to_investor(&mut ts, INVESTOR1, 500);
    setup_investor(&mut ts, b"INV002", INVESTOR2, b"FR");
    ts.next_tx(ADMIN);
    let inv2_chest_id = ts::most_recent_id_shared<Chest>().destroy_some();

    // Partial transfer (200 of 500) should fail
    ts.next_tx(INVESTOR1);
    let treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let policy = ts.take_shared<Policy<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let clock = clock::create_for_testing(ts.ctx());

    let mut from_chest = ts.take_shared_by_id<Chest>(inv1_chest_id);
    let to_chest = ts.take_shared_by_id<Chest>(inv2_chest_id);

    let pas_auth = chest::new_auth(ts.ctx());
    let mut request = chest::transfer_funds<TEST_VOLORO>(
        &mut from_chest,
        &pas_auth,
        &to_chest,
        200,
        ts.ctx(),
    );

    ds_token::transfer(
        &treasury,
        &mut investor_info,
        &compliance,
        &mut request,
        &version,
        &clock,
    );

    transfer_funds::resolve(request, &policy);

    clock.destroy_for_testing();
    ts::return_shared(treasury);
    ts::return_shared(investor_info);
    ts::return_shared(compliance);
    ts::return_shared(policy);
    ts::return_shared(version);
    ts::return_shared(from_chest);
    ts::return_shared(to_chest);

    ts.end();
}

/// ForceFullTransfer: partial transfer to special wallet → EPartialTransferNotAllowed
#[test]
#[expected_failure(abort_code = force_full_transfer::EPartialTransferNotAllowed)]
fun test_transfer_to_special_wallet_with_force_full_transfer() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    // Register ForceFullTransfer rule (worldwide)
    ts.next_tx(ADMIN);
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let rule = force_full_transfer::new<TEST_VOLORO>(
        &auth,
        false,
        true,
        &version,
        ts.ctx(),
    );
    compliance_service::register_rule<TEST_VOLORO, ForceFullTransfer>(
        &mut compliance,
        &auth,
        rule,
        &version,
        ts.ctx(),
    );
    ts::return_shared(compliance);
    ts::return_shared(auth);
    ts::return_shared(version);

    setup_investor(&mut ts, b"INV001", INVESTOR1, b"US");
    ts.next_tx(ADMIN);
    let inv1_chest_id = ts::most_recent_id_shared<Chest>().destroy_some();
    issue_to_investor(&mut ts, INVESTOR1, 500);
    test_helpers::add_issuer_wallet(&mut ts, ISSUER_WALLET);
    ts.next_tx(ADMIN);
    let issuer_chest_id = ts::most_recent_id_shared<Chest>().destroy_some();

    // Partial transfer (200 of 500) to issuer wallet → EPartialTransferNotAllowed
    ts.next_tx(INVESTOR1);
    let treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let policy = ts.take_shared<Policy<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let clock = clock::create_for_testing(ts.ctx());

    let issuer_chest = ts.take_shared_by_id<Chest>(issuer_chest_id);
    let mut investor_chest = ts.take_shared_by_id<Chest>(inv1_chest_id);

    let pas_auth = chest::new_auth(ts.ctx());
    let mut request = chest::transfer_funds<TEST_VOLORO>(
        &mut investor_chest,
        &pas_auth,
        &issuer_chest,
        200,
        ts.ctx(),
    );

    ds_token::transfer(
        &treasury,
        &mut investor_info,
        &compliance,
        &mut request,
        &version,
        &clock,
    );

    transfer_funds::resolve(request, &policy);

    clock.destroy_for_testing();
    ts::return_shared(treasury);
    ts::return_shared(investor_info);
    ts::return_shared(compliance);
    ts::return_shared(policy);
    ts::return_shared(version);
    ts::return_shared(issuer_chest);
    ts::return_shared(investor_chest);
    ts.end();
}

/// FlowbackRestriction: non-US → US transfer blocked during active restriction period
#[test]
#[expected_failure(abort_code = flowback_restriction::EFlowbackRestricted)]
fun test_validate_transfer_with_flowback_restriction_blocked() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    // Set US compliance region
    test_helpers::set_country_compliance(&mut ts, b"US", 1); // US = 1

    // Register FlowbackRestriction: restriction ends at 90 days (Reg S distribution period)
    ts.next_tx(ADMIN);
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let ninety_days_ms: u64 = 90 * 24 * 60 * 60 * 1000; // 7,776,000,000 ms
    let rule = flowback_restriction::new<TEST_VOLORO>(
        &auth,
        ninety_days_ms,
        &version,
        ts.ctx(),
    );
    compliance_service::register_rule<TEST_VOLORO, FlowbackRestriction>(
        &mut compliance,
        &auth,
        rule,
        &version,
        ts.ctx(),
    );
    ts::return_shared(compliance);
    ts::return_shared(auth);
    ts::return_shared(version);

    // INVESTOR1 = FR (non-US sender), INVESTOR2 = US (US recipient)
    setup_investor(&mut ts, b"INV001", INVESTOR1, b"FR");
    ts.next_tx(ADMIN);
    let inv1_chest_id = ts::most_recent_id_shared<Chest>().destroy_some();
    issue_to_investor(&mut ts, INVESTOR1, 500);
    setup_investor(&mut ts, b"INV002", INVESTOR2, b"US");
    ts.next_tx(ADMIN);
    let inv2_chest_id = ts::most_recent_id_shared<Chest>().destroy_some();

    // Transfer at time 0 → within 90-day restriction → blocked
    ts.next_tx(INVESTOR1);
    let treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let policy = ts.take_shared<Policy<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let clock = clock::create_for_testing(ts.ctx());

    let mut from_chest = ts.take_shared_by_id<Chest>(inv1_chest_id);
    let to_chest = ts.take_shared_by_id<Chest>(inv2_chest_id);

    let pas_auth = chest::new_auth(ts.ctx());
    let mut request = chest::transfer_funds<TEST_VOLORO>(
        &mut from_chest,
        &pas_auth,
        &to_chest,
        200,
        ts.ctx(),
    );

    ds_token::transfer(
        &treasury,
        &mut investor_info,
        &compliance,
        &mut request,
        &version,
        &clock,
    );

    transfer_funds::resolve(request, &policy);

    clock.destroy_for_testing();
    ts::return_shared(treasury);
    ts::return_shared(investor_info);
    ts::return_shared(compliance);
    ts::return_shared(policy);
    ts::return_shared(version);
    ts::return_shared(from_chest);
    ts::return_shared(to_chest);

    ts.end();
}

/// FlowbackRestriction: non-US → US transfer succeeds after restriction period expires
#[test]
fun test_validate_transfer_with_flowback_restriction_expired() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    // Set US compliance region
    test_helpers::set_country_compliance(&mut ts, b"US", 1); // US = 1

    // Register FlowbackRestriction: restriction ends at 90 days
    ts.next_tx(ADMIN);
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let ninety_days_ms: u64 = 90 * 24 * 60 * 60 * 1000;
    let rule = flowback_restriction::new<TEST_VOLORO>(
        &auth,
        ninety_days_ms,
        &version,
        ts.ctx(),
    );
    compliance_service::register_rule<TEST_VOLORO, FlowbackRestriction>(
        &mut compliance,
        &auth,
        rule,
        &version,
        ts.ctx(),
    );
    ts::return_shared(compliance);
    ts::return_shared(auth);
    ts::return_shared(version);

    // INVESTOR1 = FR (non-US sender), INVESTOR2 = US (US recipient)
    setup_investor(&mut ts, b"INV001", INVESTOR1, b"FR");
    ts.next_tx(ADMIN);
    let inv1_chest_id = ts::most_recent_id_shared<Chest>().destroy_some();
    issue_to_investor(&mut ts, INVESTOR1, 500);
    setup_investor(&mut ts, b"INV002", INVESTOR2, b"US");
    ts.next_tx(ADMIN);
    let inv2_chest_id = ts::most_recent_id_shared<Chest>().destroy_some();

    // Transfer at time 91 days → past the 90-day restriction → allowed
    ts.next_tx(INVESTOR1);
    let treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let policy = ts.take_shared<Policy<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let mut clock = clock::create_for_testing(ts.ctx());
    let ninety_one_days_ms: u64 = 91 * 24 * 60 * 60 * 1000;
    clock::set_for_testing(&mut clock, ninety_one_days_ms);

    let mut from_chest = ts.take_shared_by_id<Chest>(inv1_chest_id);
    let to_chest = ts.take_shared_by_id<Chest>(inv2_chest_id);

    let pas_auth = chest::new_auth(ts.ctx());
    let mut request = chest::transfer_funds<TEST_VOLORO>(
        &mut from_chest,
        &pas_auth,
        &to_chest,
        200,
        ts.ctx(),
    );

    ds_token::transfer(
        &treasury,
        &mut investor_info,
        &compliance,
        &mut request,
        &version,
        &clock,
    );

    transfer_funds::resolve(request, &policy);

    assert!(
        registry_service::investor_wallet_balance<TEST_VOLORO>(&investor_info, INVESTOR1) == 300,
        0,
    );
    assert!(
        registry_service::investor_wallet_balance<TEST_VOLORO>(&investor_info, INVESTOR2) == 200,
        1,
    );

    clock.destroy_for_testing();
    ts::return_shared(treasury);
    ts::return_shared(investor_info);
    ts::return_shared(compliance);
    ts::return_shared(policy);
    ts::return_shared(version);
    ts::return_shared(to_chest);
    ts::return_shared(from_chest);
    ts.end();
}

/// AccreditedOnly: transfer to non-accredited investor → ENotAccredited
#[test]
#[expected_failure(abort_code = accredited_only::ENotAccredited)]
fun test_validate_transfer_with_accredited_only() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    // Register AccreditedOnly rule (force_accredited = true)
    ts.next_tx(ADMIN);
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
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
    ts::return_shared(compliance);
    ts::return_shared(auth);
    ts::return_shared(version);

    // INVESTOR1 is accredited, INVESTOR2 is NOT
    setup_investor(&mut ts, b"INV001", INVESTOR1, b"US");
    ts.next_tx(ADMIN);
    let inv1_chest_id = ts::most_recent_id_shared<Chest>().destroy_some();

    ts.next_tx(ADMIN);
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    registry_service::set_attribute<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        2,
        1,
        0,
        &version,
        ts.ctx(), // ACCREDITED=2, APPROVED=1
    );
    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);

    issue_to_investor(&mut ts, INVESTOR1, 500);
    setup_investor(&mut ts, b"INV002", INVESTOR2, b"FR");
    ts.next_tx(ADMIN);
    let inv2_chest_id = ts::most_recent_id_shared<Chest>().destroy_some();
    // Transfer to non-accredited INVESTOR2 should fail
    ts.next_tx(INVESTOR1);
    let treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let policy = ts.take_shared<Policy<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let clock = clock::create_for_testing(ts.ctx());

    let mut from_chest = ts.take_shared_by_id<Chest>(inv1_chest_id);
    let to_chest = ts.take_shared_by_id<Chest>(inv2_chest_id);

    let pas_auth = chest::new_auth(ts.ctx());
    let mut request = chest::transfer_funds<TEST_VOLORO>(
        &mut from_chest,
        &pas_auth,
        &to_chest,
        200,
        ts.ctx(),
    );

    ds_token::transfer(
        &treasury,
        &mut investor_info,
        &compliance,
        &mut request,
        &version,
        &clock,
    );

    transfer_funds::resolve(request, &policy);

    clock.destroy_for_testing();
    ts::return_shared(treasury);
    ts::return_shared(investor_info);
    ts::return_shared(compliance);
    ts::return_shared(policy);
    ts::return_shared(version);
    ts::return_shared(from_chest);
    ts::return_shared(to_chest);

    ts.end();
}

/// InvestorLimits: transfer creating new investor exceeding limit → EMaxInvestorsExceeded
#[test]
#[expected_failure(abort_code = investor_limits::EMaxInvestorsExceeded)]
fun test_validate_transfer_with_investor_limits_exceeded() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    // Register InvestorLimits rule: max 1 total investor
    ts.next_tx(ADMIN);
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let rule = investor_limits::new<TEST_VOLORO>(
        &auth,
        1, // total_investors_limit = 1
        0, // minimum_total_investors
        0,
        0,
        0,
        0,
        0,
        0, // other limits disabled
        &version,
        ts.ctx(),
    );
    compliance_service::register_rule<TEST_VOLORO, InvestorLimits>(
        &mut compliance,
        &auth,
        rule,
        &version,
        ts.ctx(),
    );
    ts::return_shared(compliance);
    ts::return_shared(auth);
    ts::return_shared(version);

    setup_investor(&mut ts, b"INV001", INVESTOR1, b"US");
    ts.next_tx(ADMIN);
    let inv1_chest_id = ts::most_recent_id_shared<Chest>().destroy_some();
    issue_to_investor(&mut ts, INVESTOR1, 500);
    setup_investor(&mut ts, b"INV002", INVESTOR2, b"FR");
    ts.next_tx(ADMIN);
    let inv2_chest_id = ts::most_recent_id_shared<Chest>().destroy_some();

    // Partial transfer: INVESTOR1 stays (count=1), INVESTOR2 would be new (count→2 > limit=1)
    ts.next_tx(INVESTOR1);
    let treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let policy = ts.take_shared<Policy<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let clock = clock::create_for_testing(ts.ctx());

    let mut from_chest = ts.take_shared_by_id<Chest>(inv1_chest_id);
    let to_chest = ts.take_shared_by_id<Chest>(inv2_chest_id);

    let pas_auth = chest::new_auth(ts.ctx());
    let mut request = chest::transfer_funds<TEST_VOLORO>(
        &mut from_chest,
        &pas_auth,
        &to_chest,
        200,
        ts.ctx(),
    );

    ds_token::transfer(
        &treasury,
        &mut investor_info,
        &compliance,
        &mut request,
        &version,
        &clock,
    );

    transfer_funds::resolve(request, &policy);

    clock.destroy_for_testing();
    ts::return_shared(treasury);
    ts::return_shared(investor_info);
    ts::return_shared(compliance);
    ts::return_shared(policy);
    ts::return_shared(version);
    ts::return_shared(from_chest);
    ts::return_shared(to_chest);

    ts.end();
}

/// EU retail per-country limit: transfer to different EU country succeeds (per-country tracking)
#[test]
fun test_investor_limits_eu_retail_different_country_succeeds() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    // Set DE and FR as EU region (2)
    test_helpers::set_country_compliance(&mut ts, b"DE", 2); // EU = 2
    test_helpers::set_country_compliance(&mut ts, b"FR", 2); // EU = 2

    // Register InvestorLimits: eu_retail_limit = 1 per country
    ts.next_tx(ADMIN);
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let rule = investor_limits::new<TEST_VOLORO>(
        &auth,
        0, // total_investors_limit (no limit)
        0, // minimum_total_investors
        0,
        0,
        0,
        0,
        1, // eu_retail_limit = 1 per country
        0, // max_us_percentage
        &version,
        ts.ctx(),
    );
    compliance_service::register_rule<TEST_VOLORO, InvestorLimits>(
        &mut compliance,
        &auth,
        rule,
        &version,
        ts.ctx(),
    );
    ts::return_shared(compliance);
    ts::return_shared(auth);
    ts::return_shared(version);

    // INVESTOR1 in DE, INVESTOR2 in FR (different EU countries)
    setup_investor(&mut ts, b"INV001", INVESTOR1, b"DE");
    ts.next_tx(ADMIN);
    let inv1_chest_id = ts::most_recent_id_shared<Chest>().destroy_some();
    issue_to_investor(&mut ts, INVESTOR1, 500); // DE retail count → 1
    setup_investor(&mut ts, b"INV002", INVESTOR2, b"FR");
    ts.next_tx(ADMIN);
    let inv2_chest_id = ts::most_recent_id_shared<Chest>().destroy_some();

    // Transfer to INVESTOR2 (FR): FR retail count = 0 < limit 1 → succeeds
    ts.next_tx(INVESTOR1);
    let treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let policy = ts.take_shared<Policy<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let clock = clock::create_for_testing(ts.ctx());

    let mut from_chest = ts.take_shared_by_id<Chest>(inv1_chest_id);
    let to_chest = ts.take_shared_by_id<Chest>(inv2_chest_id);

    let pas_auth = chest::new_auth(ts.ctx());
    let mut request = chest::transfer_funds<TEST_VOLORO>(
        &mut from_chest,
        &pas_auth,
        &to_chest,
        200,
        ts.ctx(),
    );

    ds_token::transfer(
        &treasury,
        &mut investor_info,
        &compliance,
        &mut request,
        &version,
        &clock,
    );

    transfer_funds::resolve(request, &policy);

    clock.destroy_for_testing();
    ts::return_shared(treasury);
    ts::return_shared(investor_info);
    ts::return_shared(compliance);
    ts::return_shared(policy);
    ts::return_shared(version);
    ts::return_shared(from_chest);
    ts::return_shared(to_chest);

    ts.next_tx(ADMIN);
    let investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    assert!(
        registry_service::investor_wallet_balance<TEST_VOLORO>(&investor_info, INVESTOR1) == 300,
        0,
    );
    assert!(
        registry_service::investor_wallet_balance<TEST_VOLORO>(&investor_info, INVESTOR2) == 200,
        1,
    );
    ts::return_shared(investor_info);

    ts.end();
}

/// EU retail per-country limit: partial transfer to same EU country exceeds limit → EMaxEURetailExceeded
#[test]
#[expected_failure(abort_code = investor_limits::EMaxEURetailExceeded)]
fun test_investor_limits_eu_retail_same_country_exceeded() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    // Set DE as EU region (2)
    test_helpers::set_country_compliance(&mut ts, b"DE", 2); // EU = 2

    // Register InvestorLimits: eu_retail_limit = 1 per country
    ts.next_tx(ADMIN);
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let rule = investor_limits::new<TEST_VOLORO>(
        &auth,
        0, // total_investors_limit (no limit)
        0, // minimum_total_investors
        0,
        0,
        0,
        0,
        1, // eu_retail_limit = 1 per country
        0, // max_us_percentage
        &version,
        ts.ctx(),
    );
    compliance_service::register_rule<TEST_VOLORO, InvestorLimits>(
        &mut compliance,
        &auth,
        rule,
        &version,
        ts.ctx(),
    );
    ts::return_shared(compliance);
    ts::return_shared(auth);
    ts::return_shared(version);

    // INVESTOR1 and INVESTOR2 both in DE (same EU country)
    setup_investor(&mut ts, b"INV001", INVESTOR1, b"DE");
    ts.next_tx(ADMIN);
    let inv1_chest_id = ts::most_recent_id_shared<Chest>().destroy_some();
    issue_to_investor(&mut ts, INVESTOR1, 500); // DE retail count → 1
    setup_investor(&mut ts, b"INV002", INVESTOR2, b"DE");
    ts.next_tx(ADMIN);
    let inv2_chest_id = ts::most_recent_id_shared<Chest>().destroy_some();

    // Partial transfer (200 of 500): INVESTOR1 stays (not exiting), INVESTOR2 enters
    // DE retail count = 1 >= limit 1 → EMaxEURetailExceeded
    ts.next_tx(INVESTOR1);
    let treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let policy = ts.take_shared<Policy<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let clock = clock::create_for_testing(ts.ctx());

    let mut from_chest = ts.take_shared_by_id<Chest>(inv1_chest_id);
    let to_chest = ts.take_shared_by_id<Chest>(inv2_chest_id);

    let pas_auth = chest::new_auth(ts.ctx());
    let mut request = chest::transfer_funds<TEST_VOLORO>(
        &mut from_chest,
        &pas_auth,
        &to_chest,
        200,
        ts.ctx(),
    );

    ds_token::transfer(
        &treasury,
        &mut investor_info,
        &compliance,
        &mut request,
        &version,
        &clock,
    );

    transfer_funds::resolve(request, &policy);

    clock.destroy_for_testing();
    ts::return_shared(treasury);
    ts::return_shared(investor_info);
    ts::return_shared(compliance);
    ts::return_shared(policy);
    ts::return_shared(version);
    ts::return_shared(from_chest);
    ts::return_shared(to_chest);

    ts.end();
}

/// BackdatingIssuance allowed: backdated issuance timestamp is used for lockup calculation
#[test]
fun test_backdating_issuance_allowed() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    // Register BackdatingIssuance (allow backdating) + LockupRestriction (10,000ms)
    ts.next_tx(ADMIN);
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let bd_rule = backdating_issuance::new<TEST_VOLORO>(
        &auth,
        false,
        &version,
        ts.ctx(), // disallow_backdating = false → allowed
    );
    compliance_service::register_rule<TEST_VOLORO, BackdatingIssuance>(
        &mut compliance,
        &auth,
        bd_rule,
        &version,
        ts.ctx(),
    );

    let lr_rule = lockup_restriction::new<TEST_VOLORO>(
        &auth,
        10_000,
        10_000,
        &version,
        ts.ctx(),
    );
    compliance_service::register_rule<TEST_VOLORO, LockupRestriction>(
        &mut compliance,
        &auth,
        lr_rule,
        &version,
        ts.ctx(),
    );

    ts::return_shared(compliance);
    ts::return_shared(auth);
    ts::return_shared(version);

    setup_investor(&mut ts, b"INV001", INVESTOR1, b"US");
    ts.next_tx(ADMIN);
    let inv1_chest_id = ts::most_recent_id_shared<Chest>().destroy_some();

    // Issue at clock time 20,000 but with backdated issuance_time = 5,000
    // Since backdating is allowed, issuance records time 5,000
    // Lock expires at 5,000 + 10,000 = 15,000 < 20,000 → already unlocked
    ts.next_tx(ADMIN);
    let mut treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let chest = ts.take_shared<Chest>(); // only 1 chest at this point
    let mut clock = clock::create_for_testing(ts.ctx());
    clock::set_for_testing(&mut clock, 20_000);

    ds_token::issue_tokens(
        &mut treasury,
        &auth,
        &mut investor_info,
        &mut compliance,
        &chest,
        INVESTOR1,
        500,
        0,
        b"".to_string(),
        &version,
        vector[],
        vector[],
        5_000,
        &clock,
        ts.ctx(), // issuance_time_ms = 5,000 (backdated)
    );

    clock.destroy_for_testing();
    ts::return_shared(treasury);
    ts::return_shared(auth);
    ts::return_shared(investor_info);
    ts::return_shared(compliance);
    ts::return_shared(version);
    ts::return_shared(chest);

    setup_investor(&mut ts, b"INV002", INVESTOR2, b"FR");
    ts.next_tx(ADMIN);
    let inv2_chest_id = ts::most_recent_id_shared<Chest>().destroy_some();

    // Transfer at clock time 20,000 → issuance at 5,000 + lock 10,000 = 15,000 < 20,000
    // Tokens are unlocked because backdating placed issuance in the past → succeeds
    ts.next_tx(INVESTOR1);
    let treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let policy = ts.take_shared<Policy<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let mut clock = clock::create_for_testing(ts.ctx());
    clock::set_for_testing(&mut clock, 20_000);

    let mut from_chest = ts.take_shared_by_id<Chest>(inv1_chest_id);
    let to_chest = ts.take_shared_by_id<Chest>(inv2_chest_id);

    let pas_auth = chest::new_auth(ts.ctx());
    let mut request = chest::transfer_funds<TEST_VOLORO>(
        &mut from_chest,
        &pas_auth,
        &to_chest,
        200,
        ts.ctx(),
    );

    ds_token::transfer(
        &treasury,
        &mut investor_info,
        &compliance,
        &mut request,
        &version,
        &clock,
    );

    transfer_funds::resolve(request, &policy);

    assert!(
        registry_service::investor_wallet_balance<TEST_VOLORO>(&investor_info, INVESTOR1) == 300,
        0,
    );
    assert!(
        registry_service::investor_wallet_balance<TEST_VOLORO>(&investor_info, INVESTOR2) == 200,
        1,
    );

    clock.destroy_for_testing();
    ts::return_shared(treasury);
    ts::return_shared(investor_info);
    ts::return_shared(compliance);
    ts::return_shared(policy);
    ts::return_shared(version);
    ts::return_shared(to_chest);
    ts::return_shared(from_chest);
    ts.end();
}

/// After lockup expires, transfer succeeds and expired issuances are cleaned up
#[test]
fun test_cleanup_party_issuances() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    // Register LockupRestriction rule: 10,000ms lock for both regions
    ts.next_tx(ADMIN);
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let rule = lockup_restriction::new<TEST_VOLORO>(
        &auth,
        10_000,
        10_000,
        &version,
        ts.ctx(),
    );
    compliance_service::register_rule<TEST_VOLORO, LockupRestriction>(
        &mut compliance,
        &auth,
        rule,
        &version,
        ts.ctx(),
    );
    ts::return_shared(compliance);
    ts::return_shared(auth);
    ts::return_shared(version);

    setup_investor(&mut ts, b"INV001", INVESTOR1, b"US");
    ts.next_tx(ADMIN);
    let inv1_chest_id = ts::most_recent_id_shared<Chest>().destroy_some();
    issue_to_investor(&mut ts, INVESTOR1, 500); // issuance recorded at time 0
    setup_investor(&mut ts, b"INV002", INVESTOR2, b"FR");
    ts.next_tx(ADMIN);
    let inv2_chest_id = ts::most_recent_id_shared<Chest>().destroy_some();

    // Transfer at time 10,001 → issuance expired, cleanup removes it, transfer succeeds
    ts.next_tx(INVESTOR1);
    let treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let policy = ts.take_shared<Policy<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let mut clock = clock::create_for_testing(ts.ctx());
    clock::set_for_testing(&mut clock, 10_001);

    let mut from_chest = ts.take_shared_by_id<Chest>(inv1_chest_id);
    let to_chest = ts.take_shared_by_id<Chest>(inv2_chest_id);

    let pas_auth = chest::new_auth(ts.ctx());
    let mut request = chest::transfer_funds<TEST_VOLORO>(
        &mut from_chest,
        &pas_auth,
        &to_chest,
        200,
        ts.ctx(),
    );

    ds_token::transfer(
        &treasury,
        &mut investor_info,
        &compliance,
        &mut request,
        &version,
        &clock,
    );

    transfer_funds::resolve(request, &policy);

    assert!(
        registry_service::investor_wallet_balance<TEST_VOLORO>(&investor_info, INVESTOR1) == 300,
        0,
    );
    assert!(
        registry_service::investor_wallet_balance<TEST_VOLORO>(&investor_info, INVESTOR2) == 200,
        1,
    );

    clock.destroy_for_testing();
    ts::return_shared(treasury);
    ts::return_shared(investor_info);
    ts::return_shared(compliance);
    ts::return_shared(policy);
    ts::return_shared(version);
    ts::return_shared(to_chest);
    ts::return_shared(from_chest);
    ts.end();
}

// ==================== Full Lifecycle ====================

/// Comprehensive test: ALL 8 rules enabled, multiple issuances (regular + special wallet),
/// multiple transfers (regular→regular, regular→special, regular→regular re-entry,
/// same investor), then verify per-wallet balances, total investor balances, and counters.
#[test]
fun test_full_lifecycle_with_all_rules() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);
    // Set country compliances: US→1, FR→2 (EU)
    test_helpers::set_country_compliance(&mut ts, b"US", 1);
    test_helpers::set_country_compliance(&mut ts, b"FR", 2);

    // Register ALL 8 rules
    ts.next_tx(ADMIN);
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    let r1 = accredited_only::new<TEST_VOLORO>(&auth, true, false, &version, ts.ctx());
    compliance_service::register_rule<TEST_VOLORO, AccreditedOnly>(
        &mut compliance,
        &auth,
        r1,
        &version,
        ts.ctx(),
    );

    let r2 = authorized_securities::new<TEST_VOLORO>(&auth, 10_000, &version, ts.ctx());
    compliance_service::register_rule<TEST_VOLORO, AuthorizedSecurities>(
        &mut compliance,
        &auth,
        r2,
        &version,
        ts.ctx(),
    );

    let r3 = backdating_issuance::new<TEST_VOLORO>(&auth, false, &version, ts.ctx());
    compliance_service::register_rule<TEST_VOLORO, BackdatingIssuance>(
        &mut compliance,
        &auth,
        r3,
        &version,
        ts.ctx(),
    );

    let r4 = holding_limits::new<TEST_VOLORO>(
        &auth,
        10,
        5000,
        vector[],
        vector[],
        &version,
        ts.ctx(),
    );
    compliance_service::register_rule<TEST_VOLORO, HoldingLimits>(
        &mut compliance,
        &auth,
        r4,
        &version,
        ts.ctx(),
    );

    let r5 = investor_limits::new<TEST_VOLORO>(
        &auth,
        10,
        0,
        5,
        5,
        5,
        5,
        10,
        0,
        &version,
        ts.ctx(),
    );
    compliance_service::register_rule<TEST_VOLORO, InvestorLimits>(
        &mut compliance,
        &auth,
        r5,
        &version,
        ts.ctx(),
    );

    let r6 = force_full_transfer::new<TEST_VOLORO>(&auth, false, false, &version, ts.ctx());
    compliance_service::register_rule<TEST_VOLORO, ForceFullTransfer>(
        &mut compliance,
        &auth,
        r6,
        &version,
        ts.ctx(),
    );

    let r7 = flowback_restriction::new<TEST_VOLORO>(&auth, 5_000, &version, ts.ctx());
    compliance_service::register_rule<TEST_VOLORO, FlowbackRestriction>(
        &mut compliance,
        &auth,
        r7,
        &version,
        ts.ctx(),
    );

    let r8 = lockup_restriction::new<TEST_VOLORO>(&auth, 10_000, 10_000, &version, ts.ctx());
    compliance_service::register_rule<TEST_VOLORO, LockupRestriction>(
        &mut compliance,
        &auth,
        r8,
        &version,
        ts.ctx(),
    );

    ts::return_shared(compliance);
    ts::return_shared(auth);
    ts::return_shared(version);

    // Register INVESTOR1 (US, accredited) and capture chest ID
    setup_investor(&mut ts, b"INV001", INVESTOR1, b"US");
    ts.next_tx(ADMIN);
    let inv1_chest_id = ts::most_recent_id_shared<Chest>().destroy_some();
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    registry_service::set_attribute<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV001".to_string(),
        2,
        1,
        0,
        &version,
        ts.ctx(),
    );
    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);

    // Issue 1000 to INVESTOR1
    issue_to_investor(&mut ts, INVESTOR1, 1000);

    // Register INVESTOR2 (FR/EU, accredited + qualified) and capture chest ID
    setup_investor(&mut ts, b"INV002", INVESTOR2, b"FR");
    ts.next_tx(ADMIN);
    let inv2_chest_id = ts::most_recent_id_shared<Chest>().destroy_some();
    let mut registry = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    registry_service::set_attribute<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV002".to_string(),
        2,
        1,
        0,
        &version,
        ts.ctx(),
    );
    registry_service::set_attribute<TEST_VOLORO>(
        &mut registry,
        &auth,
        b"INV002".to_string(),
        4,
        1,
        0,
        &version,
        ts.ctx(),
    );
    ts::return_shared(registry);
    ts::return_shared(auth);
    ts::return_shared(version);

    // Issue 800 to INVESTOR2
    issue_to_investor(&mut ts, INVESTOR2, 800);

    // Verify counters after issuances: total=2, us=1, accredited=2
    ts.next_tx(ADMIN);
    let investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    assert!(registry_service::get_total_investors_count(&investor_info) == 2, 100);
    assert!(registry_service::get_us_investor_count(&investor_info) == 1, 101);
    assert!(registry_service::get_accredited_investor_count(&investor_info) == 2, 102);
    ts::return_shared(investor_info);

    // === Transfer 1: INVESTOR1 → INVESTOR2 (200 tokens) ===
    // US→FR: all rules pass
    ts.next_tx(INVESTOR1);
    let treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let policy = ts.take_shared<Policy<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let mut clock = clock::create_for_testing(ts.ctx());
    clock::set_for_testing(&mut clock, 20_000);

    let mut from_chest = ts.take_shared_by_id<Chest>(inv1_chest_id);
    let to_chest = ts.take_shared_by_id<Chest>(inv2_chest_id);

    let pas_auth = chest::new_auth(ts.ctx());
    let mut request = chest::transfer_funds<TEST_VOLORO>(
        &mut from_chest,
        &pas_auth,
        &to_chest,
        200,
        ts.ctx(),
    );
    ds_token::transfer(
        &treasury,
        &mut investor_info,
        &compliance,
        &mut request,
        &version,
        &clock,
    );
    transfer_funds::resolve(request, &policy);

    clock.destroy_for_testing();
    ts::return_shared(treasury);
    ts::return_shared(investor_info);
    ts::return_shared(compliance);
    ts::return_shared(policy);
    ts::return_shared(version);
    ts::return_shared(to_chest);
    ts::return_shared(from_chest);

    // After transfer 1: INV1=800, INV2=1000

    // Add ISSUER_WALLET (special wallet) and capture chest ID
    test_helpers::add_issuer_wallet(&mut ts, ISSUER_WALLET);
    ts.next_tx(ADMIN);
    let issuer_chest_id = ts::most_recent_id_shared<Chest>().destroy_some();

    // Issue 200 to ISSUER_WALLET (special wallet: only AuthorizedSecurities checked)
    ts.next_tx(ADMIN);
    let mut treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let issuer_chest = ts.take_shared_by_id<Chest>(issuer_chest_id);
    let clock = clock::create_for_testing(ts.ctx());

    ds_token::issue_tokens(
        &mut treasury,
        &auth,
        &mut investor_info,
        &mut compliance,
        &issuer_chest,
        ISSUER_WALLET,
        200,
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
    ts::return_shared(issuer_chest);

    // === Transfer 2: INVESTOR1 → ISSUER_WALLET (800 tokens, full exit) ===
    // TO special wallet → only ForceFullTransfer checked (disabled) → passes
    // INV001 exits → total: 2→1, us: 1→0, accredited: 2→1
    ts.next_tx(INVESTOR1);
    let treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let policy = ts.take_shared<Policy<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let mut clock = clock::create_for_testing(ts.ctx());
    clock::set_for_testing(&mut clock, 20_000);

    let mut inv1_chest = ts.take_shared_by_id<Chest>(inv1_chest_id);
    let issuer_chest = ts.take_shared_by_id<Chest>(issuer_chest_id);

    let pas_auth = chest::new_auth(ts.ctx());
    let mut request = chest::transfer_funds<TEST_VOLORO>(
        &mut inv1_chest,
        &pas_auth,
        &issuer_chest,
        800,
        ts.ctx(),
    );
    ds_token::transfer(
        &treasury,
        &mut investor_info,
        &compliance,
        &mut request,
        &version,
        &clock,
    );
    transfer_funds::resolve(request, &policy);

    clock.destroy_for_testing();
    ts::return_shared(treasury);
    ts::return_shared(investor_info);
    ts::return_shared(compliance);
    ts::return_shared(policy);
    ts::return_shared(version);
    ts::return_shared(issuer_chest);
    ts::return_shared(inv1_chest);

    // After transfer 2: INV1=0, INV2=1000
    // Verify counters: total=1, us=0, accredited=1
    ts.next_tx(ADMIN);
    let investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    assert!(registry_service::get_total_investors_count(&investor_info) == 1, 200);
    assert!(registry_service::get_us_investor_count(&investor_info) == 0, 201);
    assert!(registry_service::get_accredited_investor_count(&investor_info) == 1, 202);
    ts::return_shared(investor_info);

    // === Transfer 3: INVESTOR2 → INVESTOR1 (300 tokens, re-entry for INV001) ===
    // FR→US: FlowbackRestriction end_time=5,000 < 20,000 → expired ✓
    // INV001 re-enters → total: 1→2, us: 0→1, accredited: 1→2
    ts.next_tx(INVESTOR2);
    let treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let policy = ts.take_shared<Policy<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let mut clock = clock::create_for_testing(ts.ctx());
    clock::set_for_testing(&mut clock, 20_000);

    let mut inv2_chest = ts.take_shared_by_id<Chest>(inv2_chest_id);
    let inv1_chest = ts.take_shared_by_id<Chest>(inv1_chest_id);

    let pas_auth = chest::new_auth(ts.ctx());
    let mut request = chest::transfer_funds<TEST_VOLORO>(
        &mut inv2_chest,
        &pas_auth,
        &inv1_chest,
        300,
        ts.ctx(),
    );
    ds_token::transfer(
        &treasury,
        &mut investor_info,
        &compliance,
        &mut request,
        &version,
        &clock,
    );
    transfer_funds::resolve(request, &policy);

    clock.destroy_for_testing();
    ts::return_shared(treasury);
    ts::return_shared(investor_info);
    ts::return_shared(compliance);
    ts::return_shared(policy);
    ts::return_shared(version);
    ts::return_shared(inv2_chest);
    ts::return_shared(inv1_chest);

    // After transfer 3: INV1(INVESTOR1)=300, INV2=700

    // Add INVESTOR1_WALLET2 (second wallet for INV001) and capture chest ID
    test_helpers::add_investor_wallet(&mut ts, b"INV001", INVESTOR1_WALLET2);
    ts.next_tx(ADMIN);
    let wallet2_chest_id = ts::most_recent_id_shared<Chest>().destroy_some();

    // === Transfer 4: INVESTOR1 → INVESTOR1_WALLET2 (100 tokens, same investor) ===
    // Same investor → skip all compliance rules
    ts.next_tx(INVESTOR1);
    let treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let policy = ts.take_shared<Policy<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let mut clock = clock::create_for_testing(ts.ctx());
    clock::set_for_testing(&mut clock, 20_000);

    let mut inv1_chest = ts.take_shared_by_id<Chest>(inv1_chest_id);
    let wallet2_chest = ts.take_shared_by_id<Chest>(wallet2_chest_id);

    let pas_auth = chest::new_auth(ts.ctx());
    let mut request = chest::transfer_funds<TEST_VOLORO>(
        &mut inv1_chest,
        &pas_auth,
        &wallet2_chest,
        100,
        ts.ctx(),
    );
    ds_token::transfer(
        &treasury,
        &mut investor_info,
        &compliance,
        &mut request,
        &version,
        &clock,
    );
    transfer_funds::resolve(request, &policy);

    clock.destroy_for_testing();
    ts::return_shared(treasury);
    ts::return_shared(investor_info);
    ts::return_shared(compliance);
    ts::return_shared(policy);
    ts::return_shared(version);
    ts::return_shared(wallet2_chest);
    ts::return_shared(inv1_chest);

    // ==================== Final Verification ====================

    ts.next_tx(ADMIN);
    let investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();

    // Per-wallet balances
    assert!(
        registry_service::investor_wallet_balance<TEST_VOLORO>(&investor_info, INVESTOR1) == 200,
        0,
    );
    assert!(
        registry_service::investor_wallet_balance<TEST_VOLORO>(&investor_info, INVESTOR1_WALLET2) == 100,
        1,
    );
    assert!(
        registry_service::investor_wallet_balance<TEST_VOLORO>(&investor_info, INVESTOR2) == 700,
        2,
    );

    // Total investor balances
    assert!(
        registry_service::investor_wallet_balance_total<TEST_VOLORO>(&investor_info, b"INV001".to_string()) == 300,
        3,
    );
    assert!(
        registry_service::investor_wallet_balance_total<TEST_VOLORO>(&investor_info, b"INV002".to_string()) == 700,
        4,
    );

    // Investor counters
    assert!(registry_service::get_total_investors_count(&investor_info) == 2, 5);
    assert!(registry_service::get_us_investor_count(&investor_info) == 1, 6);
    assert!(registry_service::get_accredited_investor_count(&investor_info) == 2, 7);
    assert!(registry_service::get_jp_investor_count(&investor_info) == 0, 8);

    ts::return_shared(investor_info);
    ts.end();
}
