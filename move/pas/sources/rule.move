module pas::rule;

use pas::{
    command::Command,
    namespace::Namespace,
    transfer_funds_request::TransferFundsRequest,
    vault::{Self, Vault}
};
use std::type_name::{Self, TypeName};
use sui::{
    balance::{Self, Balance},
    coin::TreasuryCap,
    derived_object,
    dynamic_object_field as dof,
    vec_map::{Self, VecMap}
};

#[error(code = 0)]
const EInvalidProof: vector<u8> =
    b"The authorization witness does not match the rule's expected witness type.";
#[error(code = 1)]
const EClawbackNotAllowed: vector<u8> =
    b"Attempted to clawback tokens when clawback is not enabled for this rule.";
#[error(code = 3)]
const ERuleAlreadyExists: vector<u8> = b"A rule for this token type already exists.";
#[error(code = 4)]
const ETreasuryCapNotLocked: vector<u8> = b"This rule does not contain a managed treasury cap.";
#[error(code = 5)]
const ECannotClawbackFromAManagedTreasury: vector<u8> = b"Cannot clawback from a managed treasury.";
#[error(code = 6)]
const ESupplyMustBeZero: vector<u8> =
    b"The treasury cap must have a supply of 0 to create a managed rule.";

/// A rule is set by the owner of `T`, and points to a `TypeName` that needs
/// to be verified by the entity's contract.
///
/// This is derived from `namespace, TypeName<T>`
public struct Rule<phantom T> has key {
    id: UID,
    /// If the rule has clawback, the owner can arbitrarily clawback tokens from vaults.
    /// This is only set on registration and cannot be updated in the future.
    clawback_allowed: bool,
    /// The typename used to prove that the "smart contract" agrees with an action for a given `T`.
    /// Initially, this only means it approves "transfers", "clawbacks" and "mints (managed scenario)".
    /// In the future, there might be NFT version of these rules.
    auth_witness: TypeName,
    // TODO: Align on the `MoveCommand` architecture for making it easy to SDKs to resolve actions.
    // `TypeName` is the "action". E.g. `TransferFundsRequest`.
    // We make it a VecMap to allow expanding to support further actions in the standard.
    resolution_info: VecMap<TypeName, Command>,
}

/// Key for deriving `Rule<T>` from the namespace
public struct RuleKey<phantom T>() has copy, drop, store;

/// Key used to store the TreasuryCap<T> in the Rule<T>.
public struct TreasuryCapKey() has copy, drop, store;

/// Create a new `Rule` without making the  the `TreasuryCap`.
public fun new<T, U: drop>(
    namespace: &mut Namespace,
    _treasury: &TreasuryCap<T>,
    clawback_allowed: bool,
    _auth_witness: U,
) {
    assert!(!namespace.exists(RuleKey<T>()), ERuleAlreadyExists);

    transfer::share_object(Rule<T> {
        id: derived_object::claim(namespace.uid_mut(), RuleKey<T>()),
        clawback_allowed,
        auth_witness: type_name::with_defining_ids<U>(),
        resolution_info: vec_map::empty(),
    });
}

/// Create a new managed `Rule` which locks the `TreasuryCap` inside.
/// This provides a few guarantees:
/// 1. Issuer can burn/mint only through the `Rule<T>`
/// 2. Issuer cannot move any Coin or Balance<T> out of vault-to-vault.
public fun new_managed_treasury<T, U: drop>(
    namespace: &mut Namespace,
    mut treasury: TreasuryCap<T>,
    clawback_allowed: bool,
    _auth_witness: U,
) {
    // TODO: Discuss if we want to enforce this (though I think we should!).
    assert!(treasury.supply().value() == 0, ESupplyMustBeZero);
    assert!(!namespace.exists(RuleKey<T>()), ERuleAlreadyExists);

    let mut rule_uid = derived_object::claim(namespace.uid_mut(), RuleKey<T>());
    dof::add(&mut rule_uid, TreasuryCapKey(), treasury);

    transfer::share_object(Rule<T> {
        id: rule_uid,
        clawback_allowed,
        auth_witness: type_name::with_defining_ids<U>(),
        resolution_info: vec_map::empty(),
    });
}

/// Resolve a transfer request by verifying the authorization witness and finalizing the transfer.
/// Aborts with `EInvalidProof` if the witness does not match the rule's authorization witness.
public fun resolve_transfer<T, U: drop>(
    rule: &Rule<T>,
    request: TransferFundsRequest<T>,
    _stamp: U,
) {
    rule.assert_is_valid_creator_proof<_, U>();
    // destructuring the request to finalize the transfer.
    request.resolve();
}

/// Mint new tokens directly into the specified vault. This is only possible if `TreasuryCap` is locked
/// in the rule.
public fun mint<T, U: drop>(rule: &mut Rule<T>, to: &Vault, amount: u64, _stamp: U) {
    rule.assert_is_managed_treasury();
    rule.assert_is_valid_creator_proof<_, U>();

    balance::send_funds(rule.treasury_cap_mut().mint_balance(amount), object::id(to).to_address());
}

