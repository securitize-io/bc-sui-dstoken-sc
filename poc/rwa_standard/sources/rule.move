module rwa::rule;

use std::type_name::{Self, TypeName};
use sui::balance::Balance;
use sui::vec_map::{Self, VecMap};
use sui::coin::TreasuryCap;
use sui::derived_object;
use sui::dynamic_object_field as dof;
use rwa::vault::VaultOwnerProof;
use rwa::move_command::MoveCommand;
use rwa::vault::{Self, RwaTransferRequest, RwaVault};
use rwa::registry::RwaRegistry;
use rwa::token;


/// The authorization witness does not match the rule's expected witness type
const EInvalidProof: u64 = 0;
/// Attempted to clawback tokens when clawback is not enabled for this rule
const EClawbackNotAllowed: u64 = 1;
/// A rule for this token type already exists in the registry
const ERuleAlreadyExists: u64 = 3;
/// The TreasuryCap is not locked inside the rule
const ETreasuryCapNotLocked: u64 = 4;

/// A rule is set by the owner of `T`, and points to a `TypeName` that needs
/// to be verified by the entity's contract.
///
/// This is derived from `rwa_registry, TypeName<T>`
#[allow(unused_field)]
public struct RwaRule<phantom T> has key {
    id: UID,
    /// If the rule has clawback, the owner can arbitrarily clawback tokens from vaults.
    /// This is only set on registration and cannot be updated in the future.
    clawback_allowed: bool,
    /// The typename used to prove that the "smart contract" agrees with a transfer.
    auth_witness: TypeName,
    // TODO: Align on the `MoveCommand` architecture for making it easy to SDKs to resolve actions.
    // `TypeName` is the "action". E.g. `RwaTransferRequest`.
    // We make it a VecMap to allow expanding to support further actions in the standard.
    resolution_info: VecMap<TypeName, MoveCommand>,
}

/// Key used to store the TreasuryCap<T> in the RwaRule<T>.
public struct TreasuryCapKey() has copy, drop, store;

// ========== Rule Creation ==========

/// Create a new `RwaRule` without locking the `TreasuryCap` inside.
/// The issuer retains the `TreasuryCap` and can use all functions except mint and burn operations.
/// Aborts with `ERuleAlreadyExists` if a rule for this token type already exists.
public fun new<T, U: drop>(
    rwa_registry: &mut RwaRegistry,
    _treasury: &TreasuryCap<T>,
    clawback_allowed: bool,
    _auth_witness: U,
) {
    // Store the authorization witness type
    let auth_witness = type_name::with_defining_ids<U>();

    assert!(!derived_object::exists(rwa_registry.uid_mut(), RwaRuleKey<T>()), ERuleAlreadyExists);

    transfer::share_object(RwaRule<T>{
        id: derived_object::claim(rwa_registry.uid_mut(), RwaRuleKey<T>()),
        clawback_allowed,
        auth_witness: auth_witness,
        resolution_info: vec_map::empty(),
    });
}

/// Create a new `RwaRule` and lock the `TreasuryCap` inside as a dynamic object field.
/// This enables all rule operations including mint and burn. The `TreasuryCap` is permanently locked in the rule.
/// Aborts with `ERuleAlreadyExists` if a rule for this token type already exists.
public fun new_with_locked_treasury<T, U: drop>(
    rwa_registry: &mut RwaRegistry,
    treasury: TreasuryCap<T>,
    clawback_allowed: bool,
    _auth_witness: U,
) {
    // Store the authorization witness type
    let auth_witness = type_name::with_defining_ids<U>();

    assert!(!derived_object::exists(rwa_registry.uid_mut(), RwaRuleKey<T>()), ERuleAlreadyExists);

    let mut rule = RwaRule<T> {
        id: derived_object::claim(rwa_registry.uid_mut(), RwaRuleKey<T>()),
        clawback_allowed,
        auth_witness: auth_witness,
        resolution_info: vec_map::empty(),
    };
    dof::add(&mut rule.id, TreasuryCapKey(), treasury);

    transfer::share_object(rule);
}

