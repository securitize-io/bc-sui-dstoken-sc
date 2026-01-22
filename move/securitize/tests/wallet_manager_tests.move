#[test_only]
module securitize::wallet_manager_tests;

use pas::namespace::{Self, Namespace};
use securitize::{
    abilities::{SetIssuerWallet, SetPlatformWallet, RemoveSpecialWallet},
    registry_service::{Self, InvestorInfo},
    setup::{Self, SetupRegistry},
    trust_service::{Self, Auth, Master},
    version::{Self, Version},
    wallet_manager
};
use sui::test_scenario::{Self as ts, Scenario};
use securitize::test_helpers::TEST_VOLORO;
use securitize::test_helpers::setup_with_treasury;

const ADMIN: address = @0x001;
const UNAUTHORIZED: address = @0x002;
const WALLET1: address = @0x1001;
const WALLET2: address = @0x1002;
const WALLET3: address = @0x1003;

fun setup_for_testing(ts: &mut Scenario) {
    ts.next_tx(ADMIN);
    setup_with_treasury(ts);
}

#[test]
fun test_is_issuer_wallet() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();

    // Initially, wallet should not be an issuer wallet
    assert!(!wallet_manager::is_issuer_wallet(&investor_info, WALLET1), 0);

    ts::return_shared(investor_info);
    ts.end();
}

#[test]
fun test_is_platform_wallet() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();

    // Initially, wallet should not be a platform wallet
    assert!(!wallet_manager::is_platform_wallet(&investor_info, WALLET1), 0);

    ts::return_shared(investor_info);
    ts.end();
}

// ==================== Add Issuer Wallet Tests ====================

#[test]
fun test_add_issuer_wallet() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let mut namespace = ts.take_shared<Namespace>();

    // Add issuer wallet
    wallet_manager::add_issuer_wallet<TEST_VOLORO>(
        &mut investor_info,
        &auth,
        &mut namespace,
        WALLET1,
        &version,
        ts.ctx(),
    );

    // Verify it's an issuer wallet
    assert!(wallet_manager::is_issuer_wallet(&investor_info, WALLET1), 0);
    // Verify it's not a platform wallet
    assert!(!wallet_manager::is_platform_wallet(&investor_info, WALLET1), 1);

    ts::return_shared(investor_info);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts::return_shared(namespace);
    ts.end();
}

#[test]
#[expected_failure(abort_code = wallet_manager::ENotAuthorized)]
fun test_add_issuer_wallet_unauthorized() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(UNAUTHORIZED);
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let mut namespace = ts.take_shared<Namespace>();

    // Should fail - UNAUTHORIZED has no SetIssuerWallet ability
    wallet_manager::add_issuer_wallet<TEST_VOLORO>(
        &mut investor_info,
        &auth,
        &mut namespace,
        WALLET1,
        &version,
        ts.ctx(),
    );

    ts::return_shared(investor_info);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts::return_shared(namespace);
    ts.end();
}

// ==================== Add Platform Wallet Tests ====================

#[test]
fun test_add_platform_wallet() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let mut namespace = ts.take_shared<Namespace>();

    // Add platform wallet
    wallet_manager::add_platform_wallet<TEST_VOLORO>(
        &mut investor_info,
        &auth,
        &mut namespace,
        WALLET1,
        &version,
        ts.ctx(),
    );

    // Verify it's a platform wallet
    assert!(wallet_manager::is_platform_wallet(&investor_info, WALLET1), 0);
    // Verify it's not an issuer wallet
    assert!(!wallet_manager::is_issuer_wallet(&investor_info, WALLET1), 1);

    ts::return_shared(investor_info);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts::return_shared(namespace);
    ts.end();
}

#[test]
#[expected_failure(abort_code = wallet_manager::ENotAuthorized)]
fun test_add_platform_wallet_unauthorized() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(UNAUTHORIZED);
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let mut namespace = ts.take_shared<Namespace>();

    // Should fail - UNAUTHORIZED has no SetPlatformWallet ability
    wallet_manager::add_platform_wallet<TEST_VOLORO>(
        &mut investor_info,
        &auth,
        &mut namespace,
        WALLET1,
        &version,
        ts.ctx(),
    );

    ts::return_shared(investor_info);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts::return_shared(namespace);
    ts.end();
}

// ==================== Remove Special Wallet Tests ====================

#[test]
fun test_remove_issuer_wallet() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let mut namespace = ts.take_shared<Namespace>();

    // Add issuer wallet
    wallet_manager::add_issuer_wallet<TEST_VOLORO>(
        &mut investor_info,
        &auth,
        &mut namespace,
        WALLET1,
        &version,
        ts.ctx(),
    );

    assert!(wallet_manager::is_issuer_wallet(&investor_info, WALLET1), 0);

    // Remove special wallet
    wallet_manager::remove_special_wallet<TEST_VOLORO>(
        &mut investor_info,
        &auth,
        WALLET1,
        &version,
        ts.ctx(),
    );

    // Verify it's no longer an issuer wallet
    assert!(!wallet_manager::is_issuer_wallet(&investor_info, WALLET1), 1);

    ts::return_shared(investor_info);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts::return_shared(namespace);
    ts.end();
}

