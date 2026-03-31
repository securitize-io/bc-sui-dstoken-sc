/// Module: compliance_service
///
/// Core compliance engine that validates all token transfers against registered rules.
/// Manages compliance rules configuration, country-level restrictions, and coordinates
/// with the registry service to enforce transfer policies.
module securitize::compliance_service;

use pas::{request::Request, send_funds::SendFunds};
use securitize::{
    abilities::{RegisterRule, UnregisterRule, SetCountryCompliance, ManageRules},
    accredited_only::AccreditedOnly,
    authorized_securities::AuthorizedSecurities,
    backdating_issuance::BackdatingIssuance,
    events::{
        emit_compliance_rule_added_event,
        emit_compliance_rule_removed_event,
        emit_compliance_transfer_recorded_event,
        emit_compliance_issuance_recorded_event,
        emit_compliance_burn_recorded_event,
        emit_compliance_seize_recorded_event,
        emit_string_to_uint_map_rule_set_event
    },
    flowback_restriction::FlowbackRestriction,
    force_full_transfer::ForceFullTransfer,
    holding_limits::HoldingLimits,
    investor_limits::InvestorLimits,
    lock_manager,
    lockup_restriction::LockupRestriction,
    registry_service::{InvestorInfo, is_special_wallet, Issuance, new_issuance},
    rule_wrapper::{Self, RuleInitWrapper, unwrap_update, RuleUpdateWrapper},
    trust_service::{Auth, TransferAgent, Master},
    version::Version,
    wallet_manager::is_issuer_wallet
};
use std::{string::String, type_name::{Self, TypeName}};
use sui::{bag::{Self, Bag}, balance::Balance, clock::timestamp_ms, derived_object};

// ==== Error Codes ====

#[error(code = 0)]
const ERuleNotFound: vector<u8> = b"Compliance rule not found in the registry";
#[error(code = 1)]
const ERuleAlreadyExists: vector<u8> = b"Compliance rule already exists in the registry";
#[error(code = 2)]
const EDestinationRestricted: vector<u8> = b"Destination country is restricted for transfers";
#[error(code = 3)]
const ENotWhitelisted: vector<u8> = b"Investor is not whitelisted for this token";
#[error(code = 4)]
const ETotalInvestorsUnderflow: vector<u8> = b"Total investors count would underflow";
#[error(code = 6)]
const ETokensLocked: vector<u8> = b"Transfer amount exceeds unlocked token balance";
#[error(code = 7)]
const EInvestorLiquidateOnly: vector<u8> = b"Investor is in liquidate-only mode";
#[error(code = 8)]
const ENotIssuerWallet: vector<u8> = b"Destination must be an issuer wallet";
#[error(code = 9)]
const ENotAuthorized: vector<u8> = b"Caller is not authorized to perform this action";
#[error(code = 10)]
const EArithmeticOverflow: vector<u8> = b"Arithmetic overflow occurred";

// ==== Compliance Region Constants ====

const NONE: u64 = 0;
const FORBIDDEN: u64 = 4;

public struct ComplianceServiceKey<phantom T>() has copy, drop, store;

// ==== Structs ====

/// Configuration struct that keeps rules for asset type T
public struct ComplianceConfig<phantom T> has key {
    id: UID,
    /// Type names -> rule objects
    rules_bag: Bag,
    /// Set of rules for the asset T
    rules: vector<TypeName>,
}

/// Holds contextual information for a transfer operation
public struct TransferInfo has copy, drop {
    amount: u64,
    equal_country: bool,
    equal_region: bool,
    timestamp_ms: u64,
}

/// Holds contextual information for an issuance operation
public struct IssuanceInfo has copy, drop {
    amount: u64,
    total_supply: u64,
    timestamp_ms: u64,
}

