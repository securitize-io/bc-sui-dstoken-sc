#[test_only]
module securitize::ds_token_tests;

use pas::{
    chest::{Self, Chest},
    namespace::Namespace,
    policy::Policy,
    send_funds,
    templates::Templates
};
use ptb::ptb::{Self, Command};
use securitize::{
    compliance_service::{Self, ComplianceConfig},
    ds_token::{Self, Treasury},
    lock_manager,
    registry_service::{Self, InvestorInfo},
    test_helpers::{Self, TEST_VOLORO},
    trust_service::Auth,
    version::Version
};
use std::string::String;
use sui::{
    balance::Balance,
    clock,
    coin_registry::{Self, Currency},
    test_scenario::{Self as ts, Scenario}
};

const ADMIN: address = @0x001;
const UNAUTHORIZED: address = @0x002;
const INVESTOR1: address = @0x101;
const INVESTOR2: address = @0x102;
const ISSUER_WALLET: address = @0x201;
const PLATFORM_WALLET: address = @0x301;

// ==================== Setup Helpers ====================

/// Full setup with Treasury using the TEST_VOLORO pattern
fun setup_full(ts: &mut Scenario) {
    test_helpers::setup_with_treasury(ts);
}

/// Setup investor with country and wallet.
/// Note: register_investor_with_wallet automatically creates the chest.
fun setup_investor(
    ts: &mut Scenario,
    investor_id: vector<u8>,
    wallet: address,
    country: vector<u8>,
) {
    test_helpers::register_investor_with_wallet(ts, investor_id, wallet);
    test_helpers::set_investor_country(ts, investor_id, country);
}

// ==================== Pause/Unpause Tests ====================

#[test]
fun test_pause_treasury() {
    let mut ts = ts::begin(ADMIN);
    setup_full(&mut ts);

    ts.next_tx(ADMIN);
    let mut treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    assert!(!ds_token::is_paused(&treasury), 0);

    ds_token::pause(&mut treasury, &auth, &version, ts.ctx());
    assert!(ds_token::is_paused(&treasury), 1);

    ts::return_shared(treasury);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_unpause_treasury() {
    let mut ts = ts::begin(ADMIN);
    setup_full(&mut ts);

    ts.next_tx(ADMIN);
    let mut treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    // First pause
    ds_token::pause(&mut treasury, &auth, &version, ts.ctx());
    assert!(ds_token::is_paused(&treasury), 0);

    // Then unpause
    ds_token::unpause(&mut treasury, &auth, &version, ts.ctx());
    assert!(!ds_token::is_paused(&treasury), 1);

    ts::return_shared(treasury);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = ds_token::ENotAuthorized)]
fun test_pause_unauthorized() {
    let mut ts = ts::begin(ADMIN);
    setup_full(&mut ts);

    // Try to pause from unauthorized address
    ts.next_tx(UNAUTHORIZED);
    let mut treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    ds_token::pause(&mut treasury, &auth, &version, ts.ctx());

    ts::return_shared(treasury);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = ds_token::ENotAuthorized)]
fun test_unpause_unauthorized() {
    let mut ts = ts::begin(ADMIN);
    setup_full(&mut ts);

    ts.next_tx(ADMIN);
    let mut treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    // Pause as admin
    ds_token::pause(&mut treasury, &auth, &version, ts.ctx());

    ts::return_shared(treasury);
    ts::return_shared(auth);
    ts::return_shared(version);

    // Try to unpause from unauthorized address
    ts.next_tx(UNAUTHORIZED);
    let mut treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    ds_token::unpause(&mut treasury, &auth, &version, ts.ctx());

    ts::return_shared(treasury);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = ds_token::ETreasuryAlreadyPaused)]
fun test_pause_already_paused() {
    let mut ts = ts::begin(ADMIN);
    setup_full(&mut ts);

    ts.next_tx(ADMIN);
    let mut treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    // Pause once
    ds_token::pause(&mut treasury, &auth, &version, ts.ctx());

    // Try to pause again - should fail
    ds_token::pause(&mut treasury, &auth, &version, ts.ctx());

    ts::return_shared(treasury);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = ds_token::ETreasuryNotPaused)]
fun test_unpause_not_paused() {
    let mut ts = ts::begin(ADMIN);
    setup_full(&mut ts);

    ts.next_tx(ADMIN);
    let mut treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    // Try to unpause when not paused - should fail
    ds_token::unpause(&mut treasury, &auth, &version, ts.ctx());

    ts::return_shared(treasury);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

// ==================== Issuance Tests ====================

#[test]
fun test_issue_tokens_to_us_investor() {
    let mut ts = ts::begin(ADMIN);
    setup_full(&mut ts);

    // Register investor with US country (chest is created automatically)
    setup_investor(&mut ts, b"INV001", INVESTOR1, b"USΑ");

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
        b"".to_string(),
        &version,
        vector[],
        vector[],
        clock.timestamp_ms(),
        &clock,
        ts.ctx(),
    );

    // Verify investor balance after issuance
    let investor_id = b"INV001".to_string();
    let balance = registry_service::investor_wallet_balance_total(&investor_info, investor_id);
    assert!(balance == 500, 0);

    // Verify investor counters after issuance (new investor added)
    let total_investors = registry_service::get_total_investors_count(&investor_info);
    assert!(total_investors == 1, 1);

    clock::destroy_for_testing(clock);
    ts::return_shared(treasury);
    ts::return_shared(auth);
    ts::return_shared(investor_info);
    ts::return_shared(compliance);
    ts::return_shared(version);
    ts::return_shared(chest);
    ts.end();
}

#[test]
#[expected_failure(abort_code = ds_token::ENotAuthorized)]
fun test_issue_tokens_unauthorized() {
    let mut ts = ts::begin(ADMIN);
    setup_full(&mut ts);

    // Register investor (chest is created automatically)
    setup_investor(&mut ts, b"INV001", INVESTOR1, b"US");

    // Try to issue from unauthorized address
    ts.next_tx(UNAUTHORIZED);
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
        b"".to_string(),
        &version,
        vector[],
        vector[],
        clock.timestamp_ms(),
        &clock,
        ts.ctx(),
    );

    clock::destroy_for_testing(clock);
    ts::return_shared(treasury);
    ts::return_shared(auth);
    ts::return_shared(investor_info);
    ts::return_shared(compliance);
    ts::return_shared(version);
    ts::return_shared(chest);
    ts.end();
}

#[test]
#[expected_failure(abort_code = ds_token::EValueZero)]
fun test_issue_zero_tokens() {
    let mut ts = ts::begin(ADMIN);
    setup_full(&mut ts);

    // Register investor (chest is created automatically)
    setup_investor(&mut ts, b"INV001", INVESTOR1, b"US");

    ts.next_tx(ADMIN);
    let mut treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let chest = ts.take_shared<Chest>();
    let clock = clock::create_for_testing(ts.ctx());

    // Try to issue 0 tokens - should fail
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

    clock::destroy_for_testing(clock);
    ts::return_shared(treasury);
    ts::return_shared(auth);
    ts::return_shared(investor_info);
    ts::return_shared(compliance);
    ts::return_shared(version);
    ts::return_shared(chest);
    ts.end();
}

#[test]
#[expected_failure(abort_code = ds_token::EChestOwnerMismatch)]
fun test_issue_tokens_chest_owner_mismatch() {
    let mut ts = ts::begin(ADMIN);
    setup_full(&mut ts);

    // Register investor (chest is created automatically)
    setup_investor(&mut ts, b"INV001", INVESTOR1, b"US");

    ts.next_tx(ADMIN);
    let mut treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let chest = ts.take_shared<Chest>();
    let clock = clock::create_for_testing(ts.ctx());

    // Try to issue to wrong address (chest belongs to INVESTOR1, but we pass INVESTOR2)
    ds_token::issue_tokens(
        &mut treasury,
        &auth,
        &mut investor_info,
        &mut compliance,
        &chest,
        INVESTOR2, // Wrong address!
        500,
        0,
        b"".to_string(),
        &version,
        vector[],
        vector[],
        clock.timestamp_ms(),
        &clock,
        ts.ctx(),
    );

    clock::destroy_for_testing(clock);
    ts::return_shared(treasury);
    ts::return_shared(auth);
    ts::return_shared(investor_info);
    ts::return_shared(compliance);
    ts::return_shared(version);
    ts::return_shared(chest);
    ts.end();
}

