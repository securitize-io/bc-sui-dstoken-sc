#[test_only]
module securitize::ds_token_tests;

use pas::{rule::Rule, vault::Vault};
use securitize::{
    compliance_service::{Self, ComplianceConfig},
    ds_token::{Self, Treasury},
    lock_manager,
    registry_service::{Self, InvestorInfo},
    test_helpers::{Self, TEST_VOLORO},
    trust_service::{Auth},
    version::Version
};
use sui::{clock, test_scenario::{Self as ts, Scenario}};

const ADMIN: address = @0x001;
const UNAUTHORIZED: address = @0x002;
const INVESTOR1: address = @0x101;
const INVESTOR2: address = @0x102;
const ISSUER_WALLET: address = @0x201;

// ==================== Setup Helpers ====================

/// Full setup with Treasury using the TEST_VOLORO pattern
fun setup_full(ts: &mut Scenario) {
    test_helpers::setup_with_treasury(ts);
}

/// Setup investor with country and wallet.
/// Note: register_investor_with_wallet automatically creates the vault.
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

    // Register investor with US country (vault is created automatically)
    setup_investor(&mut ts, b"INV001", INVESTOR1, b"USΑ");

    ts.next_tx(ADMIN);
    let mut treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let rule = ts.take_shared<Rule<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let vault = ts.take_shared<Vault>();
    let clock = clock::create_for_testing(ts.ctx());

    ds_token::issue_tokens(
        &mut treasury,
        &auth,
        &mut investor_info,
        &mut compliance,
        &rule,
        &vault,
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
    ts::return_shared(rule);
    ts::return_shared(version);
    ts::return_shared(vault);
    ts.end();
}