/// Holds all relevant information about a party (sender or recipient) in a transfer/issuance
public struct PartyInfo has copy, drop {
    addr: address,
    investor_id: Option<String>,
    country: String,
    region: u64,
    balance: u64,
    transferable_balance: u64,
    is_accredited: bool,
    is_qualified: bool,
    is_exit_investor: bool,
    is_new_investor: bool,
    is_special_wallet: bool,
}

// ==================== Initialization Functions ====================

/// Create a new ComplianceConfig for token type T
public(package) fun new<T>(
    uid: &mut UID,
    auth: &mut Auth<T>,
    version: &Version,
    ctx: &mut TxContext,
): ComplianceConfig<T> {
    auth.add_role_ability<T, Master, RegisterRule>(version, ctx);
    auth.add_role_ability<T, Master, UnregisterRule>(version, ctx);
    auth.add_role_ability<T, Master, SetCountryCompliance>(version, ctx);
    auth.add_role_ability<T, Master, ManageRules>(version, ctx);

    auth.add_role_ability<T, TransferAgent, RegisterRule>(version, ctx);
    auth.add_role_ability<T, TransferAgent, UnregisterRule>(version, ctx);
    auth.add_role_ability<T, TransferAgent, SetCountryCompliance>(version, ctx);
    auth.add_role_ability<T, TransferAgent, ManageRules>(version, ctx);

    ComplianceConfig<T> {
        id: derived_object::claim(uid, ComplianceServiceKey<T>()),
        rules_bag: bag::new(ctx),
        rules: vector[],
    }
}

/// Makes the ComplianceConfig a shared object for public access
public(package) fun share<T>(config: ComplianceConfig<T>) {
    transfer::share_object(config);
}

// ==================== Validation Functions ====================

/// Validate transfer action against all configured rules
public(package) fun validate_transfer<T>(
    config: &ComplianceConfig<T>,
    registry: &mut InvestorInfo<T>,
    request: &Request<SendFunds<Balance<T>>>,
    current_time_ms: u64,
    version: &Version,
) {
    version.check_is_valid();

    let from_address = request.data().sender();
    let to_address = request.data().recipient();
    let amount = request.data().funds().value();

    assert!(
        registry.is_special_wallet(to_address) || registry.is_wallet(to_address),
        ENotWhitelisted,
    );

    // Get party info for both sides
    let mut from_info = get_party_info(registry, from_address, amount);
    let to_info = get_party_info(registry, to_address, 0);

    // Build transfer context
    let transfer = TransferInfo {
        amount,
        equal_country: &from_info.country == &to_info.country,
        equal_region: from_info.region == to_info.region,
        timestamp_ms: current_time_ms,
    };

    // === TO special wallet ===
    if (handle_transfer_to_special_wallet_exit(config, registry, &transfer, &from_info, &to_info))
        return;

    // === Same Investor ===
    // Same investor: skip compliance, but exit invariant already enforced
    if (handle_same_investor_exit(config, registry, &transfer, &from_info, &to_info)) return;

    assert!(to_info.region != FORBIDDEN, EDestinationRestricted);

    // Validate sender lock constraints and get transferable balance
    from_info.transferable_balance =
        assert_and_compute_transferable_balance(registry, &from_info, amount, current_time_ms);

    // Validate recipient is not in liquidate-only mode
    assert_not_liquidate_only(registry, &to_info);
    let empty_issuances: vector<Issuance> = vector[];
    // Get sender's issuances for lockup rule validation
    let from_issuances_data = if (!from_info.is_special_wallet) {
        let from_id = from_info.investor_id.borrow();
        registry.get_investor_issuances(*from_id)
    } else {
        &empty_issuances
    };

    // Validate all configured rules
    config.rules.do_ref!(|rule| {
        validate_transfer_rule(
            config,
            registry,
            *rule,
            &transfer,
            &from_info,
            &to_info,
            from_issuances_data,
        );
    });

    record_transfer(config, registry, &transfer, &from_info, &to_info);
}