#[test]
#[expected_failure(abort_code = ds_token::EInvalidLengthOfParameters)]
fun test_issue_tokens_mismatched_lock_arrays() {
    let mut ts = ts::begin(ADMIN);
    setup_full(&mut ts);

    // Register investor (chest is created automatically)
    setup_investor(&mut ts, b"INV001", INVESTOR1, b"US");

    ts.next_tx(ADMIN);
    let mut treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let chest = ts.take_shared<Chest>();
    let clock = clock::create_for_testing(ts.ctx());

    // Mismatched arrays: 2 locked values but only 1 release time
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
        vector[100, 200], // 2 elements
        vector[1000], // 1 element - mismatch!
        clock.timestamp_ms(),
        &clock,
        ts.ctx(),
    );

    clock::destroy_for_testing(clock);
    ts::return_shared(treasury);
    ts::return_shared(auth);
    ts::return_shared(investor_info);
    ts::return_shared(compliance);
    ts::return_shared(version);
    ts::return_shared(chest);
    ts.end();
}

#[test]
#[expected_failure(abort_code = ds_token::EValueLockedLargerThanValue)]
fun test_issue_tokens_locked_exceeds_value() {
    let mut ts = ts::begin(ADMIN);
    setup_full(&mut ts);

    // Register investor (chest is created automatically)
    setup_investor(&mut ts, b"INV001", INVESTOR1, b"USA");

    ts.next_tx(ADMIN);
    let mut treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let chest = ts.take_shared<Chest>();
    let clock = clock::create_for_testing(ts.ctx());

    // Locked value (600) exceeds issue value (500)
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
        vector[600], // More than 500!
        vector[clock.timestamp_ms() + 1000],
        clock.timestamp_ms(),
        &clock,
        ts.ctx(),
    );

    clock::destroy_for_testing(clock);
    ts::return_shared(treasury);
    ts::return_shared(auth);
    ts::return_shared(investor_info);
    ts::return_shared(compliance);
    ts::return_shared(version);
    ts::return_shared(chest);
    ts.end();
}

#[test]
fun test_issue_tokens_with_partial_lock() {
    let mut ts = ts::begin(ADMIN);
    setup_full(&mut ts);

    // Register investor (chest is created automatically)
    setup_investor(&mut ts, b"INV001", INVESTOR1, b"US");

    ts.next_tx(ADMIN);
    let mut treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let chest = ts.take_shared<Chest>();
    let clock = clock::create_for_testing(ts.ctx());

    // Issue 500 with 200 locked
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
        vector[200],
        vector[clock.timestamp_ms() + test_helpers::one_year_ms()],
        clock.timestamp_ms(),
        &clock,
        ts.ctx(),
    );

    // Verify total balance is 500
    let investor_id = b"INV001".to_string();
    let balance = registry_service::investor_wallet_balance_total(&investor_info, investor_id);
    assert!(balance == 500, 0);

    // Verify 200 is locked, so only 300 is transferable
    let transferable = lock_manager::compute_transferable(
        &investor_info,
        investor_id,
        balance,
        clock.timestamp_ms(),
    );
    assert!(transferable == 300, 1);

    // Verify there is 1 lock
    let lock_count = lock_manager::lock_count(&investor_info, investor_id);
    assert!(lock_count == 1, 2);

    clock::destroy_for_testing(clock);
    ts::return_shared(treasury);
    ts::return_shared(auth);
    ts::return_shared(investor_info);
    ts::return_shared(compliance);
    ts::return_shared(version);
    ts::return_shared(chest);
    ts.end();
}

#[test]
fun test_issue_tokens_with_full_lock() {
    let mut ts = ts::begin(ADMIN);
    setup_full(&mut ts);

    // Register investor (chest is created automatically)
    setup_investor(&mut ts, b"INV001", INVESTOR1, b"US");

    ts.next_tx(ADMIN);
    let mut treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let chest = ts.take_shared<Chest>();
    let clock = clock::create_for_testing(ts.ctx());

    // Issue 500 with all 500 locked
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
        vector[500],
        vector[clock.timestamp_ms() + test_helpers::one_year_ms()],
        clock.timestamp_ms(),
        &clock,
        ts.ctx(),
    );

    // Verify total balance is 500
    let investor_id = b"INV001".to_string();
    let balance = registry_service::investor_wallet_balance_total(&investor_info, investor_id);
    assert!(balance == 500, 0);

    // Verify all 500 is locked, so 0 is transferable
    let transferable = lock_manager::compute_transferable(
        &investor_info,
        investor_id,
        balance,
        clock.timestamp_ms(),
    );
    assert!(transferable == 0, 1);

    // Verify there is 1 lock
    let lock_count = lock_manager::lock_count(&investor_info, investor_id);
    assert!(lock_count == 1, 2);

    clock::destroy_for_testing(clock);
    ts::return_shared(treasury);
    ts::return_shared(auth);
    ts::return_shared(investor_info);
    ts::return_shared(compliance);
    ts::return_shared(version);
    ts::return_shared(chest);
    ts.end();
}

#[test]
fun test_issue_tokens_multiple_investors() {
    let mut ts = ts::begin(ADMIN);
    setup_full(&mut ts);

    // Register first investor
    setup_investor(&mut ts, b"INV001", INVESTOR1, b"US");

    // Issue to first investor
    ts.next_tx(ADMIN);
    let mut treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let chest1 = ts.take_shared<Chest>();
    let clock = clock::create_for_testing(ts.ctx());

    ds_token::issue_tokens(
        &mut treasury,
        &auth,
        &mut investor_info,
        &mut compliance,
        &chest1,
        INVESTOR1,
        500,
        0,
        b"".to_string(),
        &version,
        vector[],
        vector[],
        clock.timestamp_ms(),
        &clock,
        ts.ctx(),
    );

    clock::destroy_for_testing(clock);
    ts::return_shared(treasury);
    ts::return_shared(auth);
    ts::return_shared(investor_info);
    ts::return_shared(compliance);
    ts::return_shared(version);
    ts::return_shared(chest1);

    // Register second investor
    setup_investor(&mut ts, b"INV002", INVESTOR2, b"FR");

    // Issue to second investor
    ts.next_tx(ADMIN);
    let mut treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let chest2 = ts.take_shared<Chest>();
    let clock = clock::create_for_testing(ts.ctx());

    ds_token::issue_tokens(
        &mut treasury,
        &auth,
        &mut investor_info,
        &mut compliance,
        &chest2,
        INVESTOR2,
        750,
        0,
        b"".to_string(),
        &version,
        vector[],
        vector[],
        clock.timestamp_ms(),
        &clock,
        ts.ctx(),
    );

    // Verify both investors have correct balances
    let investor1_id = b"INV001".to_string();
    let investor2_id = b"INV002".to_string();
    let balance1 = registry_service::investor_wallet_balance_total(&investor_info, investor1_id);
    let balance2 = registry_service::investor_wallet_balance_total(&investor_info, investor2_id);
    assert!(balance1 == 500, 0);
    assert!(balance2 == 750, 1);

    // Verify investor counters (2 investors now)
    let total_investors = registry_service::get_total_investors_count(&investor_info);
    assert!(total_investors == 2, 2);

    clock::destroy_for_testing(clock);
    ts::return_shared(treasury);
    ts::return_shared(auth);
    ts::return_shared(investor_info);
    ts::return_shared(compliance);
    ts::return_shared(version);
    ts::return_shared(chest2);
    ts.end();
}

// ==================== Burn Tests ====================

#[test]
fun test_burn_tokens() {
    let mut ts = ts::begin(ADMIN);
    setup_full(&mut ts);

    // Register investor and issue tokens (chest is created automatically)
    setup_investor(&mut ts, b"INV001", INVESTOR1, b"US");

    // Issue tokens first
    ts.next_tx(ADMIN);
    let mut treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let policy = ts.take_shared<Policy<Balance<TEST_VOLORO>>>();
    let version = ts.take_shared<Version>();
    let mut chest = ts.take_shared<Chest>();
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
        b"".to_string(),
        &version,
        vector[],
        vector[],
        clock.timestamp_ms(),
        &clock,
        ts.ctx(),
    );

    // Verify balance before burn
    let investor_id = b"INV001".to_string();
    let balance_before = registry_service::investor_wallet_balance_total(
        &investor_info,
        investor_id,
    );
    assert!(balance_before == 500, 0);

    // Verify investor count before burn
    let total_before = registry_service::get_total_investors_count(&investor_info);
    assert!(total_before == 1, 1);

    // Now burn some tokens (partial burn - investor still has balance)
    let request = chest.clawback_balance<TEST_VOLORO>(50, ts.ctx());
    ds_token::burn(
        &mut treasury,
        &auth,
        &mut investor_info,
        &policy,
        request,
        b"test burn".to_string(),
        &version,
        ts.ctx(),
    );

    // Verify balance after burn (500 - 50 = 450)
    let balance_after = registry_service::investor_wallet_balance_total(
        &investor_info,
        investor_id,
    );
    assert!(balance_after == 450, 2);

    // Verify investor count unchanged (partial burn, investor still has tokens)
    let total_after = registry_service::get_total_investors_count(&investor_info);
    assert!(total_after == 1, 3);

    clock::destroy_for_testing(clock);
    ts::return_shared(treasury);
    ts::return_shared(auth);
    ts::return_shared(investor_info);
    ts::return_shared(compliance);
    ts::return_shared(policy);
    ts::return_shared(version);
    ts::return_shared(chest);
    ts.end();
}