/// Key for deriving RwaRule from registry
public struct RwaRuleKey<phantom T>() has copy, drop, store;

/// Resolve a transfer request by verifying the authorization witness and finalizing the transfer.
/// Aborts with `EInvalidProof` if the witness does not match the rule's authorization witness.
public fun resolve_transfer<T, U: drop>(
    rule: &RwaRule<T>,
    request: RwaTransferRequest<T>,
    _stamp: U,
) {
    rule.assert_is_valid_creator_proof<T, U>();
    // destructuring the request to finalize the transfer.
    request.resolve_transfer();
}

/// Mint new tokens and transfer them to the vault derived by the specified address.
/// REQUIRES: `TreasuryCap` must be locked inside the rule.
/// Abort with `ETreasuryCapNotLocked` if the `TreasuryCap` is not locked in the rule.
/// Aborts with `EInvalidProof` if the witness does not match.
public fun mint<T, U: drop>(
    rwa_registry: &RwaRegistry,
    rule: &mut RwaRule<T>,
    to: address,
    amount: u64,
    _stamp: U,
    ctx: &mut TxContext,
) {
    rule.assert_is_treasury_locked<T>();
    rule.assert_is_valid_creator_proof<T, U>();
    let balance = dof::borrow_mut<TreasuryCapKey, TreasuryCap<T>>(&mut rule.id, TreasuryCapKey()).mint_balance(amount);
    let token = token::new(balance, ctx);
    let receiving_vault = vault::derive_address(rwa_registry, to);

    token.transfer(receiving_vault);
}

/// Mint new tokens directly into the specified vault.
/// REQUIRES: `TreasuryCap` must be locked inside the rule.
/// Aborts with `ETreasuryCapNotLocked` if the `TreasuryCap` is not locked in the rule.
/// Aborts with `EInvalidProof` if the witness does not match.
public fun mint_to_vault<T, U: drop>(
    rule: &mut RwaRule<T>,
    to: &mut RwaVault,
    amount: u64,
    _stamp: U,
) {
    rule.assert_is_treasury_locked<T>();
    rule.assert_is_valid_creator_proof<T, U>();
    let balance = dof::borrow_mut<TreasuryCapKey, TreasuryCap<T>>(&mut rule.id, TreasuryCapKey()).mint_balance(amount);
    to.deposit_balance(balance);
}

/// Deposit existing token balance to the vault derived by the specified address.
/// Aborts with `EInvalidProof` if the witness does not match the rule's authorization witness.
public fun deposit<T, U: drop>(
    rwa_registry: &RwaRegistry,
    rule: &RwaRule<T>,
    to: address,
    balance: Balance<T>,
    _stamp: U,
    ctx: &mut TxContext,
) {
    rule.assert_is_valid_creator_proof<T, U>();

    let token = token::new(balance, ctx);
    let receiving_vault = vault::derive_address(rwa_registry, to);

    token.transfer(receiving_vault);
}

/// Deposit existing token balance directly into the specified vault.
/// Aborts with `EInvalidProof` if the witness does not match the rule's authorization witness.
public fun deposit_to_vault<T, U: drop>(
    rule: &RwaRule<T>,
    vault: &mut RwaVault,
    balance: Balance<T>,
    _stamp: U,
) {
    rule.assert_is_valid_creator_proof<T, U>();

    vault.deposit_balance(balance)
}