/// Validate issuance action against all configured rules
public(package) fun validate_issue<T>(
    config: &ComplianceConfig<T>,
    registry: &mut InvestorInfo<T>,
    to_address: address,
    amount: u64,
    total_supply: u64,
    issuance_time_ms: u64,
    current_time_ms: u64,
    version: &Version,
) {
    version.check_is_valid();

    assert!(
        registry.is_special_wallet(to_address) || registry.is_wallet(to_address),
        ENotWhitelisted,
    );

    // Get party info for recipient
    let to_info = get_party_info(registry, to_address, amount);

    assert!(to_info.region != FORBIDDEN, EDestinationRestricted);

    // Resolve effective issuance timestamp based on backdating rule
    let effective_time_ms = resolve_issuance_time(config, issuance_time_ms, current_time_ms);

    // Build issuance context
    let issuance = IssuanceInfo {
        amount,
        total_supply,
        timestamp_ms: effective_time_ms,
    };

    if (handle_issuance_to_special_wallet_exit(config, &issuance, &to_info)) return;

    // Validate recipient is not in liquidate-only mode
    assert_not_liquidate_only(registry, &to_info);

    // Validate all configured rules
    config.rules.do_ref!(|rule| {
        validate_issuance_rule(
            config,
            registry,
            *rule,
            &issuance,
            &to_info,
        );
    });

    record_issuance(config, registry, &issuance, &to_info, current_time_ms);
}

/// Validate burn action against all configured rules
public(package) fun validate_burn<T>(
    registry: &mut InvestorInfo<T>,
    from_address: address,
    amount: u64,
) {
    let from_info = get_party_info(registry, from_address, amount);
    record_burn(registry, &from_info, amount);
}

/// Validate seize (clawback) action against all configured rules
public(package) fun validate_seize<T>(
    registry: &mut InvestorInfo<T>,
    from_address: address,
    to_address: address,
    amount: u64,
) {
    assert!(is_issuer_wallet(registry, to_address), ENotIssuerWallet);
    let from_info = get_party_info(registry, from_address, amount);
    record_seize(registry, &from_info, amount);
}

// ==================== Rule Management Functions ====================

/// Register a new rule to type `T`.
/// Adds the rule object to the rules bag and registers its type.
///
/// # Aborts
/// * `ENotAuthorized` - If caller lacks RegisterRule ability
/// * `ERuleAlreadyExists` - If the rule type is already registered
public fun register_rule<T, R: store>(
    self: &mut ComplianceConfig<T>,
    auth: &Auth<T>,
    wrapper: RuleInitWrapper<T, R>,
    version: &Version,
    ctx: &TxContext,
) {
    version.check_is_valid();
    assert!(auth.owner_has_ability<T, RegisterRule>(ctx.sender()), ENotAuthorized);
    let rule_type = type_name::with_defining_ids<R>();
    // Check if rule already exists
    assert!(!self.rules.contains(&rule_type), ERuleAlreadyExists);
    // Add the rule object to the bag
    self.rules_bag.add(rule_type, wrapper.unwrap_init());
    // Add the typename to the rules vector
    self.rules.push_back(rule_type);
    // Emit event
    emit_compliance_rule_added_event<T>(rule_type);
}

/// Unregister a rule from type `T`.
/// Removes the rule object from the rules bag and unregisters its type.
///
/// # Aborts
/// * `ENotAuthorized` - If caller lacks UnregisterRule ability
/// * `ERuleNotFound` - If the rule type is not registered
public fun unregister_rule<T, R: store + drop>(
    self: &mut ComplianceConfig<T>,
    auth: &Auth<T>,
    version: &Version,
    ctx: &TxContext,
) {
    version.check_is_valid();
    assert!(auth.owner_has_ability<T, UnregisterRule>(ctx.sender()), ENotAuthorized);
    let rule_type = type_name::with_defining_ids<R>();
    // Remove the typename from the rules vector
    let (exists, idx) = self.rules.index_of(&rule_type);
    assert!(exists, ERuleNotFound);
    self.rules.remove(idx);
    // Remove the rule object from the bag (it will be dropped automatically)
    let _rule: R = self.rules_bag.remove(rule_type);
    // Emit event
    emit_compliance_rule_removed_event<T>(rule_type);
}

