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

// ==== Error Codes ====

const ERuleNotFound: u64 = 0;
const ERuleAlreadyExists: u64 = 1;
const EDestinationRestricted: u64 = 2;
const ENotWhitelisted: u64 = 3;
const ETotalInvestorsUnderflow: u64 = 4;
const ETokensLocked: u64 = 6;

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

    assert!(registry.is_special_wallet(to_address) ||  registry.is_wallet(to_address), ENotWhitelisted);

    let to_is_platform_wallet = is_platform_wallet(registry, to_address);
    let from_is_platform_wallet = is_platform_wallet(registry, from_address);
    let to_is_special_wallet = is_special_wallet(registry, to_address);
    let from_is_special_wallet = is_special_wallet(registry, from_address);

    let amount = request.request_amount();
    // ---- FROM ----
    let (
        from_country,
        from_region,
        from_is_accredited,
        from_is_exit_investor,
        from_balance,
        _unused_from_qualified,
        _unused_from_new
    ) = get_investor_info(registry, from_address, amount);

    // ---- TO ----
    let (
        to_country,
        to_region,
        to_is_accredited,
        _unused_to_exit,
        to_balance,
        to_is_qualified,
        to_is_new_investor
    ) = get_investor_info(registry, to_address, amount);

    let equal_country = from_country == to_country;

    assert!(to_region != FORBIDDEN, EDestinationRestricted);

    let platform_rules = vector[type_name::with_defining_ids<ForceFullTransfer>()];
    let empty_rules = vector[];

    let mut rules = &config.rules;

    if (to_is_platform_wallet) {
        rules = &platform_rules;
    };

    if (from_address == to_address) {
        rules = &empty_rules;
    };

    let empty_issuances: &vector<Issuance> = &vector[];

    let (from_investor_issuances_ref, from_transferable_balance) =
    if (!from_is_special_wallet) {
        let from_id = registry.get_investor_id_by_wallet(from_address);

        let transferable = lock_manager::compute_transferable(
            registry,
            from_id,
            from_balance,
            timestamp_ms,
        );

        // ---- GLOBAL lock invariant (TokenLocked) ----
        assert!(transferable >= amount, ETokensLocked);

        (
            registry.get_investor_issuances(from_id),
            transferable,
        )
    } else {
        (empty_issuances, from_balance)
    };

    // Validate all configured rules
    rules.do_ref!(|rule| {
        validate_transfer_rule(
            config,
            registry,
            *rule,
            amount,
            from_region,
            from_balance,
            from_transferable_balance,
            from_is_accredited,
            from_is_exit_investor,
            from_is_platform_wallet,
            to_region,
            to_country,
            to_balance,
            to_is_accredited,
            to_is_qualified,
            to_is_new_investor,
            from_investor_issuances_ref,
            equal_country,
            timestamp_ms
        );
    });

    record_transfer(config, registry, from_region, to_region, from_address, to_address, amount, from_is_special_wallet, to_is_special_wallet, to_is_new_investor, from_is_exit_investor, timestamp_ms);

}

/// Validate issuance action against all configured rules
public fun validate_issue<T>(
    config: &mut ComplianceConfig<T>,
    registry: &mut InvestorInfo<T>,
    to: address,
    amount: u64,
    timestamp_ms: u64,
    version: &Version,
) {
    version.check_is_valid();

    assert!(registry.is_special_wallet(to) ||  registry.is_wallet(to), ENotWhitelisted);

    // get investor info
    // TODO check SPECIAL WALLETS 
    let is_platform_wallet = is_platform_wallet(registry, to);

    // ---- TO ----
    let (
        to_country,
        to_region,
        to_is_accredited,
        _unused_to_exit,
        to_balance,
        to_is_qualified,
        to_is_new_investor
    ) = get_investor_info(registry, to, amount);

    assert!(to_region != FORBIDDEN, EDestinationRestricted);

    // Skip checks for platform wallets
    if (is_platform_wallet) return;
    // Validate all configured rules
    config.rules.do_ref!(|rule| {
        validate_issuance_rule(
            config,
            registry,
            *rule,
            amount,
            to_balance,
            to_region,
            to_country,
            to_is_accredited,
            to_is_qualified,
            to_is_new_investor
        );
    });

    record_issuance(config, registry, to, to_region, amount, is_platform_wallet, to_is_new_investor, timestamp_ms);
}