#[test]
#[expected_failure(abort_code = ds_token::ENotAuthorized)]
fun test_burn_unauthorized() {
    let mut ts = ts::begin(ADMIN);
    setup_full(&mut ts);

    // Register investor and issue tokens (chest is created automatically)
    setup_investor(&mut ts, b"INV001", INVESTOR1, b"US");

    // Issue tokens first
    ts.next_tx(ADMIN);
    let mut treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let policy = ts.take_shared<Policy<Balance<TEST_VOLORO>>>();
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
        b"".to_string(),
        &version,
        vector[],
        vector[],
        clock.timestamp_ms(),
        &clock,
        ts.ctx(),
    );

    clock::destroy_for_testing(clock);
    ts::return_shared(treasury);
    ts::return_shared(auth);
    ts::return_shared(investor_info);
    ts::return_shared(compliance);
    ts::return_shared(version);
    ts::return_shared(chest);

    // Try to burn from unauthorized address
    ts.next_tx(UNAUTHORIZED);
    let mut treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let mut chest = ts.take_shared<Chest>();

    let request = chest.clawback_balance<TEST_VOLORO>(50, ts.ctx());
    ds_token::burn(
        &mut treasury,
        &auth,
        &mut investor_info,
        &policy,
        request,
        b"unauthorized burn".to_string(),
        &version,
        ts.ctx(),
    );

    ts::return_shared(treasury);
    ts::return_shared(auth);
    ts::return_shared(investor_info);
    ts::return_shared(policy);
    ts::return_shared(version);
    ts::return_shared(chest);
    ts.end();
}

// ==================== Seize Tests ====================

#[test]
fun test_seize_tokens() {
    let mut ts = ts::begin(ADMIN);
    setup_full(&mut ts);

    // Register investor (chest is created automatically)
    setup_investor(&mut ts, b"INV001", INVESTOR1, b"US");
    ts.next_tx(ADMIN);
    let inv1_chest_id = ts::most_recent_id_shared<Chest>().destroy_some();

    // Issue tokens first (before adding issuer wallet to avoid chest ordering issues)
    ts.next_tx(ADMIN);
    let mut treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let investor_chest = ts.take_shared<Chest>(); // only 1 chest at this point
    let clock = clock::create_for_testing(ts.ctx());

    ds_token::issue_tokens(
        &mut treasury,
        &auth,
        &mut investor_info,
        &mut compliance,
        &investor_chest,
        INVESTOR1,
        500,
        0,
        b"".to_string(),
        &version,
        vector[],
        vector[],
        clock.timestamp_ms(),
        &clock,
        ts.ctx(),
    );

    clock::destroy_for_testing(clock);
    ts::return_shared(treasury);
    ts::return_shared(auth);
    ts::return_shared(investor_info);
    ts::return_shared(compliance);
    ts::return_shared(version);
    ts::return_shared(investor_chest);

    // Add issuer wallet (chest is created automatically by add_issuer_wallet)
    test_helpers::add_issuer_wallet(&mut ts, ISSUER_WALLET);
    ts.next_tx(ADMIN);
    let issuer_chest_id = ts::most_recent_id_shared<Chest>().destroy_some();

    // Now seize tokens
    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let policy = ts.take_shared<Policy<Balance<TEST_VOLORO>>>();
    let version = ts.take_shared<Version>();
    let issuer_chest = ts.take_shared_by_id<Chest>(issuer_chest_id);
    let mut investor_chest = ts.take_shared_by_id<Chest>(inv1_chest_id);

    // Verify balance before seize
    let investor_id = b"INV001".to_string();
    let balance_before = registry_service::investor_wallet_balance_total(
        &investor_info,
        investor_id,
    );
    assert!(balance_before == 500, 0);

    // Verify investor count before seize
    let total_before = registry_service::get_total_investors_count(&investor_info);
    assert!(total_before == 1, 1);

    // Seize tokens (partial seize - investor still has balance)
    let request = investor_chest.clawback_balance<TEST_VOLORO>(50, ts.ctx());
    ds_token::seize(
        &auth,
        &mut investor_info,
        &policy,
        request,
        &issuer_chest,
        ISSUER_WALLET,
        b"seize reason".to_string(),
        &version,
        ts.ctx(),
    );

    // Verify balance after seize (500 - 50 = 450)
    let balance_after = registry_service::investor_wallet_balance_total(
        &investor_info,
        investor_id,
    );
    assert!(balance_after == 450, 2);

    // Verify investor count unchanged (partial seize, investor still has tokens)
    let total_after = registry_service::get_total_investors_count(&investor_info);
    assert!(total_after == 1, 3);

    ts::return_shared(auth);
    ts::return_shared(investor_info);
    ts::return_shared(policy);
    ts::return_shared(version);
    ts::return_shared(investor_chest);
    ts::return_shared(issuer_chest);
    ts.end();
}

#[test]
#[expected_failure(abort_code = ds_token::ENotAuthorized)]
fun test_seize_unauthorized() {
    let mut ts = ts::begin(ADMIN);
    setup_full(&mut ts);

    // Register investor (chest is created automatically)
    setup_investor(&mut ts, b"INV001", INVESTOR1, b"US");
    ts.next_tx(ADMIN);
    let inv1_chest_id = ts::most_recent_id_shared<Chest>().destroy_some();

    // Issue tokens first (before adding issuer wallet to avoid chest ordering issues)
    ts.next_tx(ADMIN);
    let mut treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let policy = ts.take_shared<Policy<Balance<TEST_VOLORO>>>();
    let version = ts.take_shared<Version>();
    let chest = ts.take_shared<Chest>(); // only 1 chest at this point
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
        b"".to_string(),
        &version,
        vector[],
        vector[],
        clock.timestamp_ms(),
        &clock,
        ts.ctx(),
    );

    clock::destroy_for_testing(clock);
    ts::return_shared(treasury);
    ts::return_shared(auth);
    ts::return_shared(investor_info);
    ts::return_shared(compliance);
    ts::return_shared(policy);
    ts::return_shared(version);
    ts::return_shared(chest);

    // Add issuer wallet (chest is created automatically by add_issuer_wallet)
    test_helpers::add_issuer_wallet(&mut ts, ISSUER_WALLET);
    ts.next_tx(ADMIN);
    let issuer_chest_id = ts::most_recent_id_shared<Chest>().destroy_some();

    // Try to seize from unauthorized address
    ts.next_tx(UNAUTHORIZED);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let policy = ts.take_shared<Policy<Balance<TEST_VOLORO>>>();
    let version = ts.take_shared<Version>();
    let issuer_chest = ts.take_shared_by_id<Chest>(issuer_chest_id);
    let mut investor_chest = ts.take_shared_by_id<Chest>(inv1_chest_id);

    let request = investor_chest.clawback_balance<TEST_VOLORO>(50, ts.ctx());
    ds_token::seize(
        &auth,
        &mut investor_info,
        &policy,
        request,
        &issuer_chest,
        ISSUER_WALLET,
        b"unauthorized seize".to_string(),
        &version,
        ts.ctx(),
    );

    ts::return_shared(auth);
    ts::return_shared(investor_info);
    ts::return_shared(policy);
    ts::return_shared(version);
    ts::return_shared(investor_chest);
    ts::return_shared(issuer_chest);
    ts.end();
}