/// Check if a specific rule type is registered
public fun has_rule<T, R: store>(config: &ComplianceConfig<T>): bool {
    let rule_type = type_name::with_defining_ids<R>();
    config.rules.contains(&rule_type)
}

/// Get a rule configuration wrapped in a hot potato.
/// The rule is removed from the bag and must be returned via `return_rule`.
///
/// # Aborts
/// * `ENotAuthorized` - If caller lacks ManageRules ability
public fun get_rule<T, R: store + drop>(
    self: &mut ComplianceConfig<T>,
    auth: &Auth<T>,
    version: &Version,
    ctx: &TxContext,
): RuleUpdateWrapper<T, R> {
    version.check_is_valid();
    assert!(auth.owner_has_ability<T, ManageRules>(ctx.sender()), ENotAuthorized);
    let rule_type = type_name::with_defining_ids<R>();
    let rule: R = self.rules_bag.remove(rule_type);
    rule_wrapper::new_update(rule)
}

/// Return a rule back to the compliance config.
/// Consumes the hot potato wrapper and adds the rule back to the bag.
///
/// # Aborts
/// * `ENotAuthorized` - If caller lacks ManageRules ability
public fun return_rule<T, R: store + drop>(
    self: &mut ComplianceConfig<T>,
    auth: &Auth<T>,
    wrapper: RuleUpdateWrapper<T, R>,
    version: &Version,
    ctx: &TxContext,
) {
    version.check_is_valid();
    assert!(auth.owner_has_ability<T, ManageRules>(ctx.sender()), ENotAuthorized);
    let rule_type = type_name::with_defining_ids<R>();
    self.rules_bag.add(rule_type, wrapper.unwrap_update());
}

/// Borrow an immutable reference to a rule configuration.
/// Use this for read-only access to rule state.
public fun borrow_rule<T, R: store + drop>(self: &ComplianceConfig<T>): &R {
    let rule_type = type_name::with_defining_ids<R>();
    self.rules_bag.borrow(rule_type)
}

/// Get immutable reference to the rules vector
public fun rules_vector<T>(self: &ComplianceConfig<T>): &vector<TypeName> {
    &self.rules
}

// ==================== Country Compliance Configuration ====================

/// Set compliance region for a country.
///
/// # Aborts
/// * `ENotAuthorized` - If caller lacks SetCountryCompliance ability
public fun set_country_compliance<T>(
    registry: &mut InvestorInfo<T>,
    country: String,
    compliance_region: u64,
    auth: &Auth<T>,
    version: &Version,
    ctx: &TxContext,
) {
    version.check_is_valid();
    assert!(auth.owner_has_ability<T, SetCountryCompliance>(ctx.sender()), ENotAuthorized);
    let previous_value = registry.get_country_compliance(country);
    registry.set_country_compliance(country, compliance_region);
    emit_string_to_uint_map_rule_set_event<T>(
        b"countryCompliance".to_string(),
        country,
        previous_value,
        compliance_region,
    );
}

/// Get compliance region for a country
public fun get_country_compliance<T>(registry: &InvestorInfo<T>, country: String): u64 {
    registry.get_country_compliance(country)
}

// ==================== Recorders ====================