/// Validate burn action against all configured rules
public(package) fun validate_burn<T>(
    registry: &mut InvestorInfo<T>,
    from: address,
    amount: u64,
) {

    let from_is_special_wallet = is_special_wallet(registry, from);
    let (
        _from_country,
        _from_region,
        _from_is_accredited,
        from_is_exit_investor,
        _from_balance,
        _unused_from_qualified,
        _unused_from_new
    ) = get_investor_info(registry, from, amount);

    record_burn(registry, from, amount, from_is_special_wallet, from_is_exit_investor);
}

/// Validate seize (clawback) action against all configured rules
public(package) fun validate_seize<T>(
    registry: &mut InvestorInfo<T>,
    from: address,
    to: address,
    amount: u64,
) {
    assert!(is_issuer_wallet(registry, to));
    let from_is_special_wallet = is_special_wallet(registry, from);
    let (
        _from_country,
        _from_region,
        _from_is_accredited,
        from_is_exit_investor,
        _from_balance,
        _unused_from_qualified,
        _unused_from_new
    ) = get_investor_info(registry, from, amount);

    record_seize(registry, from, amount, from_is_special_wallet, from_is_exit_investor);
}

// ==================== Helper Functions ====================

/// Validate a single transfer rule
fun validate_transfer_rule<T>(
    config: &ComplianceConfig<T>,
    registry: &InvestorInfo<T>,
    rule: TypeName,
    amount: u64,
    from_region: u64,
    from_balance: u64,
    from_transferable_balance: u64,
    from_is_accredited: bool,
    from_is_exit_investor: bool,
    from_is_platform_wallet: bool,
    to_region: u64,
    to_country: String,
    to_balance: u64,
    to_is_accredited: bool,
    to_is_qualified: bool,
    to_is_new_investor: bool,
    investor_issuances: &vector<Issuance>,
    equal_country: bool,
    timestamp_ms: u64,
) {
    // Match on rule type and delegate to appropriate validator
    if (rule == type_name::with_defining_ids<AccreditedOnly>()) {
        let rule: &AccreditedOnly = config.rules_bag.borrow(rule);
        rule.validate_rule(to_region, to_is_accredited);
    } else if (rule == type_name::with_defining_ids<HoldingLimits>()) {
        let rule: &HoldingLimits = config.rules_bag.borrow(rule);
        rule.validate_holding_limits_for_transfer(
            amount,
            from_is_platform_wallet,
            from_balance,
            to_balance,
            from_region,
            to_region,
        );
    } else if (rule == type_name::with_defining_ids<InvestorLimits>()) {
        let rule: &InvestorLimits = config.rules_bag.borrow(rule);
        rule.validate_investor_limits_for_transfer<T>(
            registry,
            from_is_accredited,
            from_is_exit_investor,
            to_region,
            to_country,
            to_is_accredited,
            to_is_qualified,
            to_is_new_investor,
            equal_country,
        );
    } else if (rule == type_name::with_defining_ids<ForceFullTransfer>()) {
        let rule: &ForceFullTransfer = config.rules_bag.borrow(rule);
        rule.validate_rule(from_region, from_is_exit_investor);
    } else if (rule == type_name::with_defining_ids<FlowbackRestriction>()) {
        let rule: &FlowbackRestriction = config.rules_bag.borrow(rule);
        rule.validate_rule(from_region, to_region, from_is_platform_wallet, timestamp_ms);
    } else if (rule == type_name::with_defining_ids<LockupRestriction>()) {
        let rule: &LockupRestriction = config.rules_bag.borrow(rule);
        rule.validate_rule(investor_issuances, amount, from_region, from_is_platform_wallet, from_transferable_balance, timestamp_ms);
    };
}

/// Validate a single issuance rule
fun validate_issuance_rule<T>(
    config: &ComplianceConfig<T>,
    registry: &InvestorInfo<T>,
    rule: TypeName,
    amount: u64,
    to_balance: u64,
    to_region: u64,
    to_country: String,
    to_is_accredited: bool,
    to_is_qualified: bool,
    to_is_new_investor: bool,
) {
    // TODO: LockManager Is Investor LiquidateOnly
    if (rule == type_name::with_defining_ids<AccreditedOnly>()) {
        let rule: &AccreditedOnly = config.rules_bag.borrow(rule);
        rule.validate_rule(to_region, to_is_accredited);
    } else if (rule == type_name::with_defining_ids<HoldingLimits>()) {
        let rule: &HoldingLimits = config.rules_bag.borrow(rule);
        rule.validate_holding_limits_for_issuance(amount, to_balance, to_region);
    } else if (rule == type_name::with_defining_ids<InvestorLimits>()) {
        let rule: &InvestorLimits = config.rules_bag.borrow(rule);
        rule.validate_investor_limits_for_issuance(
            registry,
            to_region,
            to_country,
            to_is_accredited,
            to_is_qualified,
            to_is_new_investor,
        );
    };
}

