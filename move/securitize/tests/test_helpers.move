#[test_only]
/// Test helpers module for DS Token integration tests.
/// Provides utilities for setting up complete test environments with Treasury,
/// Auth, InvestorInfo, ComplianceConfig, and related objects.
/// Follows the TEST_VOLORO module pattern for creating DS Tokens.
module securitize::test_helpers;

use pas::namespace::{Self, Namespace};
use securitize::{
    compliance_service::{Self, ComplianceConfig},
    ds_token::Treasury,
    registry_service::{Self, InvestorInfo},
    setup::{Self, SetupRegistry, SetupFinalize},
    trust_service::Auth,
    version::{Self, Version},
    wallet_manager
};
use sui::{coin_registry::{Self, CoinRegistry}, test_scenario::{Self as ts, Scenario}};

// ==== Constants ====

const ADMIN: address = @0x001;
// ==== Test Token Type (following TEST_VOLORO pattern) ====

/// Test token type for DS Token tests (must have key ability like TEST_VOLORO)
public struct TEST_VOLORO has key {
    id: UID,
}

// // ==== Helper Functions ====

/// Initialize basic infrastructure (Version, SetupRegistry, Namespace)
public(package) fun init_basic_objects_for_testing(ts: &mut Scenario) {
    ts.next_tx(ADMIN);
    version::init_for_testing(ts.ctx());
    setup::init_for_testing(ts.ctx());
    init_namespace_for_testing(ts);
}

fun package_id<T>(): ID {
    sui::address::from_ascii_bytes(std::type_name::with_defining_ids<T>()
        .address_string()
        .as_bytes()).to_id()
}

/// Initialize a namespace with upgrade cap set (required by PAS).
/// Call this instead of `namespace::init_for_testing` directly.
public(package) fun init_namespace_for_testing(ts: &mut Scenario) {
    namespace::init_for_testing(ts.ctx());
    ts.next_tx(ADMIN);
    let mut ns = ts.take_shared<Namespace>();
    let pkg_id = package_id<Namespace>();
    let upgrade_cap = sui::package::test_publish(pkg_id, ts.ctx());
    namespace::setup(&mut ns, &upgrade_cap);
    transfer::public_transfer(upgrade_cap, ADMIN);
    ts::return_shared(ns);
}

/// Initialize CoinRegistry for testing (must be called from @0x0)
public(package) fun init_coin_registry(ts: &mut Scenario) {
    ts.next_tx(@0x0);
    let registry = coin_registry::create_coin_data_registry_for_testing(ts.ctx());
    coin_registry::share_for_testing(registry);
}

/// Create a DS Token following the TEST_VOLORO pattern.
/// This is the proper way to create a DS Token with Treasury.
public(package) fun create_ds_token(
    name: vector<u8>,
    symbol: vector<u8>,
    url: vector<u8>,
    description: vector<u8>,
    decimals: u8,
    setup_registry: &mut SetupRegistry,
    namespace: &mut Namespace,
    registry: &mut CoinRegistry,
    version: &Version,
    ctx: &mut TxContext,
): (
    Auth<TEST_VOLORO>,
    Treasury<TEST_VOLORO>,
    InvestorInfo<TEST_VOLORO>,
    ComplianceConfig<TEST_VOLORO>,
    SetupFinalize,
) {
    let (currency, treasury_cap) = coin_registry::new_currency<TEST_VOLORO>(
        registry,
        decimals,
        name.to_string(),
        symbol.to_string(),
        description.to_string(),
        url.to_string(),
        ctx,
    );
    let metadata_cap = currency.finalize(ctx);
    setup::setup(setup_registry, namespace, treasury_cap, metadata_cap, version, ctx)
}

/// Setup complete DS Token environment with Treasury.
/// This initializes all infrastructure and creates a full DS Token.
public(package) fun setup_with_treasury(ts: &mut Scenario) {
    // Initialize basic infrastructure
    init_basic_objects_for_testing(ts);
    // Initialize CoinRegistry from @0x0
    init_coin_registry(ts);

    // Create the DS Token from ADMIN
    ts.next_tx(ADMIN);
    let mut setup_registry = ts.take_shared<SetupRegistry>();
    let version = ts.take_shared<Version>();
    let mut namespace = ts.take_shared<Namespace>();
    let mut registry = ts.take_shared<CoinRegistry>();

    let (auth, treasury, investor_info, compliance, finalize) = create_ds_token(
        b"TEST_VOLORO Token",
        b"TEST_VOLORO",
        b"https://TEST_VOLORO.io/icon.png",
        b"A test security token",
        8,
        &mut setup_registry,
        &mut namespace,
        &mut registry,
        &version,
        ts.ctx(),
    );

    // Finalize setup - this shares all the objects
    setup::finalize_setup(finalize, auth, treasury, investor_info, compliance, &version);

    ts::return_shared(registry);
    ts::return_shared(namespace);
    ts::return_shared(version);
    ts::return_shared(setup_registry);
}