/// Record issuance and update investor counts (handles both regular investors and special wallets)
public(package) fun record_issuance<T>(
    config: &ComplianceConfig<T>,
    registry: &mut InvestorInfo<T>,
    issuance: &IssuanceInfo,
    to: &PartyInfo,
    current_time_ms: u64,
) {
    if (issuance.amount == 0) return;

    // === TO side ===
    if (to.is_new_investor) {
        adjust_total_investors_counts<T>(
            registry,
            to.addr,
            to.is_special_wallet,
            true,
        );
    };

    // Record issuance based on wallet type
    if (!to.is_special_wallet) {
        let to_id = to.investor_id.borrow();
        let issuances = registry.get_investor_issuances_mut(*to_id);
        issuances.push_back(new_issuance(issuance.amount, issuance.timestamp_ms));
    };

    cleanup_party_issuances(config, registry, to, current_time_ms);

    emit_compliance_issuance_recorded_event<T>(to.addr, issuance.amount);
}

/// Record transfer and update investor counts
public(package) fun record_transfer<T>(
    config: &ComplianceConfig<T>,
    registry: &mut InvestorInfo<T>,
    transfer: &TransferInfo,
    from: &PartyInfo,
    to: &PartyInfo,
) {
    if (transfer.amount == 0) return;

    // === TO side ===
    if (to.is_new_investor) {
        adjust_total_investors_counts<T>(
            registry,
            to.addr,
            to.is_special_wallet,
            true,
        );
    };

    // === FROM side ===
    if (!is_same_investor(from, to) && from.is_exit_investor) {
        adjust_total_investors_counts<T>(
            registry,
            from.addr,
            from.is_special_wallet,
            false,
        );
    };

    cleanup_party_issuances(config, registry, from, transfer.timestamp_ms);
    cleanup_party_issuances(config, registry, to, transfer.timestamp_ms);

    emit_compliance_transfer_recorded_event<T>(from.addr, to.addr, transfer.amount);
}

/// Record burn and update investor counts
public(package) fun record_burn<T>(registry: &mut InvestorInfo<T>, from: &PartyInfo, amount: u64) {
    if (amount == 0) return;

    // === FROM side ===
    if (from.is_exit_investor) {
        adjust_total_investors_counts<T>(
            registry,
            from.addr,
            from.is_special_wallet,
            false,
        );
    };

    emit_compliance_burn_recorded_event<T>(from.addr, amount);
}

/// Record seize (clawback) and update investor counts
public(package) fun record_seize<T>(registry: &mut InvestorInfo<T>, from: &PartyInfo, amount: u64) {
    if (amount == 0) return;

    // === FROM side ===
    if (from.is_exit_investor) {
        adjust_total_investors_counts<T>(
            registry,
            from.addr,
            from.is_special_wallet,
            false,
        );
    };

    emit_compliance_seize_recorded_event<T>(from.addr, amount);
}

/// Adjust total investor counts (increment or decrement)
public(package) fun adjust_total_investors_counts<T>(
    registry: &mut InvestorInfo<T>,
    wallet: address,
    is_special_wallet: bool,
    increase: bool,
) {
    if (is_special_wallet) return;

    let total = registry.get_total_investors_count();

    if (increase) {
        registry.set_total_investors_count_internal(total + 1);
    } else {
        assert!(total > 0, ETotalInvestorsUnderflow);
        registry.set_total_investors_count_internal(total - 1);
    };

    // country + accreditation breakdown
    let investor_id = registry.get_investor_id_by_wallet(wallet);
    let country = registry.get_country(investor_id);

    registry.adjust_investors_counts_by_country<T>(
        investor_id,
        country,
        increase,
    );
}

// ==================== Issuance Management Functions ====================

/// Record a new issuance for an investor (for lockup tracking)
public(package) fun record_investor_issuance<T>(
    registry: &mut InvestorInfo<T>,
    investor_id: String,
    amount: u64,
    issuance_time_ms: u64,
) {
    if (amount == 0) return;

    let issuance = new_issuance(amount, issuance_time_ms);
    let issuances = registry.get_investor_issuances_mut(investor_id);
    issuances.push_back(issuance);
}