/// Loads all relevant compliance and investor state for a given wallet address. 
/// For **non-special wallets**, it resolves:
/// - the investor ID,
/// - the country and mapped compliance region,
/// - total token balance across all wallets,
/// - accreditation and qualification status,
/// - whether the investor is new (balance == 0),
/// - whether the outgoing transfer represents a full exit (balance == amount).
///
/// For **special wallets**, all fields are defaulted (region = NONE, booleans = false,
/// balance = 0), and no registry lookups are performed.
fun get_investor_info<T>(registry: &InvestorInfo<T>, addr: address, amount: u64): (
    String, // country
    u64,    // region
    bool,   // accredited
    bool,   // exit investor
    u64,    // balance
    bool,   // qualified
    bool    // new investor
) {
    if (registry.is_special_wallet(addr)) {
        return ("", NONE, false, false, 0, false, false)
    };

    let id = registry.get_investor_id_by_wallet(addr);
    let country = registry.get_country(id);
    let region = registry.get_country_compliance(country);
    let balance = registry.investor_wallet_balance_total(id);
    let accredited = registry.is_accredited_investor_by_id(id);
    let qualified = registry.is_qualified_investor_by_id(id);
    let exit = balance == amount;
    let is_new = balance == 0;

    (country, region, accredited, exit, balance, qualified, is_new)
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
    to: address,
    amount: u64,
    region: u64,
    to_is_special_wallet: bool,
    to_is_new_investor: bool,
    timestamp_ms: u64,
) {
    if (amount == 0) return;

    // === TO side ===
    if (to_is_new_investor) {
        adjust_total_investors_counts<T>(
            registry,
            to,
            to_is_special_wallet,
            true,
        );
    };
    let to_investor_id = registry.get_investor_id_by_wallet(to);

    record_investor_issuance(registry, to_investor_id, amount, timestamp_ms);
    cleanup_investor_issuances(config, registry, region, to_investor_id, timestamp_ms)
}

public(package) fun record_transfer<T>(
    config: &ComplianceConfig<T>,
    registry: &mut InvestorInfo<T>,
    from_region: u64,
    to_region: u64,
    from: address,
    to: address,
    amount: u64,
    from_is_special_wallet: bool,
    to_is_special_wallet: bool,
    to_is_new_investor: bool,
    from_is_exit_investor: bool,
    timestamp_ms: u64,
) {
    if (amount == 0) return;

    let mut same_investor = false;

    if (!from_is_special_wallet && !to_is_special_wallet) {
        let from_id = registry.get_investor_id_by_wallet(from);
        let to_id = registry.get_investor_id_by_wallet(to);
        same_investor = from_id == to_id;
    };

    // === TO side ===
    if (to_is_new_investor) {
        adjust_total_investors_counts<T>(
            registry,
            to,
            to_is_special_wallet,
            true,
        );
    };

    // === FROM side ===
    if (!same_investor && from_is_exit_investor) {
        adjust_total_investors_counts<T>(
            registry,
            from,
            from_is_special_wallet,
            false,
        );
    };

    if (!from_is_special_wallet) {
        let from_id = registry.get_investor_id_by_wallet(from);
        cleanup_investor_issuances(config, registry, from_region, from_id, timestamp_ms)
    };
    if (!to_is_special_wallet) {
        let to_id = registry.get_investor_id_by_wallet(to);
        cleanup_investor_issuances(config, registry, to_region, to_id, timestamp_ms)
    };
}

public(package) fun record_burn<T>(
    registry: &mut InvestorInfo<T>,
    from: address,
    amount: u64,
    from_is_special_wallet: bool,
    from_is_exit_investor: bool,
) {
    if (amount == 0) return;

    // === FROM side ===
    if (from_is_exit_investor) {
        adjust_total_investors_counts<T>(
            registry,
            from,
            from_is_special_wallet,
            false,
        );
    };
}

public(package) fun record_seize<T>(
    registry: &mut InvestorInfo<T>,
    from: address,
    amount: u64,
    from_is_special_wallet: bool,
    from_is_exit_investor: bool,
) {
    record_burn(registry, from, amount, from_is_special_wallet, from_is_exit_investor);
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
    region: u64,
    investor_id: String,
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