#[test]
#[expected_failure(abort_code = compliance_service::ENotIssuerWallet)]
fun test_seize_to_non_issuer_wallet() {
    let mut ts = ts::begin(ADMIN);
    setup_full(&mut ts);

    // Register first investor and issue tokens
    setup_investor(&mut ts, b"INV001", INVESTOR1, b"US");
    ts.next_tx(ADMIN);
    let inv1_chest_id = ts::most_recent_id_shared<Chest>().destroy_some();

    // Issue tokens to INVESTOR1
    ts.next_tx(ADMIN);
    let mut treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let policy = ts.take_shared<Policy<Balance<TEST_VOLORO>>>();
    let version = ts.take_shared<Version>();
    let chest1 = ts.take_shared<Chest>(); // only 1 chest at this point
    let clock = clock::create_for_testing(ts.ctx());

    ds_token::issue_tokens(
        &mut treasury,
        &auth,
        &mut investor_info,
        &mut compliance,
        &chest1,
        INVESTOR1,
        500,
        0,
        b"".to_string(),
        &version,
        vector[],
        vector[],
        clock.timestamp_ms(),
        &clock,
        ts.ctx(),
    );

    clock::destroy_for_testing(clock);
    ts::return_shared(treasury);
    ts::return_shared(auth);
    ts::return_shared(investor_info);
    ts::return_shared(compliance);
    ts::return_shared(policy);
    ts::return_shared(version);
    ts::return_shared(chest1);

    // Register second investor (this creates INVESTOR2's chest)
    setup_investor(&mut ts, b"INV002", INVESTOR2, b"US");
    ts.next_tx(ADMIN);
    let inv2_chest_id = ts::most_recent_id_shared<Chest>().destroy_some();

    // Now try to seize from INVESTOR1 to INVESTOR2 (who is not an issuer wallet)
    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let policy = ts.take_shared<Policy<Balance<TEST_VOLORO>>>();
    let version = ts.take_shared<Version>();
    let chest2 = ts.take_shared_by_id<Chest>(inv2_chest_id);
    let mut chest1 = ts.take_shared_by_id<Chest>(inv1_chest_id);

    // Try to seize to a non-issuer wallet (INVESTOR2) - should fail with ENotIssuerWallet
    let request = chest1.clawback_balance<TEST_VOLORO>(50, ts.ctx());
    ds_token::seize(
        &auth,
        &mut investor_info,
        &policy,
        request,
        &chest2,
        INVESTOR2, // Not an issuer wallet!
        b"invalid seize".to_string(),
        &version,
        ts.ctx(),
    );

    ts::return_shared(auth);
    ts::return_shared(investor_info);
    ts::return_shared(policy);
    ts::return_shared(version);
    ts::return_shared(chest1);
    ts::return_shared(chest2);
    ts.end();
}

// ==================== Issuance Helper Tests ====================

#[test]
fun test_new_issuance_record() {
    let issuance = registry_service::new_issuance(1000, 1640000000000);
    assert!(registry_service::issuance_amount(&issuance) == 1000, 0);
    assert!(registry_service::issuance_time_ms(&issuance) == 1640000000000, 1);
}

// ==================== Special Wallet Balance Tests ====================

#[test]
fun test_issue_tokens_to_platform_wallet_updates_balance() {
    let mut ts = ts::begin(ADMIN);
    setup_full(&mut ts);

    // Add platform wallet (chest is created automatically)
    test_helpers::add_platform_wallet(&mut ts, PLATFORM_WALLET);

    ts.next_tx(ADMIN);
    let mut treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let chest = ts.take_shared<Chest>();
    let clock = clock::create_for_testing(ts.ctx());

    // Verify initial balance is 0
    assert!(registry_service::special_wallet_balance(&investor_info, PLATFORM_WALLET) == 0, 0);

    // Issue tokens to platform wallet
    ds_token::issue_tokens(
        &mut treasury,
        &auth,
        &mut investor_info,
        &mut compliance,
        &chest,
        PLATFORM_WALLET,
        500,
        0,
        b"".to_string(),
        &version,
        vector[],
        vector[],
        clock.timestamp_ms(),
        &clock,
        ts.ctx(),
    );

    // Verify platform wallet balance is updated
    assert!(registry_service::special_wallet_balance(&investor_info, PLATFORM_WALLET) == 500, 1);

    clock::destroy_for_testing(clock);
    ts::return_shared(treasury);
    ts::return_shared(auth);
    ts::return_shared(investor_info);
    ts::return_shared(compliance);
    ts::return_shared(version);
    ts::return_shared(chest);
    ts.end();
}

#[test]
fun test_issue_tokens_to_issuer_wallet_updates_balance() {
    let mut ts = ts::begin(ADMIN);
    setup_full(&mut ts);

    // Add issuer wallet (chest is created automatically)
    test_helpers::add_issuer_wallet(&mut ts, ISSUER_WALLET);

    ts.next_tx(ADMIN);
    let mut treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let chest = ts.take_shared<Chest>();
    let clock = clock::create_for_testing(ts.ctx());

    // Verify initial balance is 0
    assert!(registry_service::special_wallet_balance(&investor_info, ISSUER_WALLET) == 0, 0);

    // Issue tokens to issuer wallet
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

    // Verify issuer wallet balance is updated
    assert!(registry_service::special_wallet_balance(&investor_info, ISSUER_WALLET) == 1000, 1);

    clock::destroy_for_testing(clock);
    ts::return_shared(treasury);
    ts::return_shared(auth);
    ts::return_shared(investor_info);
    ts::return_shared(compliance);
    ts::return_shared(version);
    ts::return_shared(chest);
    ts.end();
}

#[test]
fun test_burn_from_platform_wallet_updates_balance() {
    let mut ts = ts::begin(ADMIN);
    setup_full(&mut ts);

    // Add platform wallet (chest is created automatically)
    test_helpers::add_platform_wallet(&mut ts, PLATFORM_WALLET);

    // Issue tokens to platform wallet first
    ts.next_tx(ADMIN);
    let mut treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let policy = ts.take_shared<Policy<Balance<TEST_VOLORO>>>();
    let version = ts.take_shared<Version>();
    let mut chest = ts.take_shared<Chest>();
    let clock = clock::create_for_testing(ts.ctx());

    ds_token::issue_tokens(
        &mut treasury,
        &auth,
        &mut investor_info,
        &mut compliance,
        &chest,
        PLATFORM_WALLET,
        500,
        0,
        b"".to_string(),
        &version,
        vector[],
        vector[],
        clock.timestamp_ms(),
        &clock,
        ts.ctx(),
    );

    // Verify balance after issuance
    assert!(registry_service::special_wallet_balance(&investor_info, PLATFORM_WALLET) == 500, 0);

    // Burn some tokens from platform wallet
    let request = chest.clawback_balance<TEST_VOLORO>(200, ts.ctx());
    ds_token::burn(
        &mut treasury,
        &auth,
        &mut investor_info,
        &policy,
        request,
        b"burn from platform".to_string(),
        &version,
        ts.ctx(),
    );

    // Verify platform wallet balance is reduced
    assert!(registry_service::special_wallet_balance(&investor_info, PLATFORM_WALLET) == 300, 1);

    clock::destroy_for_testing(clock);
    ts::return_shared(treasury);
    ts::return_shared(auth);
    ts::return_shared(investor_info);
    ts::return_shared(compliance);
    ts::return_shared(policy);
    ts::return_shared(version);
    ts::return_shared(chest);
    ts.end();
}

#[test]
fun test_seize_to_issuer_wallet_updates_balance() {
    let mut ts = ts::begin(ADMIN);
    setup_full(&mut ts);

    // Register investor and issue tokens
    setup_investor(&mut ts, b"INV001", INVESTOR1, b"US");
    ts.next_tx(ADMIN);
    let inv_chest_id = ts::most_recent_id_shared<Chest>().destroy_some();

    ts.next_tx(ADMIN);
    let mut treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let investor_chest = ts.take_shared<Chest>();
    let clock = clock::create_for_testing(ts.ctx());

    ds_token::issue_tokens(
        &mut treasury,
        &auth,
        &mut investor_info,
        &mut compliance,
        &investor_chest,
        INVESTOR1,
        500,
        0,
        b"".to_string(),
        &version,
        vector[],
        vector[],
        clock.timestamp_ms(),
        &clock,
        ts.ctx(),
    );

    clock::destroy_for_testing(clock);
    ts::return_shared(treasury);
    ts::return_shared(auth);
    ts::return_shared(investor_info);
    ts::return_shared(compliance);
    ts::return_shared(version);
    ts::return_shared(investor_chest);

    // Add issuer wallet
    test_helpers::add_issuer_wallet(&mut ts, ISSUER_WALLET);
    ts.next_tx(ADMIN);
    let issuer_chest_id = ts::most_recent_id_shared<Chest>().destroy_some();

    // Seize tokens from investor to issuer wallet
    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let policy = ts.take_shared<Policy<Balance<TEST_VOLORO>>>();
    let version = ts.take_shared<Version>();
    let issuer_chest = ts.take_shared_by_id<Chest>(issuer_chest_id);
    let mut investor_chest = ts.take_shared_by_id<Chest>(inv_chest_id);

    // Verify issuer wallet balance is 0 initially
    assert!(registry_service::special_wallet_balance(&investor_info, ISSUER_WALLET) == 0, 0);

    let request = investor_chest.clawback_balance<TEST_VOLORO>(150, ts.ctx());
    ds_token::seize(
        &auth,
        &mut investor_info,
        &policy,
        request,
        &issuer_chest,
        ISSUER_WALLET,
        b"seize to issuer".to_string(),
        &version,
        ts.ctx(),
    );

    // Verify issuer wallet balance is updated
    assert!(registry_service::special_wallet_balance(&investor_info, ISSUER_WALLET) == 150, 1);

    // Verify investor balance is reduced
    let investor_id = b"INV001".to_string();
    let investor_balance = registry_service::investor_wallet_balance_total(
        &investor_info,
        investor_id,
    );
    assert!(investor_balance == 350, 2);

    ts::return_shared(auth);
    ts::return_shared(investor_info);
    ts::return_shared(policy);
    ts::return_shared(version);
    ts::return_shared(investor_chest);
    ts::return_shared(issuer_chest);
    ts.end();
}