/// Register an investor with the given ID and add a wallet
public(package) fun register_investor_with_wallet(
    ts: &mut Scenario,
    investor_id: vector<u8>,
    wallet: address,
) {
    ts.next_tx(ADMIN);
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let mut namespace = ts.take_shared<Namespace>();

    // First register the investor
    registry_service::register_investor<TEST_VOLORO>(
        &mut investor_info,
        &auth,
        investor_id.to_string(),
        &version,
        ts.ctx(),
    );

    // Then add their wallet
    registry_service::add_wallet<TEST_VOLORO>(
        &mut investor_info,
        &auth,
        &mut namespace,
        investor_id.to_string(),
        wallet,
        &version,
        ts.ctx(),
    );

    ts::return_shared(investor_info);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts::return_shared(namespace);
}

/// Add a wallet to an existing investor
public(package) fun add_investor_wallet(
    ts: &mut Scenario,
    investor_id: vector<u8>,
    wallet: address,
) {
    ts.next_tx(ADMIN);
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let mut namespace = ts.take_shared<Namespace>();

    registry_service::add_wallet<TEST_VOLORO>(
        &mut investor_info,
        &auth,
        &mut namespace,
        investor_id.to_string(),
        wallet,
        &version,
        ts.ctx(),
    );

    ts::return_shared(investor_info);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts::return_shared(namespace);
}

/// Set investor country
public(package) fun set_investor_country(
    ts: &mut Scenario,
    investor_id: vector<u8>,
    country: vector<u8>,
) {
    ts.next_tx(ADMIN);
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    registry_service::set_country<TEST_VOLORO>(
        &mut investor_info,
        &auth,
        investor_id.to_string(),
        country.to_string(),
        &version,
        ts.ctx(),
    );

    ts::return_shared(investor_info);
    ts::return_shared(auth);
    ts::return_shared(version);
}

/// Set country compliance region
public(package) fun set_country_compliance(ts: &mut Scenario, country: vector<u8>, region: u64) {
    ts.next_tx(ADMIN);
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();

    compliance_service::set_country_compliance<TEST_VOLORO>(
        &mut investor_info,
        country.to_string(),
        region,
        &auth,
        &version,
        ts.ctx(),
    );

    ts::return_shared(investor_info);
    ts::return_shared(auth);
    ts::return_shared(version);
}

/// Add an issuer wallet
public(package) fun add_issuer_wallet(ts: &mut Scenario, wallet: address) {
    ts.next_tx(ADMIN);
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let mut namespace = ts.take_shared<Namespace>();

    wallet_manager::add_issuer_wallet<TEST_VOLORO>(
        &mut investor_info,
        &auth,
        &mut namespace,
        wallet,
        &version,
        ts.ctx(),
    );

    ts::return_shared(investor_info);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts::return_shared(namespace);
}

/// Add a platform wallet
public(package) fun add_platform_wallet(ts: &mut Scenario, wallet: address) {
    ts.next_tx(ADMIN);
    let mut investor_info = ts.take_shared<InvestorInfo<TEST_VOLORO>>();
    let auth = ts.take_shared<Auth<TEST_VOLORO>>();
    let version = ts.take_shared<Version>();
    let mut namespace = ts.take_shared<Namespace>();

    wallet_manager::add_platform_wallet<TEST_VOLORO>(
        &mut investor_info,
        &auth,
        &mut namespace,
        wallet,
        &version,
        ts.ctx(),
    );

    ts::return_shared(investor_info);
    ts::return_shared(auth);
    ts::return_shared(version);
    ts::return_shared(namespace);
}

/// Set up Templates for testing (required for template command tests)
public(package) fun setup_templates(ts: &mut Scenario) {
    ts.next_tx(ADMIN);
    let mut namespace = ts.take_shared<Namespace>();
    pas::templates::setup(&mut namespace);
    ts::return_shared(namespace);
}

/// One year in milliseconds (365 days)
public fun one_year_ms(): u64 { 31_536_000_000 }