/// Burn tokens from a vault, reducing the total supply. Requires vault owner authorization.
/// REQUIRES: `TreasuryCap` must be locked inside the rule.
/// Aborts with `ETreasuryCapNotLocked` if the `TreasuryCap` is not locked in the rule.
/// Aborts with `EInvalidProof` if the witness does not match,
/// if the owner proof is invalid, or if the vault has insufficient balance.
public fun burn_from_vault<T, U: drop>(
    rule: &mut RwaRule<T>,
    from: &mut RwaVault,
    owner_proof: &VaultOwnerProof,
    amount: u64,
    _stamp: U,
    ctx: &mut TxContext,
) {
    rule.assert_is_treasury_locked<T>();
    owner_proof.assert_is_valid_for_vault(from);
    rule.assert_is_valid_creator_proof<T, U>();

    let balance = from.withdraw_balance<T>(amount);
    dof::borrow_mut<TreasuryCapKey, TreasuryCap<T>>(&mut rule.id, TreasuryCapKey()).burn(balance.into_coin(ctx));
}

/// Unlock token balance from a vault with owner authorization.
/// Aborts with `EInvalidProof` if the witness does not match, if the owner proof is invalid,
/// or if the vault has insufficient balance.
public fun unlock_from_vault<T, U: drop>(
    rule: &RwaRule<T>,
    vault: &mut RwaVault,
    owner_proof: &VaultOwnerProof,
    amount: u64,
    _stamp: U,
): Balance<T> {
    owner_proof.assert_is_valid_for_vault(vault);
    rule.assert_is_valid_creator_proof<T, U>();

    vault.withdraw_balance<T>(amount)
}

/// Clawback tokens from a vault without owner authorization. Only allowed if clawback was enabled during rule creation.
/// Aborts with `EClawbackNotAllowed` if clawback is disabled, `EInvalidProof` if the witness does not match,
/// or if the vault has insufficient balance.
public fun clawback<T, U: drop>(
    rule: &RwaRule<T>,
    from: &mut RwaVault,
    amount: u64,
    _stamp: U,
): Balance<T> {
    assert!(rule.clawback_allowed, EClawbackNotAllowed);
    rule.assert_is_valid_creator_proof<T, U>();

    from.withdraw_balance<T>(amount)
}

/// Clawback tokens from one vault and deposit them into another vault without owner authorization.
/// Only allowed if clawback was enabled during rule creation.
/// Aborts with `EClawbackNotAllowed` if clawback is disabled, `EInvalidProof` if the witness does not match,
/// or if the source vault has insufficient balance.
public fun clawback_to_vault<T, U: drop>(
    rule: &RwaRule<T>,
    from: &mut RwaVault,
    to: &mut RwaVault,
    amount: u64,
    _stamp: U,
) {
    assert!(rule.clawback_allowed, EClawbackNotAllowed);
    rule.assert_is_valid_creator_proof<T, U>();

    let balance = from.withdraw_balance<T>(amount);
    to.deposit_balance(balance);
}

fun assert_is_valid_creator_proof<T, U: drop>(rule: &RwaRule<T>) {
    assert!(type_name::with_defining_ids<U>() == rule.auth_witness, EInvalidProof);
}

fun assert_is_treasury_locked<T>(rule: &RwaRule<T>) {
    assert!(dof::exists_(&rule.id, TreasuryCapKey()), ETreasuryCapNotLocked);
}

// ========== Action Management ==========

/// Add a move command for a specific action type to the rule's resolution info.
/// Aborts with `EInvalidProof` if the witness does not match the rule's authorization witness.
public fun add_action<T, U: drop>(
    rule: &mut RwaRule<T>,
    action_type: TypeName,
    action_command: MoveCommand,
    _auth_witness: U,
) {
    rule.assert_is_valid_creator_proof<T, U>();

    // Add action move command
    if (!rule.resolution_info.contains(&action_type)) {
        rule.resolution_info.insert(action_type, action_command);
    };
}

// ========== Getter Functions ==========

/// Get the authorization witness `TypeName` required for operations on this rule
public fun authorization_witness<T>(rule: &RwaRule<T>): TypeName {
    rule.auth_witness
}

/// Get the move command associated with a specific action type
public fun action_command<T>(rule: &RwaRule<T>, action_type: &TypeName): &MoveCommand {
    rule.resolution_info.get(action_type)
}