#[test]
fun test_seize_from_platform_wallet_updates_balance() {
    let mut ts = ts::begin(ADMIN);
    setup_full(&mut ts);

    // Add platform wallet and issue tokens to it
    test_helpers::add_platform_wallet(&mut ts, PLATFORM_WALLET);
    ts.next_tx(ADMIN);
    let platform_chest_id = ts::most_recent_id_shared<Chest>().destroy_some();

    ts.next_tx(ADMIN);
    let mut treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let platform_chest = ts.take_shared<Chest>();
    let clock = clock::create_for_testing(ts.ctx());

    ds_token::issue_tokens(
        &mut treasury,
        &auth,
        &mut investor_info,
        &mut compliance,
        &platform_chest,
        PLATFORM_WALLET,
        500,
        0,
        b"".to_string(),
        &version,
        vector[],
        vector[],
        clock.timestamp_ms(),
        &clock,
        ts.ctx(),
    );

    // Verify platform wallet balance after issuance
    assert!(registry_service::special_wallet_balance(&investor_info, PLATFORM_WALLET) == 500, 0);

    clock::destroy_for_testing(clock);
    ts::return_shared(treasury);
    ts::return_shared(auth);
    ts::return_shared(investor_info);
    ts::return_shared(compliance);
    ts::return_shared(version);
    ts::return_shared(platform_chest);

    // Add issuer wallet
    test_helpers::add_issuer_wallet(&mut ts, ISSUER_WALLET);
    ts.next_tx(ADMIN);
    let issuer_chest_id = ts::most_recent_id_shared<Chest>().destroy_some();

    // Seize tokens from platform wallet to issuer wallet
    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let policy = ts.take_shared<Policy<Balance<TEST_VOLORO>>>();
    let version = ts.take_shared<Version>();
    let issuer_chest = ts.take_shared_by_id<Chest>(issuer_chest_id);
    let mut platform_chest = ts.take_shared_by_id<Chest>(platform_chest_id);

    let request = platform_chest.clawback_balance<TEST_VOLORO>(200, ts.ctx());
    ds_token::seize(
        &auth,
        &mut investor_info,
        &policy,
        request,
        &issuer_chest,
        ISSUER_WALLET,
        b"seize from platform".to_string(),
        &version,
        ts.ctx(),
    );

    // Verify platform wallet balance is reduced
    assert!(registry_service::special_wallet_balance(&investor_info, PLATFORM_WALLET) == 300, 1);

    // Verify issuer wallet balance is increased
    assert!(registry_service::special_wallet_balance(&investor_info, ISSUER_WALLET) == 200, 2);

    ts::return_shared(auth);
    ts::return_shared(investor_info);
    ts::return_shared(policy);
    ts::return_shared(version);
    ts::return_shared(platform_chest);
    ts::return_shared(issuer_chest);
    ts.end();
}

// ==================== Template Command Tests ====================

/// Helper: convert a type name to std::string::String
fun type_to_string<T>(): String {
    std::type_name::with_defining_ids<T>().into_string().into_bytes().to_string()
}

/// Helper: get the package address as a string
fun pkg_address_string<T>(): String {
    std::type_name::with_defining_ids<T>().address_string().into_bytes().to_string()
}

/// Helper: build a transfer Command for ds_token::transfer<TEST_VOLORO>
fun build_transfer_command(): Command {
    let pkg = pkg_address_string<Treasury<TEST_VOLORO>>();
    let arguments = vector[
        ptb::object_by_type_string(type_to_string<Treasury<TEST_VOLORO>>()),
        ptb::object_by_type_string(type_to_string<InvestorInfo<TEST_VOLORO>>()),
        ptb::object_by_type_string(type_to_string<ComplianceConfig<TEST_VOLORO>>()),
        ptb::ext_input(b"request".to_string()),
        ptb::object_by_type_string(type_to_string<Version>()),
        ptb::clock(),
    ];
    ptb::move_call(
        pkg,
        b"ds_token".to_string(),
        b"transfer".to_string(),
        arguments,
        vector[type_to_string<TEST_VOLORO>()],
    )
}

#[test]
fun test_set_template_command() {
    let mut ts = ts::begin(ADMIN);
    setup_full(&mut ts);
    test_helpers::setup_templates(&mut ts);

    let command = build_transfer_command();

    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let mut templates = ts.take_shared<Templates>();
    let version = ts.take_shared<Version>();

    ds_token::set_template_command<TEST_VOLORO>(
        &auth,
        &mut templates,
        command,
        &version,
        ts.ctx(),
    );

    ts::return_shared(auth);
    ts::return_shared(templates);
    ts::return_shared(version);

    // Verify the command was stored by successfully unsetting it
    // (unset aborts with ETemplateNotSet if the command doesn't exist)
    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let mut templates = ts.take_shared<Templates>();
    let version = ts.take_shared<Version>();

    ds_token::unset_template_command<TEST_VOLORO>(
        &auth,
        &mut templates,
        &version,
        ts.ctx(),
    );

    ts::return_shared(auth);
    ts::return_shared(templates);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = ds_token::ENotAuthorized)]
fun test_set_template_command_unauthorized() {
    let mut ts = ts::begin(ADMIN);
    setup_full(&mut ts);
    test_helpers::setup_templates(&mut ts);

    let command = build_transfer_command();

    ts.next_tx(UNAUTHORIZED);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let mut templates = ts.take_shared<Templates>();
    let version = ts.take_shared<Version>();

    ds_token::set_template_command<TEST_VOLORO>(
        &auth,
        &mut templates,
        command,
        &version,
        ts.ctx(),
    );

    ts::return_shared(auth);
    ts::return_shared(templates);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure]
fun test_unset_template_command() {
    let mut ts = ts::begin(ADMIN);
    setup_full(&mut ts);
    test_helpers::setup_templates(&mut ts);

    let command = build_transfer_command();

    // First set the template
    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let mut templates = ts.take_shared<Templates>();
    let version = ts.take_shared<Version>();

    ds_token::set_template_command<TEST_VOLORO>(
        &auth,
        &mut templates,
        command,
        &version,
        ts.ctx(),
    );

    ts::return_shared(auth);
    ts::return_shared(templates);
    ts::return_shared(version);

    // Unset it
    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let mut templates = ts.take_shared<Templates>();
    let version = ts.take_shared<Version>();

    ds_token::unset_template_command<TEST_VOLORO>(
        &auth,
        &mut templates,
        &version,
        ts.ctx(),
    );

    ts::return_shared(auth);
    ts::return_shared(templates);
    ts::return_shared(version);

    // Try to unset again — should abort with ETemplateNotSet,
    // proving the first unset actually removed the command
    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let mut templates = ts.take_shared<Templates>();
    let version = ts.take_shared<Version>();

    ds_token::unset_template_command<TEST_VOLORO>(
        &auth,
        &mut templates,
        &version,
        ts.ctx(),
    );

    ts::return_shared(auth);
    ts::return_shared(templates);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = ds_token::ENotAuthorized)]
fun test_unset_template_command_unauthorized() {
    let mut ts = ts::begin(ADMIN);
    setup_full(&mut ts);
    test_helpers::setup_templates(&mut ts);

    let command = build_transfer_command();

    // Set the template as admin
    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let mut templates = ts.take_shared<Templates>();
    let version = ts.take_shared<Version>();

    ds_token::set_template_command<TEST_VOLORO>(
        &auth,
        &mut templates,
        command,
        &version,
        ts.ctx(),
    );

    ts::return_shared(auth);
    ts::return_shared(templates);
    ts::return_shared(version);

    // Try to unset from unauthorized address
    ts.next_tx(UNAUTHORIZED);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let mut templates = ts.take_shared<Templates>();
    let version = ts.take_shared<Version>();

    ds_token::unset_template_command<TEST_VOLORO>(
        &auth,
        &mut templates,
        &version,
        ts.ctx(),
    );

    ts::return_shared(auth);
    ts::return_shared(templates);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure]