#[test]
fun test_remove_platform_wallet() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let mut namespace = ts.take_shared<Namespace>();

    // Add platform wallet
    wallet_manager::add_platform_wallet<TEST_VOLORO>(
        &mut investor_info,
        &auth,
        &mut namespace,
        WALLET1,
        &version,
        ts.ctx(),
    );

    assert!(wallet_manager::is_platform_wallet(&investor_info, WALLET1), 0);

    // Remove special wallet
    wallet_manager::remove_special_wallet<TEST_VOLORO>(
        &mut investor_info,
        &auth,
        WALLET1,
        &version,
        ts.ctx(),
    );

    // Verify it's no longer a platform wallet
    assert!(!wallet_manager::is_platform_wallet(&investor_info, WALLET1), 1);

    ts::return_shared(investor_info);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts::return_shared(namespace);
    ts.end();
}

#[test]
#[expected_failure(abort_code = wallet_manager::ENotAuthorized)]
fun test_remove_special_wallet_unauthorized() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let mut namespace = ts.take_shared<Namespace>();

    // Add issuer wallet as admin
    wallet_manager::add_issuer_wallet<TEST_VOLORO>(
        &mut investor_info,
        &auth,
        &mut namespace,
        WALLET1,
        &version,
        ts.ctx(),
    );

    ts::return_shared(investor_info);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts::return_shared(namespace);

    // Try to remove as unauthorized user
    ts.next_tx(UNAUTHORIZED);
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    wallet_manager::remove_special_wallet<TEST_VOLORO>(
        &mut investor_info,
        &auth,
        WALLET1,
        &version,
        ts.ctx(),
    );

    ts::return_shared(investor_info);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

#[test]
#[expected_failure(abort_code = wallet_manager::ENotSpecialWallet)]
fun test_remove_non_special_wallet() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    // Try to remove a wallet that was never added as special
    wallet_manager::remove_special_wallet<TEST_VOLORO>(
        &mut investor_info,
        &auth,
        WALLET1,
        &version,
        ts.ctx(),
    );

    ts::return_shared(investor_info);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts.end();
}

// ==================== Direct Wallet Change Tests ====================

#[test]
#[expected_failure(abort_code = wallet_manager::EDirectWalletChange)]
fun test_cannot_change_issuer_to_platform_directly() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let mut namespace = ts.take_shared<Namespace>();

    // Add as issuer wallet
    wallet_manager::add_issuer_wallet<TEST_VOLORO>(
        &mut investor_info,
        &auth,
        &mut namespace,
        WALLET1,
        &version,
        ts.ctx(),
    );

    // Try to add same wallet as platform (should fail)
    wallet_manager::add_platform_wallet<TEST_VOLORO>(
        &mut investor_info,
        &auth,
        &mut namespace,
        WALLET1,
        &version,
        ts.ctx(),
    );

    ts::return_shared(investor_info);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts::return_shared(namespace);
    ts.end();
}

#[test]
#[expected_failure(abort_code = wallet_manager::EDirectWalletChange)]
fun test_cannot_change_platform_to_issuer_directly() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let mut namespace = ts.take_shared<Namespace>();

    // Add as platform wallet
    wallet_manager::add_platform_wallet<TEST_VOLORO>(
        &mut investor_info,
        &auth,
        &mut namespace,
        WALLET1,
        &version,
        ts.ctx(),
    );

    // Try to add same wallet as issuer (should fail)
    wallet_manager::add_issuer_wallet<TEST_VOLORO>(
        &mut investor_info,
        &auth,
        &mut namespace,
        WALLET1,
        &version,
        ts.ctx(),
    );

    ts::return_shared(investor_info);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts::return_shared(namespace);
    ts.end();
}

// ==================== Multiple Special Wallets Tests ====================

#[test]
fun test_multiple_issuer_wallets() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let mut namespace = ts.take_shared<Namespace>();

    // Add multiple issuer wallets
    wallet_manager::add_issuer_wallet<TEST_VOLORO>(
        &mut investor_info,
        &auth,
        &mut namespace,
        WALLET1,
        &version,
        ts.ctx(),
    );

    wallet_manager::add_issuer_wallet<TEST_VOLORO>(
        &mut investor_info,
        &auth,
        &mut namespace,
        WALLET2,
        &version,
        ts.ctx(),
    );

    wallet_manager::add_issuer_wallet<TEST_VOLORO>(
        &mut investor_info,
        &auth,
        &mut namespace,
        WALLET3,
        &version,
        ts.ctx(),
    );

    // Verify all are issuer wallets
    assert!(wallet_manager::is_issuer_wallet(&investor_info, WALLET1), 0);
    assert!(wallet_manager::is_issuer_wallet(&investor_info, WALLET2), 1);
    assert!(wallet_manager::is_issuer_wallet(&investor_info, WALLET3), 2);

    ts::return_shared(investor_info);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts::return_shared(namespace);
    ts.end();
}

