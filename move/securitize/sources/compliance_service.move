module securitize::compliance_service;

use rwa::{registry, vault::RwaTransferRequest};
use securitize::{
    accredited_only::AccreditedOnly,
    holding_limits::HoldingLimits,
    investor_limits::InvestorLimits,
    trust_service::{Auth, TransferAgent, Master},
    version::Version
};
use std::{ascii::String, type_name::{Self, TypeName}};
use sui::{bag::{Self, Bag}, event, vec_map::{Self, VecMap}};

// ==== Error Codes ====

/// Rule type not found in the system
const ERuleNotFound: u64 = 0;
/// Rule already exists for this asset
const ERuleAlreadyExists: u64 = 1;
const EDestinationRestricted: u64 = 2;

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
        id: object::new(ctx),
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
    request: RwaTransferRequest<T>,
    version: &Version,
    // registry: &InvestorRegistry<T>,
    // lock_manager: &LockManager<T>,
): RwaTransferRequest<T> {
    version.check_is_valid();
    // Get investor information from registry (fake values for now)
    let from_region = US;
    let to_region = EU;
    let to_country = std::ascii::string(b"GREECE");
    let from_balance = 1000;
    let to_balance = 500;
    let to_is_accredited = true;
    let to_is_qualified = true;
    let to_is_new_investor = true;
    let from_is_exit_investor = true;
    let is_platform_wallet_to = false;
    let equal_country = false;
    let from_is_accredited = false;

    assert!(to_region != FORBIDDEN, EDestinationRestricted);

    // Validate all configured rules
    config.rules.do_ref!(|rule| {
        validate_transfer_rule(
            config,
            *rule,
            request.request_amount(),
            from_region,
            to_region,
            to_country,
            from_balance,
            to_balance,
            to_is_accredited,
            to_is_qualified,
            to_is_new_investor,
            from_is_accredited,
            from_is_exit_investor,
            equal_country,
            is_platform_wallet_to,
            // registry: &InvestorRegistry<T>,
        );
    });
    request
}

/// Validate issuance action against all configured rules
/// Based on Solidity preIssuanceCheck flow
public(package) fun validate_issue<T>(
    config: &ComplianceConfig<T>,
    to: address,
    amount: u64,
    version: &Version,
    // registry: &InvestorRegistry<T>,
    // lock_manager: &LockManager<T>,
) {
    version.check_is_valid();

    // TODO Check Whitelisted
    // registry(to) exists as wallet

    let to_region = EU;
    let to_country = std::ascii::string(b"GREECE");
    let to_balance = 500;
    let to_is_accredited = true;
    let to_is_qualified = true;
    let is_platform_wallet = false;
    // Determine if this is a new investor (balance was 0 before issuance)
    let to_is_new_investor = to_balance == 0;

    assert!(to_region != FORBIDDEN, EDestinationRestricted);

    // Validate all configured rules
    config.rules.do_ref!(|rule| {
        validate_issuance_rule(
            config,
            *rule,
            amount,
            to_balance,
            to_region,
            to_country,
            to_is_accredited,
            to_is_qualified,
            to_is_new_investor,
            is_platform_wallet,
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
    rule: TypeName,
    amount: u64,
    from_region: u64,
    to_region: u64,
    to_country: String,
    from_balance: u64,
    to_balance: u64,
    to_is_accredited: bool,
    to_is_qualified: bool,
    to_is_new_investor: bool,
    from_is_accredited: bool,
    from_is_exit_investor: bool,
    equal_country: bool,
    is_platform_wallet_to: bool,
    // registry: InvestorRegistry<T>
) {
    // Match on rule type and delegate to appropriate validator
    if (rule == type_name::with_defining_ids<AccreditedOnly>()) {
        let rule: &AccreditedOnly = config.rules_bag.borrow(rule);
        rule.validate_rule(to_region, to_is_accredited);
    } else if (rule == type_name::with_defining_ids<HoldingLimits>()) {
        let rule: &HoldingLimits = config.rules_bag.borrow(rule);
        rule.validate_holding_limits_for_transfer(
            amount,
            from_balance,
            to_balance,
            from_region,
            to_region,
        );
    } else if (rule == type_name::with_defining_ids<InvestorLimits>()) {
        let rule: &InvestorLimits = config.rules_bag.borrow(rule);
        rule.validate_investor_limits_for_transfer<T>(
            to_region,
            from_is_accredited,
            from_is_exit_investor,
            to_is_accredited,
            to_is_qualified,
            to_is_new_investor,
            equal_country,
            // registry,
        );
    };
}

/// Validate a single issuance rule
fun validate_issuance_rule<T>(
    config: &ComplianceConfig<T>,
    rule: TypeName,
    amount: u64,
    to_balance: u64,
    to_region: u64,
    to_country: String,
    to_is_accredited: bool,
    to_is_qualified: bool,
    to_is_new_investor: bool,
    is_platform_wallet: bool,
) {
    // Skip most checks for platform wallets
    if (is_platform_wallet) return;

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
            to_region,
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