fun test_unset_template_command_not_set() {
    let mut ts = ts::begin(ADMIN);
    setup_full(&mut ts);
    test_helpers::setup_templates(&mut ts);

    // Try to unset without setting first
    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let mut templates = ts.take_shared<Templates>();
    let version = ts.take_shared<Version>();

    ds_token::unset_template_command<TEST_VOLORO>(
        &auth,
        &mut templates,
        &version,
        ts.ctx(),
    );

    ts::return_shared(auth);
    ts::return_shared(templates);
    ts::return_shared(version);
    ts.end();
}

// ==================== Policy Cap Tests ====================

#[test]
fun test_policy_cap_borrow() {
    let mut ts = ts::begin(ADMIN);
    setup_full(&mut ts);

    ts.next_tx(ADMIN);
    let treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    // Borrow policy_cap - should succeed for ADMIN (Master role has AccessPolicyCap)
    let _cap = ds_token::policy_cap<TEST_VOLORO>(&treasury, &auth, &version, ts.ctx());

    ts::return_shared(treasury);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = ds_token::ENotAuthorized)]
fun test_policy_cap_unauthorized() {
    let mut ts = ts::begin(ADMIN);
    setup_full(&mut ts);

    ts.next_tx(UNAUTHORIZED);
    let treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    // Try to borrow policy_cap from unauthorized address - should fail
    let _cap = ds_token::policy_cap<TEST_VOLORO>(&treasury, &auth, &version, ts.ctx());

    ts::return_shared(treasury);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

// ==================== Issue Tokens No Chest Tests ====================

#[test]
fun test_issue_tokens_no_chest_success() {
    let mut ts = ts::begin(ADMIN);
    setup_full(&mut ts);

    // Register investor (this creates their wallet in registry but we won't use the chest)
    setup_investor(&mut ts, b"INV001", INVESTOR1, b"US");

    ts.next_tx(ADMIN);
    let mut treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let namespace = ts.take_shared<Namespace>();
    let version = ts.take_shared<Version>();
    let clock = clock::create_for_testing(ts.ctx());

    // Issue tokens without requiring a chest reference
    ds_token::issue_tokens_no_chest(
        &mut treasury,
        &auth,
        &mut investor_info,
        &mut compliance,
        &namespace,
        INVESTOR1,
        500,
        0,
        b"".to_string(),
        &version,
        vector[],
        vector[],
        clock.timestamp_ms(),
        &clock,
        ts.ctx(),
    );

    // Verify investor balance after issuance
    let investor_id = b"INV001".to_string();
    let balance = registry_service::investor_wallet_balance_total(&investor_info, investor_id);
    assert!(balance == 500, 0);

    clock::destroy_for_testing(clock);
    ts::return_shared(treasury);
    ts::return_shared(auth);
    ts::return_shared(investor_info);
    ts::return_shared(compliance);
    ts::return_shared(namespace);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = ds_token::ENotAuthorized)]
fun test_issue_tokens_no_chest_unauthorized() {
    let mut ts = ts::begin(ADMIN);
    setup_full(&mut ts);

    // Register investor
    setup_investor(&mut ts, b"INV001", INVESTOR1, b"US");

    // Try to issue from unauthorized address
    ts.next_tx(UNAUTHORIZED);
    let mut treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let namespace = ts.take_shared<Namespace>();
    let version = ts.take_shared<Version>();
    let clock = clock::create_for_testing(ts.ctx());

    // Should fail - UNAUTHORIZED has no IssueTokens ability
    ds_token::issue_tokens_no_chest(
        &mut treasury,
        &auth,
        &mut investor_info,
        &mut compliance,
        &namespace,
        INVESTOR1,
        500,
        0,
        b"".to_string(),
        &version,
        vector[],
        vector[],
        clock.timestamp_ms(),
        &clock,
        ts.ctx(),
    );

    clock::destroy_for_testing(clock);
    ts::return_shared(treasury);
    ts::return_shared(auth);
    ts::return_shared(investor_info);
    ts::return_shared(compliance);
    ts::return_shared(namespace);
    ts::return_shared(version);
    ts.end();
}

// ==================== Seize Chest Owner Mismatch Test ====================

#[test]
#[expected_failure(abort_code = ds_token::EChestOwnerMismatch)]
fun test_seize_chest_owner_mismatch() {
    let mut ts = ts::begin(ADMIN);
    setup_full(&mut ts);

    // Register investor and issue tokens
    setup_investor(&mut ts, b"INV001", INVESTOR1, b"US");

    ts.next_tx(ADMIN);
    let mut treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let investor_chest = ts.take_shared<Chest>();
    let clock = clock::create_for_testing(ts.ctx());

    ds_token::issue_tokens(
        &mut treasury,
        &auth,
        &mut investor_info,
        &mut compliance,
        &investor_chest,
        INVESTOR1,
        500,
        0,
        b"".to_string(),
        &version,
        vector[],
        vector[],
        clock.timestamp_ms(),
        &clock,
        ts.ctx(),
    );

    clock::destroy_for_testing(clock);
    ts::return_shared(treasury);
    ts::return_shared(auth);
    ts::return_shared(investor_info);
    ts::return_shared(compliance);
    ts::return_shared(version);
    ts::return_shared(investor_chest);

    // Add issuer wallet (creates issuer's chest)
    test_helpers::add_issuer_wallet(&mut ts, ISSUER_WALLET);

    // Try to seize with mismatched chest owner
    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let policy = ts.take_shared<Policy<Balance<TEST_VOLORO>>>();
    let version = ts.take_shared<Version>();
    // Get issuer chest (most recently created)
    let issuer_chest = ts.take_shared<Chest>();
    // Get investor chest
    let mut investor_chest = ts.take_shared<Chest>();

    // Seize but pass wrong to_address (INVESTOR1 instead of ISSUER_WALLET)
    let request = investor_chest.clawback_balance<TEST_VOLORO>(50, ts.ctx());
    ds_token::seize(
        &auth,
        &mut investor_info,
        &policy,
        request,
        &issuer_chest,
        INVESTOR1, // Wrong! Should be ISSUER_WALLET to match issuer_chest.owner()
        b"seize mismatch".to_string(),
        &version,
        ts.ctx(),
    );

    ts::return_shared(auth);
    ts::return_shared(investor_info);
    ts::return_shared(policy);
    ts::return_shared(version);
    ts::return_shared(investor_chest);
    ts::return_shared(issuer_chest);
    ts.end();
}

// ==================== Transfer Tests ====================

#[test]
fun test_transfer_success() {
    let mut ts = ts::begin(ADMIN);
    setup_full(&mut ts);

    // Register two investors
    setup_investor(&mut ts, b"INV001", INVESTOR1, b"US");
    setup_investor(&mut ts, b"INV002", INVESTOR2, b"US");

    // Issue tokens to INVESTOR1
    ts.next_tx(ADMIN);
    let mut treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    // INVESTOR2's chest is most recent, so it comes first
    let chest2 = ts.take_shared<Chest>();
    let chest1 = ts.take_shared<Chest>();
    let clock = clock::create_for_testing(ts.ctx());

    ds_token::issue_tokens(
        &mut treasury,
        &auth,
        &mut investor_info,
        &mut compliance,
        &chest1,
        INVESTOR1,
        500,
        0,
        b"".to_string(),
        &version,
        vector[],
        vector[],
        clock.timestamp_ms(),
        &clock,
        ts.ctx(),
    );

    clock::destroy_for_testing(clock);
    ts::return_shared(treasury);
    ts::return_shared(auth);
    ts::return_shared(investor_info);
    ts::return_shared(compliance);
    ts::return_shared(version);
    ts::return_shared(chest1);
    ts::return_shared(chest2);

    // Transfer from INVESTOR1 to INVESTOR2
    ts.next_tx(INVESTOR1);
    let treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let policy = ts.take_shared<Policy<Balance<TEST_VOLORO>>>();
    let version = ts.take_shared<Version>();
    let chest2 = ts.take_shared<Chest>();
    let mut chest1 = ts.take_shared<Chest>();
    let clock = clock::create_for_testing(ts.ctx());

    // Create auth and transfer request
    let pas_auth = chest::new_auth(ts.ctx());
    let mut request = chest1.send_balance<TEST_VOLORO>(&pas_auth, &chest2, 200, ts.ctx());

    // Call ds_token::transfer
    ds_token::transfer(
        &treasury,
        &mut investor_info,
        &compliance,
        &mut request,
        &version,
        &clock,
    );

    // Resolve the request
    send_funds::resolve_balance(request, &policy);

    // Verify balances
    let investor1_id = b"INV001".to_string();
    let investor2_id = b"INV002".to_string();
    let balance1 = registry_service::investor_wallet_balance_total(&investor_info, investor1_id);
    let balance2 = registry_service::investor_wallet_balance_total(&investor_info, investor2_id);
    assert!(balance1 == 300, 0);
    assert!(balance2 == 200, 1);

    clock::destroy_for_testing(clock);
    ts::return_shared(treasury);
    ts::return_shared(investor_info);
    ts::return_shared(compliance);
    ts::return_shared(policy);
    ts::return_shared(version);
    ts::return_shared(chest1);
    ts::return_shared(chest2);
    ts.end();
}