/// Cleanup expired issuances for a party (investor or special wallet) based on lock period
/// lock_period_ms == 0 means lockups are disabled:
/// - all issuances are cleared
/// - no transfer is ever blocked by lockup
fun cleanup_party_issuances<T>(
    config: &ComplianceConfig<T>,
    registry: &mut InvestorInfo<T>,
    party: &PartyInfo,
    now_ms: u64,
) {
    let issuances = if (!party.is_special_wallet) {
        let id = party.investor_id.borrow();
        registry.get_investor_issuances_mut(*id)
    } else {
        return
    };

    let lock_period_ms = get_lock_period_ms(config, party.region);

    // Lock period of 0 means no lockup - clear all issuances
    if (lock_period_ms == 0) {
        while (!issuances.is_empty()) {
            issuances.pop_back();
        };
        return
    };

    remove_if!(issuances, |issuance| {
        let lock_end_u256_ms = (issuance.issuance_time_ms() as u256) + (lock_period_ms as u256);
        let lock_end_ms = try_from_u256_to_u64!(lock_end_u256_ms);
        lock_end_ms <= now_ms
    })
}

/// Get lock period from LockupRestriction rule if registered, else 0
fun get_lock_period_ms<T>(config: &ComplianceConfig<T>, region: u64): u64 {
    if (has_rule<T, LockupRestriction>(config)) {
        let rule: &LockupRestriction = config
            .rules_bag
            .borrow(type_name::with_defining_ids<LockupRestriction>());
        rule.lock_period_for_region(region)
    } else {
        0
    }
}

/// Resolve the effective issuance timestamp.
///
/// Returns issuance_time_ms only if BackdatingIssuance rule exists AND allows backdating.
/// Otherwise returns current_time_ms (safe default).
fun resolve_issuance_time<T>(
    config: &ComplianceConfig<T>,
    issuance_time_ms: u64,
    current_time_ms: u64,
): u64 {
    if (!has_rule<T, BackdatingIssuance>(config)) {
        return current_time_ms
    };

    let rule: &BackdatingIssuance = config
        .rules_bag
        .borrow(type_name::with_defining_ids<BackdatingIssuance>());

    if (rule.is_backdating_allowed()) issuance_time_ms else current_time_ms
}

// ==================== Helper Functions ====================

/// Validate a single transfer rule
fun validate_transfer_rule<T>(
    config: &ComplianceConfig<T>,
    registry: &InvestorInfo<T>,
    rule: TypeName,
    transfer: &TransferInfo,
    from: &PartyInfo,
    to: &PartyInfo,
    from_issuances_data: &vector<Issuance>,
) {
    // Match on rule type and delegate to appropriate validator
    if (rule == type_name::with_defining_ids<AccreditedOnly>()) {
        let rule: &AccreditedOnly = config.rules_bag.borrow(rule);
        rule.validate_rule(to.region, to.is_accredited);
    } else if (rule == type_name::with_defining_ids<HoldingLimits>()) {
        let rule: &HoldingLimits = config.rules_bag.borrow(rule);
        rule.validate_holding_limits_for_transfer(
            transfer.amount,
            from.is_special_wallet,
            from.balance,
            from.region,
            to.balance,
            to.region,
        );
    } else if (rule == type_name::with_defining_ids<InvestorLimits>()) {
        let rule: &InvestorLimits = config.rules_bag.borrow(rule);
        rule.validate_investor_limits_for_transfer<T>(
            registry,
            from.is_accredited,
            from.is_exit_investor,
            from.is_qualified,
            to.region,
            to.country,
            to.is_accredited,
            to.is_qualified,
            to.is_new_investor,
            transfer.equal_region,
            transfer.equal_country,
        );
    } else if (rule == type_name::with_defining_ids<ForceFullTransfer>()) {
        let rule: &ForceFullTransfer = config.rules_bag.borrow(rule);
        rule.validate_rule(from.region, from.is_special_wallet, from.is_exit_investor);
    } else if (rule == type_name::with_defining_ids<FlowbackRestriction>()) {
        let rule: &FlowbackRestriction = config.rules_bag.borrow(rule);
        rule.validate_rule(from.region, to.region, from.is_special_wallet, transfer.timestamp_ms);
    } else if (rule == type_name::with_defining_ids<LockupRestriction>()) {
        let rule: &LockupRestriction = config.rules_bag.borrow(rule);
        rule.validate_rule(
            from_issuances_data,
            transfer.amount,
            from.region,
            from.is_special_wallet,
            from.transferable_balance,
            transfer.timestamp_ms,
        );
    }
}