#[test]
#[expected_failure(abort_code = ds_token::ENotAuthorized)]
fun test_issue_tokens_unauthorized() {
    let mut ts = ts::begin(ADMIN);
    setup_full(&mut ts);

    // Register investor (vault is created automatically)
    setup_investor(&mut ts, b"INV001", INVESTOR1, b"US");

    // Try to issue from unauthorized address
    ts.next_tx(UNAUTHORIZED);
    let mut treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let rule = ts.take_shared<Rule<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let vault = ts.take_shared<Vault>();
    let clock = clock::create_for_testing(ts.ctx());

    ds_token::issue_tokens(
        &mut treasury,
        &auth,
        &mut investor_info,
        &mut compliance,
        &rule,
        &vault,
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
    ts::return_shared(rule);
    ts::return_shared(version);
    ts::return_shared(vault);
    ts.end();
}

#[test]
#[expected_failure(abort_code = ds_token::EValueZero)]
fun test_issue_zero_tokens() {
    let mut ts = ts::begin(ADMIN);
    setup_full(&mut ts);

    // Register investor (vault is created automatically)
    setup_investor(&mut ts, b"INV001", INVESTOR1, b"US");

    ts.next_tx(ADMIN);
    let mut treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let rule = ts.take_shared<Rule<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let vault = ts.take_shared<Vault>();
    let clock = clock::create_for_testing(ts.ctx());

    // Try to issue 0 tokens - should fail
    ds_token::issue_tokens(
        &mut treasury,
        &auth,
        &mut investor_info,
        &mut compliance,
        &rule,
        &vault,
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
    ts::return_shared(rule);
    ts::return_shared(version);
    ts::return_shared(vault);
    ts.end();
}

#[test]
#[expected_failure(abort_code = ds_token::EVaultOwnerMismatch)]
fun test_issue_tokens_vault_owner_mismatch() {
    let mut ts = ts::begin(ADMIN);
    setup_full(&mut ts);

    // Register investor (vault is created automatically)
    setup_investor(&mut ts, b"INV001", INVESTOR1, b"US");

    ts.next_tx(ADMIN);
    let mut treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let rule = ts.take_shared<Rule<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let vault = ts.take_shared<Vault>();
    let clock = clock::create_for_testing(ts.ctx());

    // Try to issue to wrong address (vault belongs to INVESTOR1, but we pass INVESTOR2)
    ds_token::issue_tokens(
        &mut treasury,
        &auth,
        &mut investor_info,
        &mut compliance,
        &rule,
        &vault,
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
    ts::return_shared(rule);
    ts::return_shared(version);
    ts::return_shared(vault);
    ts.end();
}

#[test]
#[expected_failure(abort_code = ds_token::EInvalidLengthOfParameters)]
fun test_issue_tokens_mismatched_lock_arrays() {
    let mut ts = ts::begin(ADMIN);
    setup_full(&mut ts);

    // Register investor (vault is created automatically)
    setup_investor(&mut ts, b"INV001", INVESTOR1, b"US");

    ts.next_tx(ADMIN);
    let mut treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let rule = ts.take_shared<Rule<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let vault = ts.take_shared<Vault>();
    let clock = clock::create_for_testing(ts.ctx());

    // Mismatched arrays: 2 locked values but only 1 release time
    ds_token::issue_tokens(
        &mut treasury,
        &auth,
        &mut investor_info,
        &mut compliance,
        &rule,
        &vault,
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
    ts::return_shared(rule);
    ts::return_shared(version);
    ts::return_shared(vault);
    ts.end();
}

#[test]
#[expected_failure(abort_code = ds_token::EValueLockedLargerThanValue)]
fun test_issue_tokens_locked_exceeds_value() {
    let mut ts = ts::begin(ADMIN);
    setup_full(&mut ts);

    // Register investor (vault is created automatically)
    setup_investor(&mut ts, b"INV001", INVESTOR1, b"USA");

    ts.next_tx(ADMIN);
    let mut treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let rule = ts.take_shared<Rule<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let vault = ts.take_shared<Vault>();
    let clock = clock::create_for_testing(ts.ctx());

    // Locked value (600) exceeds issue value (500)
    ds_token::issue_tokens(
        &mut treasury,
        &auth,
        &mut investor_info,
        &mut compliance,
        &rule,
        &vault,
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
    ts::return_shared(rule);
    ts::return_shared(version);
    ts::return_shared(vault);
    ts.end();
}

#[test]
fun test_issue_tokens_with_partial_lock() {
    let mut ts = ts::begin(ADMIN);
    setup_full(&mut ts);

    // Register investor (vault is created automatically)
    setup_investor(&mut ts, b"INV001", INVESTOR1, b"US");

    ts.next_tx(ADMIN);
    let mut treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let rule = ts.take_shared<Rule<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let vault = ts.take_shared<Vault>();
    let clock = clock::create_for_testing(ts.ctx());

    // Issue 500 with 200 locked
    ds_token::issue_tokens(
        &mut treasury,
        &auth,
        &mut investor_info,
        &mut compliance,
        &rule,
        &vault,
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
    ts::return_shared(rule);
    ts::return_shared(version);
    ts::return_shared(vault);
    ts.end();
}

#[test]
fun test_issue_tokens_with_full_lock() {
    let mut ts = ts::begin(ADMIN);
    setup_full(&mut ts);

    // Register investor (vault is created automatically)
    setup_investor(&mut ts, b"INV001", INVESTOR1, b"US");

    ts.next_tx(ADMIN);
    let mut treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let rule = ts.take_shared<Rule<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let vault = ts.take_shared<Vault>();
    let clock = clock::create_for_testing(ts.ctx());

    // Issue 500 with all 500 locked
    ds_token::issue_tokens(
        &mut treasury,
        &auth,
        &mut investor_info,
        &mut compliance,
        &rule,
        &vault,
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
    ts::return_shared(rule);
    ts::return_shared(version);
    ts::return_shared(vault);
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
    let rule = ts.take_shared<Rule<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let vault1 = ts.take_shared<Vault>();
    let clock = clock::create_for_testing(ts.ctx());

    ds_token::issue_tokens(
        &mut treasury,
        &auth,
        &mut investor_info,
        &mut compliance,
        &rule,
        &vault1,
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
    ts::return_shared(rule);
    ts::return_shared(version);
    ts::return_shared(vault1);

    // Register second investor
    setup_investor(&mut ts, b"INV002", INVESTOR2, b"FR");

    // Issue to second investor
    ts.next_tx(ADMIN);
    let mut treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let rule = ts.take_shared<Rule<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let vault2 = ts.take_shared<Vault>();
    let clock = clock::create_for_testing(ts.ctx());

    ds_token::issue_tokens(
        &mut treasury,
        &auth,
        &mut investor_info,
        &mut compliance,
        &rule,
        &vault2,
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
    ts::return_shared(rule);
    ts::return_shared(version);
    ts::return_shared(vault2);
    ts.end();
}

// ==================== Burn Tests ====================

#[test]
fun test_burn_tokens() {
    let mut ts = ts::begin(ADMIN);
    setup_full(&mut ts);

    // Register investor and issue tokens (vault is created automatically)
    setup_investor(&mut ts, b"INV001", INVESTOR1, b"US");

    // Issue tokens first
    ts.next_tx(ADMIN);
    let mut treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let rule = ts.take_shared<Rule<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let mut vault = ts.take_shared<Vault>();
    let clock = clock::create_for_testing(ts.ctx());

    ds_token::issue_tokens(
        &mut treasury,
        &auth,
        &mut investor_info,
        &mut compliance,
        &rule,
        &vault,
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
    let balance_before = registry_service::investor_wallet_balance_total(&investor_info, investor_id);
    assert!(balance_before == 500, 0);

    // Verify investor count before burn
    let total_before = registry_service::get_total_investors_count(&investor_info);
    assert!(total_before == 1, 1);

    // Now burn some tokens (partial burn - investor still has balance)
    ds_token::burn(
        &mut treasury,
        &auth,
        &mut investor_info,
        &rule,
        &mut vault,
        INVESTOR1,
        50,
        b"test burn".to_string(),
        &version,
        ts.ctx(),
    );

    // Verify balance after burn (500 - 50 = 450)
    let balance_after = registry_service::investor_wallet_balance_total(&investor_info, investor_id);
    assert!(balance_after == 450, 2);

    // Verify investor count unchanged (partial burn, investor still has tokens)
    let total_after = registry_service::get_total_investors_count(&investor_info);
    assert!(total_after == 1, 3);

    clock::destroy_for_testing(clock);
    ts::return_shared(treasury);
    ts::return_shared(auth);
    ts::return_shared(investor_info);
    ts::return_shared(compliance);
    ts::return_shared(rule);
    ts::return_shared(version);
    ts::return_shared(vault);
    ts.end();
}

#[test]
#[expected_failure(abort_code = ds_token::ENotAuthorized)]
fun test_burn_unauthorized() {
    let mut ts = ts::begin(ADMIN);
    setup_full(&mut ts);

    // Register investor and issue tokens (vault is created automatically)
    setup_investor(&mut ts, b"INV001", INVESTOR1, b"US");

    // Issue tokens first
    ts.next_tx(ADMIN);
    let mut treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let rule = ts.take_shared<Rule<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let vault = ts.take_shared<Vault>();
    let clock = clock::create_for_testing(ts.ctx());

    ds_token::issue_tokens(
        &mut treasury,
        &auth,
        &mut investor_info,
        &mut compliance,
        &rule,
        &vault,
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
    ts::return_shared(rule);
    ts::return_shared(version);
    ts::return_shared(vault);

    // Try to burn from unauthorized address
    ts.next_tx(UNAUTHORIZED);
    let mut treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let rule = ts.take_shared<Rule<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let mut vault = ts.take_shared<Vault>();

    ds_token::burn(
        &mut treasury,
        &auth,
        &mut investor_info,
        &rule,
        &mut vault,
        INVESTOR1,
        50,
        b"unauthorized burn".to_string(),
        &version,
        ts.ctx(),
    );

    ts::return_shared(treasury);
    ts::return_shared(auth);
    ts::return_shared(investor_info);
    ts::return_shared(rule);
    ts::return_shared(version);
    ts::return_shared(vault);
    ts.end();
}

#[test]
#[expected_failure(abort_code = ds_token::EVaultOwnerMismatch)]
fun test_burn_vault_owner_mismatch() {
    let mut ts = ts::begin(ADMIN);
    setup_full(&mut ts);

    // Register investor and issue tokens (vault is created automatically)
    setup_investor(&mut ts, b"INV001", INVESTOR1, b"US");

    ts.next_tx(ADMIN);
    let mut treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let rule = ts.take_shared<Rule<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let mut vault = ts.take_shared<Vault>();
    let clock = clock::create_for_testing(ts.ctx());

    ds_token::issue_tokens(
        &mut treasury,
        &auth,
        &mut investor_info,
        &mut compliance,
        &rule,
        &vault,
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

    // Try to burn with wrong from_address
    ds_token::burn(
        &mut treasury,
        &auth,
        &mut investor_info,
        &rule,
        &mut vault,
        INVESTOR2, // Wrong! Vault belongs to INVESTOR1
        50,
        b"test burn".to_string(),
        &version,
        ts.ctx(),
    );

    clock::destroy_for_testing(clock);
    ts::return_shared(treasury);
    ts::return_shared(auth);
    ts::return_shared(investor_info);
    ts::return_shared(compliance);
    ts::return_shared(rule);
    ts::return_shared(version);
    ts::return_shared(vault);
    ts.end();
}

// ==================== Seize Tests ====================

#[test]
fun test_seize_tokens() {
    let mut ts = ts::begin(ADMIN);
    setup_full(&mut ts);

    // Register investor (vault is created automatically)
    setup_investor(&mut ts, b"INV001", INVESTOR1, b"US");

    // Issue tokens first (before adding issuer wallet to avoid vault ordering issues)
    ts.next_tx(ADMIN);
    let mut treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let rule = ts.take_shared<Rule<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let investor_vault = ts.take_shared<Vault>();
    let clock = clock::create_for_testing(ts.ctx());

    ds_token::issue_tokens(
        &mut treasury,
        &auth,
        &mut investor_info,
        &mut compliance,
        &rule,
        &investor_vault,
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
    ts::return_shared(rule);
    ts::return_shared(version);
    ts::return_shared(investor_vault);

    // Add issuer wallet (vault is created automatically by add_issuer_wallet)
    test_helpers::add_issuer_wallet(&mut ts, ISSUER_WALLET);

    // Now seize tokens
    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let rule = ts.take_shared<Rule<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    // Get issuer vault (most recently created)
    let issuer_vault = ts.take_shared<Vault>();
    // Get investor vault
    let mut investor_vault = ts.take_shared<Vault>();

    // Verify balance before seize
    let investor_id = b"INV001".to_string();
    let balance_before = registry_service::investor_wallet_balance_total(&investor_info, investor_id);
    assert!(balance_before == 500, 0);

    // Verify investor count before seize
    let total_before = registry_service::get_total_investors_count(&investor_info);
    assert!(total_before == 1, 1);

    // Seize tokens (partial seize - investor still has balance)
    ds_token::seize(
        &auth,
        &mut investor_info,
        &rule,
        &mut investor_vault,
        INVESTOR1,
        &issuer_vault,
        ISSUER_WALLET,
        50,
        b"seize reason".to_string(),
        &version,
        ts.ctx(),
    );

    // Verify balance after seize (500 - 50 = 450)
    let balance_after = registry_service::investor_wallet_balance_total(&investor_info, investor_id);
    assert!(balance_after == 450, 2);

    // Verify investor count unchanged (partial seize, investor still has tokens)
    let total_after = registry_service::get_total_investors_count(&investor_info);
    assert!(total_after == 1, 3);

    ts::return_shared(auth);
    ts::return_shared(investor_info);
    ts::return_shared(rule);
    ts::return_shared(version);
    ts::return_shared(investor_vault);
    ts::return_shared(issuer_vault);
    ts.end();
}

#[test]
#[expected_failure(abort_code = ds_token::ENotAuthorized)]
fun test_seize_unauthorized() {
    let mut ts = ts::begin(ADMIN);
    setup_full(&mut ts);

    // Register investor (vault is created automatically)
    setup_investor(&mut ts, b"INV001", INVESTOR1, b"US");

    // Issue tokens first (before adding issuer wallet to avoid vault ordering issues)
    ts.next_tx(ADMIN);
    let mut treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let rule = ts.take_shared<Rule<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let vault = ts.take_shared<Vault>();
    let clock = clock::create_for_testing(ts.ctx());

    ds_token::issue_tokens(
        &mut treasury,
        &auth,
        &mut investor_info,
        &mut compliance,
        &rule,
        &vault,
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
    ts::return_shared(rule);
    ts::return_shared(version);
    ts::return_shared(vault);

    // Add issuer wallet (vault is created automatically by add_issuer_wallet)
    test_helpers::add_issuer_wallet(&mut ts, ISSUER_WALLET);

    // Try to seize from unauthorized address
    ts.next_tx(UNAUTHORIZED);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let rule = ts.take_shared<Rule<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    // Get issuer vault (most recently created)
    let issuer_vault = ts.take_shared<Vault>();
    // Get investor vault
    let mut investor_vault = ts.take_shared<Vault>();

    ds_token::seize(
        &auth,
        &mut investor_info,
        &rule,
        &mut investor_vault,
        INVESTOR1,
        &issuer_vault,
        ISSUER_WALLET,
        50,
        b"unauthorized seize".to_string(),
        &version,
        ts.ctx(),
    );

    ts::return_shared(auth);
    ts::return_shared(investor_info);
    ts::return_shared(rule);
    ts::return_shared(version);
    ts::return_shared(investor_vault);
    ts::return_shared(issuer_vault);
    ts.end();
}

#[test]
#[expected_failure(abort_code = compliance_service::ENotIssuerWallet)]
fun test_seize_to_non_issuer_wallet() {
    let mut ts = ts::begin(ADMIN);
    setup_full(&mut ts);

    // Register first investor and issue tokens
    setup_investor(&mut ts, b"INV001", INVESTOR1, b"US");

    // Issue tokens to INVESTOR1
    ts.next_tx(ADMIN);
    let mut treasury = ts.take_shared<Treasury<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let mut compliance = ts.take_shared<ComplianceConfig<TEST_VOLORO>>();
    let rule = ts.take_shared<Rule<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let vault1 = ts.take_shared<Vault>();
    let clock = clock::create_for_testing(ts.ctx());

    ds_token::issue_tokens(
        &mut treasury,
        &auth,
        &mut investor_info,
        &mut compliance,
        &rule,
        &vault1,
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
    ts::return_shared(rule);
    ts::return_shared(version);
    ts::return_shared(vault1);

    // Register second investor (this creates INVESTOR2's vault)
    setup_investor(&mut ts, b"INV002", INVESTOR2, b"US");

    // Now try to seize from INVESTOR1 to INVESTOR2 (who is not an issuer wallet)
    ts.next_tx(ADMIN);
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let rule = ts.take_shared<Rule<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    // Get INVESTOR2's vault (most recently created)
    let vault2 = ts.take_shared<Vault>();
    // Get INVESTOR1's vault
    let mut vault1 = ts.take_shared<Vault>();

    // Try to seize to a non-issuer wallet (INVESTOR2) - should fail with ENotIssuerWallet
    ds_token::seize(
        &auth,
        &mut investor_info,
        &rule,
        &mut vault1,
        INVESTOR1,
        &vault2,
        INVESTOR2, // Not an issuer wallet!
        50,
        b"invalid seize".to_string(),
        &version,
        ts.ctx(),
    );

    ts::return_shared(auth);
    ts::return_shared(investor_info);
    ts::return_shared(rule);
    ts::return_shared(version);
    ts::return_shared(vault1);
    ts::return_shared(vault2);
    ts.end();
}

// ==================== Arithmetic Helper Tests ====================

#[test]
fun test_try_from_u256_to_u64_valid() {
    let value: u256 = 1000;
    let result = ds_token::try_from_u256_to_u64(value);
    assert!(result == 1000, 0);

    // Test max u64 value
    let max_u64: u256 = 18446744073709551615;
    let result_max = ds_token::try_from_u256_to_u64(max_u64);
    assert!(result_max == 18446744073709551615, 1);
}

// ==================== Issuance Helper Tests ====================

#[test]
fun test_new_issuance_record() {
    let issuance = registry_service::new_issuance(1000, 1640000000000);
    assert!(registry_service::issuance_amount(&issuance) == 1000, 0);
    assert!(registry_service::issuance_time_ms(&issuance) == 1640000000000, 1);
}