#[test]
#[expected_failure(abort_code = ds_token::EValueZero)]
fun test_transfer_value_zero() {
    let mut ts = ts::begin(ADMIN);
    setup_full(&mut ts);

    // Register two investors
    setup_investor(&mut ts, b"INV001", INVESTOR1, b"US");
    setup_investor(&mut ts, b"INV002", INVESTOR2, b"US");

    // Issue tokens to INVESTOR1
    ts.next_tx(ADMIN);
    let mut treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let chest2 = ts.take_shared<Chest>();
    let chest1 = ts.take_shared<Chest>();
    let clock = clock::create_for_testing(ts.ctx());

    ds_token::issue_tokens(
        &mut treasury,
        &auth,
        &mut investor_info,
        &mut compliance,
        &chest1,
        INVESTOR1,
        500,
        0,
        b"".to_string(),
        &version,
        vector[],
        vector[],
        clock.timestamp_ms(),
        &clock,
        ts.ctx(),
    );

    clock::destroy_for_testing(clock);
    ts::return_shared(treasury);
    ts::return_shared(auth);
    ts::return_shared(investor_info);
    ts::return_shared(compliance);
    ts::return_shared(version);
    ts::return_shared(chest1);
    ts::return_shared(chest2);

    // Try to transfer 0 tokens
    ts.next_tx(INVESTOR1);
    let treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let policy = ts.take_shared<Policy<Balance<TEST_VOLORO>>>();
    let version = ts.take_shared<Version>();
    let chest2 = ts.take_shared<Chest>();
    let mut chest1 = ts.take_shared<Chest>();
    let clock = clock::create_for_testing(ts.ctx());

    // Create auth and transfer request with 0 amount
    let pas_auth = chest::new_auth(ts.ctx());
    let mut request = chest1.send_balance<TEST_VOLORO>(&pas_auth, &chest2, 0, ts.ctx());

    // Should fail - value is 0
    ds_token::transfer(
        &treasury,
        &mut investor_info,
        &compliance,
        &mut request,
        &version,
        &clock,
    );

    send_funds::resolve_balance(request, &policy);

    clock::destroy_for_testing(clock);
    ts::return_shared(treasury);
    ts::return_shared(investor_info);
    ts::return_shared(compliance);
    ts::return_shared(policy);
    ts::return_shared(version);
    ts::return_shared(chest1);
    ts::return_shared(chest2);
    ts.end();
}

#[test]
#[expected_failure(abort_code = ds_token::ETreasuryPaused)]
fun test_transfer_paused() {
    let mut ts = ts::begin(ADMIN);
    setup_full(&mut ts);

    // Register two investors
    setup_investor(&mut ts, b"INV001", INVESTOR1, b"US");
    setup_investor(&mut ts, b"INV002", INVESTOR2, b"US");

    // Issue tokens to INVESTOR1 and pause treasury
    ts.next_tx(ADMIN);
    let mut treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let chest2 = ts.take_shared<Chest>();
    let chest1 = ts.take_shared<Chest>();
    let clock = clock::create_for_testing(ts.ctx());

    ds_token::issue_tokens(
        &mut treasury,
        &auth,
        &mut investor_info,
        &mut compliance,
        &chest1,
        INVESTOR1,
        500,
        0,
        b"".to_string(),
        &version,
        vector[],
        vector[],
        clock.timestamp_ms(),
        &clock,
        ts.ctx(),
    );

    // Pause the treasury
    ds_token::pause(&mut treasury, &auth, &version, ts.ctx());

    clock::destroy_for_testing(clock);
    ts::return_shared(treasury);
    ts::return_shared(auth);
    ts::return_shared(investor_info);
    ts::return_shared(compliance);
    ts::return_shared(version);
    ts::return_shared(chest1);
    ts::return_shared(chest2);

    // Try to transfer between investor wallets while paused
    ts.next_tx(INVESTOR1);
    let treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let policy = ts.take_shared<Policy<Balance<TEST_VOLORO>>>();
    let version = ts.take_shared<Version>();
    let chest2 = ts.take_shared<Chest>();
    let mut chest1 = ts.take_shared<Chest>();
    let clock = clock::create_for_testing(ts.ctx());

    let pas_auth = chest::new_auth(ts.ctx());
    let mut request = chest1.send_balance<TEST_VOLORO>(&pas_auth, &chest2, 100, ts.ctx());

    // Should fail - treasury is paused and both are investor wallets
    ds_token::transfer(
        &treasury,
        &mut investor_info,
        &compliance,
        &mut request,
        &version,
        &clock,
    );

    send_funds::resolve_balance(request, &policy);

    clock::destroy_for_testing(clock);
    ts::return_shared(treasury);
    ts::return_shared(investor_info);
    ts::return_shared(compliance);
    ts::return_shared(policy);
    ts::return_shared(version);
    ts::return_shared(chest1);
    ts::return_shared(chest2);
    ts.end();
}