/// Validate a single issuance rule
fun validate_issuance_rule<T>(
    config: &ComplianceConfig<T>,
    registry: &InvestorInfo<T>,
    rule: TypeName,
    issuance: &IssuanceInfo,
    to: &PartyInfo,
) {
    if (rule == type_name::with_defining_ids<AccreditedOnly>()) {
        let rule: &AccreditedOnly = config.rules_bag.borrow(rule);
        rule.validate_rule(to.region, to.is_accredited);
    } else if (rule == type_name::with_defining_ids<HoldingLimits>()) {
        let rule: &HoldingLimits = config.rules_bag.borrow(rule);
        rule.validate_holding_limits_for_issuance(issuance.amount, to.balance, to.region);
    } else if (rule == type_name::with_defining_ids<InvestorLimits>()) {
        let rule: &InvestorLimits = config.rules_bag.borrow(rule);
        rule.validate_investor_limits_for_issuance(
            registry,
            to.region,
            to.country,
            to.is_accredited,
            to.is_qualified,
            to.is_new_investor,
        );
    } else if (rule == type_name::with_defining_ids<AuthorizedSecurities>()) {
        let rule: &AuthorizedSecurities = config.rules_bag.borrow(rule);
        rule.validate_rule(issuance.total_supply, issuance.amount);
    };
}

/// Loads all relevant compliance and investor state for a given wallet address.
/// For **non-special wallets**, it resolves:
/// - the investor ID (as Some(id)),
/// - the country and mapped compliance region,
/// - total token balance across all wallets,
/// - accreditation and qualification status,
/// - whether the investor is new (balance == 0),
/// - whether the outgoing transfer represents a full exit (balance == amount).
///
/// For **special wallets**, all fields are defaulted (region = NONE, booleans = false,
/// balance = 0, investor_id = none).
fun get_party_info<T>(registry: &InvestorInfo<T>, addr: address, amount: u64): PartyInfo {
    let is_special = registry.is_special_wallet(addr);

    if (is_special) {
        return PartyInfo {
            addr: addr,
            investor_id: option::none(),
            country: std::string::utf8(b""),
            region: NONE,
            balance: 0, // intentionally unused for special wallets (early exit invariant)
            transferable_balance: 0, // intentionally unused for special wallets (early exit invariant)
            is_accredited: false,
            is_qualified: false,
            is_exit_investor: false,
            is_new_investor: false,
            is_special_wallet: true,
        }
    };

    let id = registry.get_investor_id_by_wallet(addr);
    let country = registry.get_country(id);
    let region = registry.get_country_compliance(country);
    let balance = registry.investor_wallet_balance_total(id);
    let accredited = registry.is_accredited_investor_by_id(id);
    let qualified = registry.is_qualified_investor_by_id(id);
    let exit = balance == amount;
    let is_new = balance == 0;

    PartyInfo {
        addr: addr,
        investor_id: option::some(id),
        country,
        region,
        balance,
        transferable_balance: balance, // Will be updated separately for sender
        is_accredited: accredited,
        is_qualified: qualified,
        is_exit_investor: exit,
        is_new_investor: is_new,
        is_special_wallet: false,
    }
}