#[test]
fun test_multiple_platform_wallets() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let mut namespace = ts.take_shared<Namespace>();

    // Add multiple platform wallets
    wallet_manager::add_platform_wallet<TEST_VOLORO>(
        &mut investor_info,
        &auth,
        &mut namespace,
        WALLET1,
        &version,
        ts.ctx(),
    );

    wallet_manager::add_platform_wallet<TEST_VOLORO>(
        &mut investor_info,
        &auth,
        &mut namespace,
        WALLET2,
        &version,
        ts.ctx(),
    );

    // Verify all are platform wallets
    assert!(wallet_manager::is_platform_wallet(&investor_info, WALLET1), 0);
    assert!(wallet_manager::is_platform_wallet(&investor_info, WALLET2), 1);

    ts::return_shared(investor_info);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts::return_shared(namespace);
    ts.end();
}

#[test]
fun test_mixed_issuer_and_platform_wallets() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let mut namespace = ts.take_shared<Namespace>();

    // Add one issuer and one platform wallet
    wallet_manager::add_issuer_wallet<TEST_VOLORO>(
        &mut investor_info,
        &auth,
        &mut namespace,
        WALLET1,
        &version,
        ts.ctx(),
    );

    wallet_manager::add_platform_wallet<TEST_VOLORO>(
        &mut investor_info,
        &auth,
        &mut namespace,
        WALLET2,
        &version,
        ts.ctx(),
    );

    // Verify correct types
    assert!(wallet_manager::is_issuer_wallet(&investor_info, WALLET1), 0);
    assert!(!wallet_manager::is_platform_wallet(&investor_info, WALLET1), 1);
    assert!(wallet_manager::is_platform_wallet(&investor_info, WALLET2), 2);
    assert!(!wallet_manager::is_issuer_wallet(&investor_info, WALLET2), 3);

    ts::return_shared(investor_info);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts::return_shared(namespace);
    ts.end();
}

// ==================== Re-add After Remove Tests ====================

#[test]
fun test_readd_issuer_wallet_after_remove() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let mut namespace = ts.take_shared<Namespace>();

    // Add issuer wallet
    wallet_manager::add_issuer_wallet<TEST_VOLORO>(
        &mut investor_info,
        &auth,
        &mut namespace,
        WALLET1,
        &version,
        ts.ctx(),
    );

    assert!(wallet_manager::is_issuer_wallet(&investor_info, WALLET1), 0);

    // Remove it
    wallet_manager::remove_special_wallet<TEST_VOLORO>(
        &mut investor_info,
        &auth,
        WALLET1,
        &version,
        ts.ctx(),
    );

    assert!(!wallet_manager::is_issuer_wallet(&investor_info, WALLET1), 1);

    // Re-add as issuer wallet
    wallet_manager::add_issuer_wallet<TEST_VOLORO>(
        &mut investor_info,
        &auth,
        &mut namespace,
        WALLET1,
        &version,
        ts.ctx(),
    );

    assert!(wallet_manager::is_issuer_wallet(&investor_info, WALLET1), 2);

    ts::return_shared(investor_info);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts::return_shared(namespace);
    ts.end();
}

#[test]
fun test_change_wallet_type_via_remove_and_readd() {
    let mut ts = ts::begin(ADMIN);
    setup_for_testing(&mut ts);

    ts.next_tx(ADMIN);
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let mut namespace = ts.take_shared<Namespace>();

    // Add as issuer wallet
    wallet_manager::add_issuer_wallet<TEST_VOLORO>(
        &mut investor_info,
        &auth,
        &mut namespace,
        WALLET1,
        &version,
        ts.ctx(),
    );

    assert!(wallet_manager::is_issuer_wallet(&investor_info, WALLET1), 0);

    // Remove issuer wallet
    wallet_manager::remove_special_wallet<TEST_VOLORO>(
        &mut investor_info,
        &auth,
        WALLET1,
        &version,
        ts.ctx(),
    );

    // Re-add as platform wallet
    wallet_manager::add_platform_wallet<TEST_VOLORO>(
        &mut investor_info,
        &auth,
        &mut namespace,
        WALLET1,
        &version,
        ts.ctx(),
    );

    // Verify it's now a platform wallet, not issuer
    assert!(wallet_manager::is_platform_wallet(&investor_info, WALLET1), 1);
    assert!(!wallet_manager::is_issuer_wallet(&investor_info, WALLET1), 2);

    ts::return_shared(investor_info);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts::return_shared(namespace);
    ts.end();
}