/// Mint new tokens and transfers them to an address. The address used is the derived one.
public fun unsafe_mint<T, U: drop>(
    namespace: &Namespace,
    rule: &mut Rule<T>,
    to: address,
    amount: u64,
    _stamp: U,
    _ctx: &mut TxContext,
) {
    rule.assert_is_managed_treasury();
    rule.assert_is_valid_creator_proof<_, U>();
    let balance = rule.treasury_cap_mut().mint_balance(amount);

    balance::send_funds(balance, vault::vault_address(object::id(namespace), to));
}

/// Deposit existing token balance directly into the specified vault.
/// Aborts with `EInvalidProof` if the witness does not match the rule's authorization witness.
public fun deposit<T, U: drop>(rule: &Rule<T>, vault: &Vault, balance: Balance<T>, _stamp: U) {
    rule.assert_is_valid_creator_proof<_, U>();
    vault.deposit(balance)
}

/// This function deposits to an address (or object).
/// THIS MUST NOT BE THE VAULT ID. The ID of the vault is derived within the function.
///
/// This is marked as `unsafe_` because if the supplied address is invalid, the funds might end up
/// in a wrong vault. They remain recoverable.
public fun unsafe_deposit<T, U: drop>(
    rule: &Rule<T>,
    namespace: &Namespace,
    balance: Balance<T>,
    to: address,
    _stamp: U,
    _ctx: &mut TxContext,
) {
    rule.assert_is_valid_creator_proof<_, U>();
    balance::send_funds(balance, vault::vault_address(object::id(namespace), to));
}

/// Burn tokens from a vault, reducing the total supply. Requires vault owner authorization.
/// TODO: Make this become a `BurnFundsRequest` and introduce `UnlockFundsRequest` too.
public fun burn<T, U: drop>(
    rule: &mut Rule<T>,
    from: &mut Vault,
    amount: u64,
    _stamp: U,
    ctx: &mut TxContext,
) {
    rule.assert_is_managed_treasury();
    rule.assert_is_valid_creator_proof<_, U>();

    let balance = from.withdraw<T>(amount);
    rule.treasury_cap_mut().burn(balance.into_coin(ctx));
}

/// Clawback tokens from one vault and deposit them into another vault without owner authorization.
/// Only allowed if clawback was enabled during rule creation.
/// Aborts with `EClawbackNotAllowed` if clawback is disabled, `EInvalidProof` if the witness does not match,
/// or if the source vault has insufficient balance.
public fun clawback<T, U: drop>(
    rule: &Rule<T>,
    from: &mut Vault,
    to: &Vault,
    amount: u64,
    _stamp: U,
) {
    assert!(rule.clawback_allowed, EClawbackNotAllowed);
    rule.assert_is_valid_creator_proof<T, U>();

    let balance = from.withdraw<T>(amount);
    to.deposit(balance);
}

/// Clawbacks `amount` of balance from a Vault, returning `Balance<T>` by value.
///
/// NOTE: THIS IS UNSAFE BECAUSE THIS CANNOT GUARANTEE THAT BALANCE<T> CANNOT GET OUT OF
/// THE CLOSED LOOP OF VAULTS (VAULT-TO-VAULT GUARANTEES).
public fun unsafe_clawback<T, U: drop>(
    rule: &Rule<T>,
    from: &mut Vault,
    amount: u64,
    _stamp: U,
): Balance<T> {
    assert!(rule.clawback_allowed, EClawbackNotAllowed);
    assert!(!rule.is_managed_treasury(), ECannotClawbackFromAManagedTreasury);

    rule.assert_is_valid_creator_proof<T, U>();
    from.withdraw<T>(amount)
}

// ========== Action Management ==========

/// Set the move command for a specific action type.
/// NOTE: If the action type already exists, it will be replaced.
public fun set_action_command<T, U: drop, A>(
    rule: &mut Rule<T>,
    command: Command,
    _auth_witness: U,
) {
    rule.assert_is_valid_creator_proof<_, U>();
    let action_type = type_name::with_defining_ids<A>();

    // Remove if already exists (as this is a setter).
    if (rule.resolution_info.contains(&action_type)) {
        rule.resolution_info.remove(&action_type);
    };

    rule.resolution_info.insert(action_type, command);
}

public fun auth_witness<T>(rule: &Rule<T>): TypeName { rule.auth_witness }

/// Whether the treasury cap for a currency is managed by the Rule.
public fun is_managed_treasury<T>(rule: &Rule<T>): bool {
    dof::exists_(&rule.id, TreasuryCapKey())
}

fun treasury_cap_mut<T>(rule: &mut Rule<T>): &mut TreasuryCap<T> {
    dof::borrow_mut<_, TreasuryCap<T>>(&mut rule.id, TreasuryCapKey())
}

fun assert_is_valid_creator_proof<T, U: drop>(rule: &Rule<T>) {
    assert!(type_name::with_defining_ids<U>() == rule.auth_witness, EInvalidProof);
}

/// Aborts if the treasury is not managed (does not have a locked treasury cap).
fun assert_is_managed_treasury<T>(rule: &Rule<T>) {
    assert!(dof::exists_(&rule.id, TreasuryCapKey()), ETreasuryCapNotLocked);
}