/// Check if sender and recipient are the same investor
fun is_same_investor(from: &PartyInfo, to: &PartyInfo): bool {
    if (from.is_special_wallet || to.is_special_wallet) return false;
    let from_id = from.investor_id.borrow();
    let to_id = to.investor_id.borrow();
    *from_id == *to_id
}

/// Handle same-investor transfer (skip compliance, record transfer). Returns true if handled.
fun handle_same_investor_exit<T>(
    config: &ComplianceConfig<T>,
    registry: &mut InvestorInfo<T>,
    transfer: &TransferInfo,
    from: &PartyInfo,
    to: &PartyInfo,
): bool {
    if (!is_same_investor(from, to)) return false;
    record_transfer(config, registry, transfer, from, to);
    true
}

/// Handle transfer to special wallet (only validate ForceFullTransfer). Returns true if handled.
fun handle_transfer_to_special_wallet_exit<T>(
    config: &ComplianceConfig<T>,
    registry: &mut InvestorInfo<T>,
    transfer: &TransferInfo,
    from: &PartyInfo,
    to: &PartyInfo,
): bool {
    if (!to.is_special_wallet) return false;

    if (has_rule<T, ForceFullTransfer>(config)) {
        let rule: &ForceFullTransfer = config
            .rules_bag
            .borrow(type_name::with_defining_ids<ForceFullTransfer>());
        rule.validate_rule(from.region, from.is_special_wallet, from.is_exit_investor);
    };

    record_transfer(config, registry, transfer, from, to);
    true
}

/// Handle issuance to special wallet (only validate AuthorizedSecurities). Returns true if handled.
fun handle_issuance_to_special_wallet_exit<T>(
    config: &ComplianceConfig<T>,
    issuance: &IssuanceInfo,
    to: &PartyInfo,
): bool {
    if (!to.is_special_wallet) return false;

    if (has_rule<T, AuthorizedSecurities>(config)) {
        let rule: &AuthorizedSecurities = config
            .rules_bag
            .borrow(type_name::with_defining_ids<AuthorizedSecurities>());
        rule.validate_rule(issuance.total_supply, issuance.amount);
    };
    true
}

/// Validates sender-side lock constraints.
/// Returns the transferable balance for the sender.
/// Aborts with ETokensLocked if the transfer amount exceeds transferable tokens.
fun assert_and_compute_transferable_balance<T>(
    registry: &InvestorInfo<T>,
    from: &PartyInfo,
    amount: u64,
    timestamp_ms: u64,
): u64 {
    if (from.is_special_wallet) return from.balance;

    let from_id = from.investor_id.borrow();
    let transferable = lock_manager::compute_transferable(
        registry,
        *from_id,
        from.balance,
        timestamp_ms,
    );

    assert!(transferable >= amount, ETokensLocked);
    transferable
}

/// Validates that the recipient is not in liquidate-only mode.
/// Aborts with EInvestorLiquidateOnly if recipient is restricted.
fun assert_not_liquidate_only<T>(registry: &InvestorInfo<T>, to: &PartyInfo) {
    if (to.is_special_wallet) return;

    let to_id = to.investor_id.borrow();
    assert!(!lock_manager::is_liquidate_only(registry, *to_id), EInvestorLiquidateOnly);
}

// ==== Macros ====

/// Remove elements from vector where predicate returns true (in-place, O(1) per removal)
macro fun remove_if<$T: drop>($v: &mut vector<$T>, $pred: |&$T| -> bool) {
    let v = $v;
    let mut i = 0;
    while (i < v.length()) {
        if ($pred(&v[i])) {
            v.swap_remove(i);
        } else {
            i = i + 1;
        }
    }
}

// Try to safely convert u256 to u64
macro fun try_from_u256_to_u64($number: u256): u64 {
    let mut number_option = std::u256::try_as_u64($number);
    assert!(number_option.is_some(), EArithmeticOverflow);
    number_option.extract()
}
