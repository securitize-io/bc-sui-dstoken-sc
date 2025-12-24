module securitize::compliance_service;

use rwa::{vault::RwaTransferRequest};
use securitize::{
    accredited_only::AccreditedOnly,
    holding_limits::HoldingLimits,
    investor_limits::InvestorLimits,
    trust_service::{Auth, TransferAgent, Master},
    version::Version,
};
use std::{type_name::{Self, TypeName}};
use sui::{bag::{Self, Bag}, event, derived_object};
use securitize::registry_service::InvestorInfo;
use std::string::String;
use securitize::force_full_transfer::ForceFullTransfer;
use securitize::flowback_restriction::FlowbackRestriction;
use securitize::wallet_manager::is_platform_wallet;
use securitize::registry_service::is_special_wallet;
use securitize::wallet_manager::is_issuer_wallet;
use sui::clock::timestamp_ms;
use securitize::registry_service::Issuance;
use securitize::registry_service::new_issuance;
use securitize::lockup_restriction::LockupRestriction;
use securitize::lock_manager;
use securitize::authorized_securities::AuthorizedSecurities;

// ==== Error Codes ====

const ERuleNotFound: u64 = 0;
const ERuleAlreadyExists: u64 = 1;
const EDestinationRestricted: u64 = 2;
const ENotWhitelisted: u64 = 3;
const ETotalInvestorsUnderflow: u64 = 4;
const ETokensLocked: u64 = 6;
const EInvestorLiquidateOnly: u64 = 7;

// ==== TEMP Compliance Region Constants ====

const NONE: u64 = 0;
const US: u64 = 1;
const EU: u64 = 2;
const FORBIDDEN: u64 = 4;
const JP: u64 = 8;

public struct ComplianceServiceKey<phantom T>() has copy, drop, store;

// ==== Events ====

public struct DSComplianceRuleAdded<phantom T> has copy, drop {
    rule_type: TypeName,
}

public struct DSComplianceRuleRemoved<phantom T> has copy, drop {
    rule_type: TypeName,
}

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
    address: address,
    investor_id: Option<String>,
    country: String,
    region: u64,
    balance: u64,
    transferable_balance: u64,
    is_accredited: bool,
    is_qualified: bool,
    is_exit_investor: bool,
    is_new_investor: bool,
    is_platform_wallet: bool,
    is_special_wallet: bool,
}

// ==== Compliance Abilities ====

public struct RegisterRule() has drop;

public struct UnregisterRule() has drop;

public struct SetCountryCompliance() has drop;

public struct ManageRules() has drop;

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
#[lint_allow(share_owned)]
public(package) fun share<T>(config: ComplianceConfig<T>) {
    transfer::share_object(config);
}

// ==================== Validation Functions ====================

/// Validate transfer action against all configured rules
public fun validate_transfer<T>(
    config: &ComplianceConfig<T>,
    registry: &mut InvestorInfo<T>,
    request: &RwaTransferRequest<T>,
    timestamp_ms: u64,
    version: &Version,
) {
    version.check_is_valid();

    let from_address = request.request_from_address();
    let to_address = request.request_to_address();
    let amount = request.request_amount();

    assert!(registry.is_special_wallet(to_address) || registry.is_wallet(to_address), ENotWhitelisted);

    // Get party info for both sides
    let mut from_info = get_party_info(registry, from_address, amount);
    let to_info = get_party_info(registry, to_address, amount);

    assert!(to_info.region != FORBIDDEN, EDestinationRestricted);

    // Build transfer context
    let transfer = TransferInfo {
        amount,
        equal_country: from_info.country == to_info.country,
        timestamp_ms,
    };

    // Determine which rules to apply
    let platform_rules = vector[type_name::with_defining_ids<ForceFullTransfer>()];
    let empty_rules = vector[];

    let mut rules = &config.rules;

    if (to_info.is_platform_wallet) {
        rules = &platform_rules;
    };

    if (from_address == to_address) {
        rules = &empty_rules;
    };

    // Handle sender-side lock checks and issuances
    let empty_issuances: &vector<Issuance> = &vector[];

    let from_investor_issuances_ref = if (!from_info.is_special_wallet) {
        let from_id = from_info.investor_id.borrow();

        let transferable = lock_manager::compute_transferable(
            registry,
            *from_id,
            from_info.balance,
            timestamp_ms,
        );

        // Update transferable balance in from_info
        from_info.transferable_balance = transferable;

        // GLOBAL lock invariant (TokenLocked)
        assert!(transferable >= amount, ETokensLocked);

        registry.get_investor_issuances(*from_id)
    } else {
        empty_issuances
    };

    // Check liquidate-only status for recipient
    if (!to_info.is_special_wallet) {
        let to_id = to_info.investor_id.borrow();
        assert!(!lock_manager::is_liquidate_only(registry, *to_id), EInvestorLiquidateOnly);
    };

    // Validate all configured rules
    rules.do_ref!(|rule| {
        validate_transfer_rule(
            config,
            registry,
            *rule,
            &transfer,
            &from_info,
            &to_info,
            from_investor_issuances_ref,
        );
    });

    record_transfer(config, registry, &transfer, &from_info, &to_info);
}

