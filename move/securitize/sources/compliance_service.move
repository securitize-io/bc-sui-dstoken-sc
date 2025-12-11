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

// ==== Error Codes ====

/// Rule type not found in the system
const ERuleNotFound: u64 = 0;
/// Rule already exists for this asset
const ERuleAlreadyExists: u64 = 1;
const EDestinationRestricted: u64 = 2;
const ENotWhitelisted: u64 = 3;
const ENotEnoughTokens: u64 = 4;

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

// ==== TEMP Compliance Region Constants ====

const US: u64 = 1;
const EU: u64 = 2;
const FORBIDDEN: u64 = 4;
const JP: u64 = 8;


// Compliance Abilities

public struct RegisterRule() has drop;
public struct UnregisterRule() has drop;
public struct SetCountry() has drop;
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
    auth.add_role_ability<T, Master, SetCountry>(version, ctx);
    auth.add_role_ability<T, Master, ManageRules>(version, ctx);

    auth.add_role_ability<T, TransferAgent, RegisterRule>(version, ctx);
    auth.add_role_ability<T, TransferAgent, UnregisterRule>(version, ctx);
    auth.add_role_ability<T, TransferAgent, SetCountry>(version, ctx);
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
    registry: &InvestorInfo<T>,
    request: RwaTransferRequest<T>,
    version: &Version,
    // lock_manager: &LockManager<T>,
): RwaTransferRequest<T> {
    version.check_is_valid();

    let from_address = request.request_from_address();
    let to_address = request.request_to_address();

    assert!(registry.is_special_wallet(to_address) ||  registry.is_wallet(to_address), ENotWhitelisted);
    // get investor id
    // TODO check SPECIAL WALLETS 
    let from_id = registry.get_investor_id_by_wallet(from_address);
    let to_id = registry.get_investor_id_by_wallet(to_address);
    /////////////////
    let from_country = registry.get_country(from_id);
    let to_country = registry.get_country(to_id);
    let from_region = registry.get_country_compliance(from_country);
    let to_region = registry.get_country_compliance(to_country);
    let from_balance = registry.investor_wallet_balance_total(from_id);
    let to_balance = registry.investor_wallet_balance_total(to_id);
    let from_is_accredited = registry.is_accredited_investor_by_id(from_id);
    let to_is_accredited = registry.is_accredited_investor_by_id(to_id);
    let to_is_qualified = registry.is_qualified_investor_by_id(to_id);
    let to_is_new_investor = to_balance == 0;
    let amount = request.request_amount();
    let from_is_exit_investor = from_balance == amount;
    // TODO add platform wallet
    let to_is_platform_wallet = false;
    let from_is_platform_wallet = false;

    let equal_country = from_country == to_country;

    assert!(from_balance >= amount, ENotEnoughTokens);
    assert!(to_region != FORBIDDEN, EDestinationRestricted);

    let mut rules =  config.rules;
    // Skip checks for platform wallets except force full transfer
    if (to_is_platform_wallet) {
        rules = vector[]
    };

    if (from_address == to_address) {
        rules = vector[]
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
            from_is_accredited,
            from_is_exit_investor,
            from_is_platform_wallet,
            to_region,
            to_country,
            to_balance,
            to_is_accredited,
            to_is_qualified,
            to_is_new_investor,
            equal_country,
        );
    });
    request
}

/// Validate issuance action against all configured rules
public fun validate_issue<T>(
    config: &ComplianceConfig<T>,
    registry: &InvestorInfo<T>,
    to: address,
    // lock_manager: &LockManager<T>,
    amount: u64,
    version: &Version,
) {
    version.check_is_valid();

    assert!(registry.is_special_wallet(to) ||  registry.is_wallet(to), ENotWhitelisted);

    // get investor info
    // TODO check SPECIAL WALLETS 
    let to_id = registry.get_investor_id_by_wallet(to);
    ////////////////
    let to_country = registry.get_country(to_id);
    let to_region = registry.get_country_compliance(to_country);
    let to_balance = registry.investor_wallet_balance_total(to_id);
    let to_is_accredited = registry.is_accredited_investor_by_id(to_id);
    let to_is_qualified = registry.is_qualified_investor_by_id(to_id);
    let to_is_new_investor = to_balance == 0;
    // TODO add platform wallet
    let is_platform_wallet = false;

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
}

/// Validate burn action against all configured rules
public(package) fun validate_burn<T>(
    config: &ComplianceConfig<T>,
    from: address,
    amount: u64,
    from_balance: u64,
    // lock_manager: &mut LockManager<T>,
) {
    abort 0
}

/// Validate seize (clawback) action against all configured rules
public(package) fun validate_seize<T>(
    config: &ComplianceConfig<T>,
    from: address,
    amount: u64,
    from_balance: u64,
    // lock_manager: &mut LockManager<T>,
) {
    abort 0
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
    from_is_accredited: bool,
    from_is_exit_investor: bool,
    from_is_platform_wallet: bool,
    to_region: u64,
    to_country: String,
    to_balance: u64,
    to_is_accredited: bool,
    to_is_qualified: bool,
    to_is_new_investor: bool,
    equal_country: bool,
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
    // Accredited only check
    if (rule == type_name::with_defining_ids<AccreditedOnly>()) {
        let rule: &AccreditedOnly = config.rules_bag.borrow(rule);
        rule.validate_rule(to_region, to_is_accredited);
    }
    // Holding limits - min/max holdings
    else if (rule == type_name::with_defining_ids<HoldingLimits>()) {
        let rule: &HoldingLimits = config.rules_bag.borrow(rule);
        rule.validate_holding_limits_for_issuance(amount, to_balance, to_region);
    }
    // Investor limits - category limits for new investors
    else if (rule == type_name::with_defining_ids<InvestorLimits>()) {
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