#[test]
fun test_transfer_to_special_wallet() {
    let mut ts = ts::begin(ADMIN);
    setup_full(&mut ts);

    // Register investor FIRST (chest created first)
    setup_investor(&mut ts, b"INV001", INVESTOR1, b"US");

    // Issue tokens to investor before adding platform wallet
    ts.next_tx(ADMIN);
    let mut treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let investor_chest = ts.take_shared<Chest>();
    let clock = clock::create_for_testing(ts.ctx());

    ds_token::issue_tokens(
        &mut treasury,
        &auth,
        &mut investor_info,
        &mut compliance,
        &investor_chest,
        INVESTOR1,
        500,
        0,
        b"".to_string(),
        &version,
        vector[],
        vector[],
        clock.timestamp_ms(),
        &clock,
        ts.ctx(),
    );

    clock::destroy_for_testing(clock);
    ts::return_shared(treasury);
    ts::return_shared(auth);
    ts::return_shared(investor_info);
    ts::return_shared(compliance);
    ts::return_shared(version);
    ts::return_shared(investor_chest);

    // Add platform wallet SECOND (chest created second, so it comes first when taking)
    test_helpers::add_platform_wallet(&mut ts, PLATFORM_WALLET);

    // Transfer from investor to platform wallet
    ts.next_tx(INVESTOR1);
    let treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let policy = ts.take_shared<Policy<Balance<TEST_VOLORO>>>();
    let version = ts.take_shared<Version>();
    // Platform chest is most recent (created second)
    let platform_chest = ts.take_shared<Chest>();
    // Investor chest is older (created first)
    let mut investor_chest = ts.take_shared<Chest>();
    let clock = clock::create_for_testing(ts.ctx());

    let pas_auth = chest::new_auth(ts.ctx());
    let mut request = investor_chest.send_balance<TEST_VOLORO>(
        &pas_auth,
        &platform_chest,
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

    send_funds::resolve_balance(request, &policy);

    // Verify balances
    let investor_balance = registry_service::investor_wallet_balance_total(
        &investor_info,
        b"INV001".to_string(),
    );
    let platform_balance = registry_service::special_wallet_balance(
        &investor_info,
        PLATFORM_WALLET,
    );
    assert!(investor_balance == 300, 0);
    assert!(platform_balance == 200, 1);

    clock::destroy_for_testing(clock);
    ts::return_shared(treasury);
    ts::return_shared(investor_info);
    ts::return_shared(compliance);
    ts::return_shared(policy);
    ts::return_shared(version);
    ts::return_shared(investor_chest);
    ts::return_shared(platform_chest);
    ts.end();
}

#[test]
fun test_transfer_from_special_wallet() {
    let mut ts = ts::begin(ADMIN);
    setup_full(&mut ts);

    // Add platform wallet
    test_helpers::add_platform_wallet(&mut ts, PLATFORM_WALLET);

    // Issue tokens to platform wallet
    ts.next_tx(ADMIN);
    let mut treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let platform_chest = ts.take_shared<Chest>();
    let clock = clock::create_for_testing(ts.ctx());

    ds_token::issue_tokens(
        &mut treasury,
        &auth,
        &mut investor_info,
        &mut compliance,
        &platform_chest,
        PLATFORM_WALLET,
        500,
        0,
        b"".to_string(),
        &version,
        vector[],
        vector[],
        clock.timestamp_ms(),
        &clock,
        ts.ctx(),
    );

    clock::destroy_for_testing(clock);
    ts::return_shared(treasury);
    ts::return_shared(auth);
    ts::return_shared(investor_info);
    ts::return_shared(compliance);
    ts::return_shared(version);
    ts::return_shared(platform_chest);

    // Register investor (creates investor chest)
    setup_investor(&mut ts, b"INV001", INVESTOR1, b"US");

    // Transfer from platform wallet to investor
    ts.next_tx(PLATFORM_WALLET);
    let treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let policy = ts.take_shared<Policy<Balance<TEST_VOLORO>>>();
    let version = ts.take_shared<Version>();
    // Investor chest is most recent
    let investor_chest = ts.take_shared<Chest>();
    let mut platform_chest = ts.take_shared<Chest>();
    let clock = clock::create_for_testing(ts.ctx());

    let pas_auth = chest::new_auth(ts.ctx());
    let mut request = platform_chest.send_balance<TEST_VOLORO>(
        &pas_auth,
        &investor_chest,
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

    send_funds::resolve_balance(request, &policy);

    // Verify balances
    let investor_balance = registry_service::investor_wallet_balance_total(
        &investor_info,
        b"INV001".to_string(),
    );
    let platform_balance = registry_service::special_wallet_balance(
        &investor_info,
        PLATFORM_WALLET,
    );
    assert!(investor_balance == 200, 0);
    assert!(platform_balance == 300, 1);

    clock::destroy_for_testing(clock);
    ts::return_shared(treasury);
    ts::return_shared(investor_info);
    ts::return_shared(compliance);
    ts::return_shared(policy);
    ts::return_shared(version);
    ts::return_shared(investor_chest);
    ts::return_shared(platform_chest);
    ts.end();
}

#[test]
fun test_transfer_paused_from_special_wallet_allowed() {
    let mut ts = ts::begin(ADMIN);
    setup_full(&mut ts);

    // Add platform wallet
    test_helpers::add_platform_wallet(&mut ts, PLATFORM_WALLET);

    // Issue tokens to platform wallet and pause treasury
    ts.next_tx(ADMIN);
    let mut treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let platform_chest = ts.take_shared<Chest>();
    let clock = clock::create_for_testing(ts.ctx());

    ds_token::issue_tokens(
        &mut treasury,
        &auth,
        &mut investor_info,
        &mut compliance,
        &platform_chest,
        PLATFORM_WALLET,
        500,
        0,
        b"".to_string(),
        &version,
        vector[],
        vector[],
        clock.timestamp_ms(),
        &clock,
        ts.ctx(),
    );

    // Pause the treasury
    ds_token::pause(&mut treasury, &auth, &version, ts.ctx());

    clock::destroy_for_testing(clock);
    ts::return_shared(treasury);
    ts::return_shared(auth);
    ts::return_shared(investor_info);
    ts::return_shared(compliance);
    ts::return_shared(version);
    ts::return_shared(platform_chest);

    // Register investor (creates investor chest)
    setup_investor(&mut ts, b"INV001", INVESTOR1, b"US");

    // Transfer from platform wallet to investor (should succeed even though paused)
    ts.next_tx(PLATFORM_WALLET);
    let treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let policy = ts.take_shared<Policy<Balance<TEST_VOLORO>>>();
    let version = ts.take_shared<Version>();
    // Investor chest is most recent
    let investor_chest = ts.take_shared<Chest>();
    let mut platform_chest = ts.take_shared<Chest>();
    let clock = clock::create_for_testing(ts.ctx());

    let pas_auth = chest::new_auth(ts.ctx());
    let mut request = platform_chest.send_balance<TEST_VOLORO>(
        &pas_auth,
        &investor_chest,
        200,
        ts.ctx(),
    );

    // Should succeed - pause only blocks investor-to-investor transfers
    ds_token::transfer(
        &treasury,
        &mut investor_info,
        &compliance,
        &mut request,
        &version,
        &clock,
    );

    send_funds::resolve_balance(request, &policy);

    // Verify balances
    let investor_balance = registry_service::investor_wallet_balance_total(
        &investor_info,
        b"INV001".to_string(),
    );
    let platform_balance = registry_service::special_wallet_balance(
        &investor_info,
        PLATFORM_WALLET,
    );
    assert!(investor_balance == 200, 0);
    assert!(platform_balance == 300, 1);

    clock::destroy_for_testing(clock);
    ts::return_shared(treasury);
    ts::return_shared(investor_info);
    ts::return_shared(compliance);
    ts::return_shared(policy);
    ts::return_shared(version);
    ts::return_shared(investor_chest);
    ts::return_shared(platform_chest);
    ts.end();
}

// ==================== Set Metadata Tests ====================

#[test]
fun test_set_metadata_name() {
    let mut ts = ts::begin(ADMIN);
    setup_full(&mut ts);

    ts.next_tx(ADMIN);
    let treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let mut currency = ts.take_shared<Currency<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    // Update only the name
    ds_token::set_metadata(
        &treasury,
        &auth,
        &mut currency,
        option::some(b"New Token Name".to_string()),
        option::none(),
        option::none(),
        &version,
        ts.ctx(),
    );

    // Verify name was updated
    assert!(coin_registry::name(&currency) == b"New Token Name".to_string(), 0);

    ts::return_shared(treasury);
    ts::return_shared(auth);
    ts::return_shared(currency);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_set_metadata_description() {
    let mut ts = ts::begin(ADMIN);
    setup_full(&mut ts);

    ts.next_tx(ADMIN);
    let treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let mut currency = ts.take_shared<Currency<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    // Update only the description
    ds_token::set_metadata(
        &treasury,
        &auth,
        &mut currency,
        option::none(),
        option::some(b"Updated description".to_string()),
        option::none(),
        &version,
        ts.ctx(),
    );

    // Verify description was updated
    assert!(coin_registry::description(&currency) == b"Updated description".to_string(), 0);

    ts::return_shared(treasury);
    ts::return_shared(auth);
    ts::return_shared(currency);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_set_metadata_icon_url() {
    let mut ts = ts::begin(ADMIN);
    setup_full(&mut ts);

    ts.next_tx(ADMIN);
    let treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let mut currency = ts.take_shared<Currency<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    // Update only the icon_url
    ds_token::set_metadata(
        &treasury,
        &auth,
        &mut currency,
        option::none(),
        option::none(),
        option::some(b"https://new-icon.png".to_string()),
        &version,
        ts.ctx(),
    );

    // Verify icon_url was updated
    assert!(coin_registry::icon_url(&currency) == b"https://new-icon.png".to_string(), 0);

    ts::return_shared(treasury);
    ts::return_shared(auth);
    ts::return_shared(currency);
    ts::return_shared(version);
    ts.end();
}

#[test]
fun test_set_metadata_all() {
    let mut ts = ts::begin(ADMIN);
    setup_full(&mut ts);

    ts.next_tx(ADMIN);
    let treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let mut currency = ts.take_shared<Currency<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    // Update all fields
    ds_token::set_metadata(
        &treasury,
        &auth,
        &mut currency,
        option::some(b"Fully Updated Token".to_string()),
        option::some(b"Complete new description".to_string()),
        option::some(b"https://brand-new-icon.png".to_string()),
        &version,
        ts.ctx(),
    );

    // Verify all fields were updated
    assert!(coin_registry::name(&currency) == b"Fully Updated Token".to_string(), 0);
    assert!(coin_registry::description(&currency) == b"Complete new description".to_string(), 1);
    assert!(coin_registry::icon_url(&currency) == b"https://brand-new-icon.png".to_string(), 2);

    ts::return_shared(treasury);
    ts::return_shared(auth);
    ts::return_shared(currency);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = ds_token::ENotAuthorized)]
fun test_set_metadata_unauthorized() {
    let mut ts = ts::begin(ADMIN);
    setup_full(&mut ts);

    // Try to set metadata from unauthorized address
    ts.next_tx(UNAUTHORIZED);
    let treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let mut currency = ts.take_shared<Currency<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    // Should fail - UNAUTHORIZED has no MetadataUpdate ability
    ds_token::set_metadata(
        &treasury,
        &auth,
        &mut currency,
        option::some(b"Unauthorized Update".to_string()),
        option::none(),
        option::none(),
        &version,
        ts.ctx(),
    );

    ts::return_shared(treasury);
    ts::return_shared(auth);
    ts::return_shared(currency);
    ts::return_shared(version);
    ts.end();
}