/// Validate issuance action against all configured rules
public fun validate_issue<T>(
    config: &mut ComplianceConfig<T>,
    registry: &mut InvestorInfo<T>,
    to_address: address,
    amount: u64,
    total_supply: u64,
    timestamp_ms: u64,
    version: &Version,
) {
    version.check_is_valid();

    assert!(registry.is_special_wallet(to_address) || registry.is_wallet(to_address), ENotWhitelisted);

    // Get party info for recipient
    let to_info = get_party_info(registry, to_address, amount);

    assert!(to_info.region != FORBIDDEN, EDestinationRestricted);

    // Skip checks for platform wallets
    if (to_info.is_platform_wallet) return;

    // Check liquidate-only status
    if (!to_info.is_special_wallet) {
        let to_id = to_info.investor_id.borrow();
        assert!(!lock_manager::is_liquidate_only(registry, *to_id), EInvestorLiquidateOnly);
    };

    // Build issuance context
    let issuance = IssuanceInfo {
        amount,
        total_supply,
        timestamp_ms,
    };

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

    record_issuance(config, registry, &issuance, &to_info);
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
    assert!(is_issuer_wallet(registry, to_address));
    let from_info = get_party_info(registry, from_address, amount);
    record_seize(registry, &from_info, amount);
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
    investor_issuances: &vector<Issuance>,
) {
    // Match on rule type and delegate to appropriate validator
    if (rule == type_name::with_defining_ids<AccreditedOnly>()) {
        let rule: &AccreditedOnly = config.rules_bag.borrow(rule);
        rule.validate_rule(to.region, to.is_accredited);
    } else if (rule == type_name::with_defining_ids<HoldingLimits>()) {
        let rule: &HoldingLimits = config.rules_bag.borrow(rule);
        rule.validate_holding_limits_for_transfer(
            transfer.amount,
            from.is_platform_wallet,
            from.balance,
            to.balance,
            from.region,
            to.region,
        );
    } else if (rule == type_name::with_defining_ids<InvestorLimits>()) {
        let rule: &InvestorLimits = config.rules_bag.borrow(rule);
        rule.validate_investor_limits_for_transfer<T>(
            registry,
            from.is_accredited,
            from.is_exit_investor,
            to.region,
            to.country,
            to.is_accredited,
            to.is_qualified,
            to.is_new_investor,
            transfer.equal_country,
        );
    } else if (rule == type_name::with_defining_ids<ForceFullTransfer>()) {
        let rule: &ForceFullTransfer = config.rules_bag.borrow(rule);
        rule.validate_rule(from.region, from.is_exit_investor);
    } else if (rule == type_name::with_defining_ids<FlowbackRestriction>()) {
        let rule: &FlowbackRestriction = config.rules_bag.borrow(rule);
        rule.validate_rule(from.region, to.region, from.is_platform_wallet, transfer.timestamp_ms);
    } else if (rule == type_name::with_defining_ids<LockupRestriction>()) {
        let rule: &LockupRestriction = config.rules_bag.borrow(rule);
        rule.validate_rule(investor_issuances, transfer.amount, from.region, from.is_platform_wallet, from.transferable_balance, transfer.timestamp_ms);
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
/// balance = 0, investor_id = none), and no registry lookups are performed.
fun get_party_info<T>(registry: &InvestorInfo<T>, addr: address, amount: u64): PartyInfo {
    let is_special = registry.is_special_wallet(addr);
    let is_platform = is_platform_wallet(registry, addr);

    if (is_special) {
        return PartyInfo {
            address: addr,
            investor_id: option::none(),
            country: b"".to_string(),
            region: NONE,
            balance: 0,
            transferable_balance: 0,
            is_accredited: false,
            is_qualified: false,
            is_exit_investor: false,
            is_new_investor: false,
            is_platform_wallet: is_platform,
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
        address: addr,
        investor_id: option::some(id),
        country,
        region,
        balance,
        transferable_balance: balance, // Will be updated separately for sender
        is_accredited: accredited,
        is_qualified: qualified,
        is_exit_investor: exit,
        is_new_investor: is_new,
        is_platform_wallet: is_platform,
        is_special_wallet: false,
    }
}

// ==================== Rule Management Functions ====================

/// Register a new rule to type `T`
/// Adds the rule object to the rules bag and registers its type
public fun register_rule<T, R: store>(
    self: &mut ComplianceConfig<T>,
    auth: &Auth<T>,
    rule: R,
    version: &Version,
    ctx: &TxContext,
) {
    version.check_is_valid();
    auth.owner_has_ability<T, RegisterRule>(ctx.sender());
    let rule_type = type_name::with_defining_ids<R>();
    // Check if rule already exists
    assert!(!self.rules.contains(&rule_type), ERuleAlreadyExists);
    // Add the rule object to the bag
    self.rules_bag.add(rule_type, rule);
    // Add the typename to the rules vector
    self.rules.push_back(rule_type);
    // Emit event
    event::emit(DSComplianceRuleAdded<T> { rule_type });
}

/// Unregister a rule from type `T`
/// Removes the rule object from the rules bag and unregisters its type
public fun unregister_rule<T, R: store + drop>(
    self: &mut ComplianceConfig<T>,
    auth: &Auth<T>,
    version: &Version,
    ctx: &TxContext,
) {
    version.check_is_valid();
    auth.owner_has_ability<T, UnregisterRule>(ctx.sender());
    let rule_type = type_name::with_defining_ids<R>();
    // Check if rule exists
    assert!(self.rules.contains(&rule_type), ERuleNotFound);
    // Remove the typename from the rules vector
    let (exists, idx) = self.rules.index_of(&rule_type);
    assert!(exists, ERuleNotFound);
    self.rules.remove(idx);
    // Remove the rule object from the bag (it will be dropped automatically)
    let _rule: R = self.rules_bag.remove(rule_type);
    // Emit event
    event::emit(DSComplianceRuleRemoved<T> { rule_type });
}

/// Check if a specific rule type is registered
public fun has_rule<T, R: store>(config: &ComplianceConfig<T>): bool {
    let rule_type = type_name::with_defining_ids<R>();
    config.rules.contains(&rule_type)
}

// ==================== Country Compliance Configuration ====================

public fun set_country_compliance<T>(registry: &mut InvestorInfo<T>, country: String, compliance_region: u64, auth: &Auth<T>, version: &Version, ctx: &TxContext){
    version.check_is_valid();
    auth.owner_has_ability<T, SetCountryCompliance>(ctx.sender());
    registry.set_country_compliance(country, compliance_region)
}

public fun get_country_compliance<T>(registry: &InvestorInfo<T>, country: String): u64{
    registry.get_country_compliance(country)
}

// ==================== Recorders ====================

public(package) fun record_issuance<T>(
    config: &ComplianceConfig<T>,
    registry: &mut InvestorInfo<T>,
    issuance: &IssuanceInfo,
    to: &PartyInfo,
) {
    if (issuance.amount == 0) return;

    // === TO side ===
    if (to.is_new_investor) {
        adjust_total_investors_counts<T>(
            registry,
            to.address,
            to.is_special_wallet,
            true,
        );
    };

    let to_id = to.investor_id.borrow();
    record_investor_issuance(registry, *to_id, issuance.amount, issuance.timestamp_ms);
    cleanup_investor_issuances(config, registry, *to_id, to.region, issuance.timestamp_ms)
}

public(package) fun record_transfer<T>(
    config: &ComplianceConfig<T>,
    registry: &mut InvestorInfo<T>,
    transfer: &TransferInfo,
    from: &PartyInfo,
    to: &PartyInfo,
) {
    if (transfer.amount == 0) return;

    let mut same_investor = false;

    if (!from.is_special_wallet && !to.is_special_wallet) {
        let from_id = from.investor_id.borrow();
        let to_id = to.investor_id.borrow();
        same_investor = *from_id == *to_id;
    };

    // === TO side ===
    if (to.is_new_investor) {
        adjust_total_investors_counts<T>(
            registry,
            to.address,
            to.is_special_wallet,
            true,
        );
    };

    // === FROM side ===
    if (!same_investor && from.is_exit_investor) {
        adjust_total_investors_counts<T>(
            registry,
            from.address,
            from.is_special_wallet,
            false,
        );
    };

    if (!from.is_special_wallet) {
        let from_id = from.investor_id.borrow();
        cleanup_investor_issuances(config, registry, *from_id, from.region, transfer.timestamp_ms)
    };
    if (!to.is_special_wallet) {
        let to_id = to.investor_id.borrow();
        cleanup_investor_issuances(config, registry, *to_id, to.region, transfer.timestamp_ms)
    };
}

public(package) fun record_burn<T>(
    registry: &mut InvestorInfo<T>,
    from: &PartyInfo,
    amount: u64,
) {
    if (amount == 0) return;

    // === FROM side ===
    if (from.is_exit_investor) {
        adjust_total_investors_counts<T>(
            registry,
            from.address,
            from.is_special_wallet,
            false,
        );
    };
}

public(package) fun record_seize<T>(
    registry: &mut InvestorInfo<T>,
    from: &PartyInfo,
    amount: u64,
) {
    record_burn(registry, from, amount);
}

public(package) fun adjust_total_investors_counts<T>(
    registry: &mut InvestorInfo<T>,
    wallet: address,
    is_special_wallet: bool,
    increase: bool,
) {
    if (is_special_wallet) return;

    let total = registry.get_total_investors_count();

    if (increase) {
        registry.set_total_investors_count(total + 1);
    } else {
        assert!(total > 0, ETotalInvestorsUnderflow);
        registry.set_total_investors_count(total - 1);
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

// ==================== Accessor Functions ====================

/// Get immutable reference to the rules vector
public fun rules<T, R: store>(
    self: &mut ComplianceConfig<T>,
    auth: &Auth<T>,
    version: &Version,
    ctx: &TxContext,
): &mut R {
    version.check_is_valid();
    auth.owner_has_ability<T, ManageRules>(ctx.sender());
    let rule_type = type_name::with_defining_ids<R>();
    self.rules_bag.borrow_mut(rule_type)
}

/// Get immutable reference to the rules vector
public fun rules_vector<T>(config: &ComplianceConfig<T>): &vector<TypeName> {
    &config.rules
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

    if (registry.has_investor_issuances(investor_id)) {
        let issuances = registry.get_investor_issuances_mut(investor_id);
        issuances.push_back(issuance);
    } else {
        registry.add_investor_issuances(investor_id, vector[issuance]);
    };
}

/// Cleanup expired issuances for an investor based on lock period
/// Should be called during transfers to remove stale records
public(package) fun cleanup_investor_issuances<T>(
    config: &ComplianceConfig<T>,
    registry: &mut InvestorInfo<T>,
    investor_id: String,
    region: u64,
    now_ms: u64,
) {
    let lock_period_ms = if (has_rule<T, LockupRestriction>(config)) {
        let rule: &LockupRestriction =
        config.rules_bag.borrow(type_name::with_defining_ids<LockupRestriction>());

        rule.lock_period_for_region(region)
    } else {
        0
    };

    if (!registry.has_investor_issuances(investor_id)) return;
    let issuances = registry.get_investor_issuances_mut(investor_id);

    // Lock period of 0 means no lockup - clear all issuances but keep entry
    if (lock_period_ms == 0) {
        while (!issuances.is_empty()) {
            issuances.pop_back();
        };
        return
    };

    remove_if!(issuances, |issuance| {
        issuance.issuance_time_ms() + lock_period_ms <= now_ms
    })
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