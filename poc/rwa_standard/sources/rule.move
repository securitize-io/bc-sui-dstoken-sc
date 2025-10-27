module rwa::rule;

use rwa::move_command::MoveCommand;
use rwa::vault::{RwaTransferRequest, RwaVault};
use rwa::registry::RwaRegistry;
use rwa::token::{Self, RwaToken};
use std::type_name::{Self, TypeName};
use sui::balance::Balance;
use sui::vec_map::{Self, VecMap};
use sui::coin::TreasuryCap;
use sui::derived_object;

const EInvalidProof: u64 = 0;
const EClawbackNotAllowed: u64 = 1;
const EVaultAlreadyExists: u64 = 3;

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

// ========== Rule Creation ==========

/// Create a new RwaRule - requires TreasuryCap to prove token ownership
/// Only the holder of TreasuryCap<T> can create the rule for token T
public fun create_rule<T, U: drop>(
    rwa_registry: &mut RwaRegistry,
    _treasury: &TreasuryCap<T>,
    clawback_allowed: bool,
    _auth_witness: U,
) {
    // Store the authorization witness type
    let auth_witness = type_name::with_defining_ids<U>();

    assert!(!derived_object::exists(rwa_registry.uid_mut(), RwaRuleKey<T>()), EVaultAlreadyExists);

    transfer::share_object(RwaRule<T>{
        id: derived_object::claim(rwa_registry.uid_mut(), RwaRuleKey<T>()),
        clawback_allowed,
        auth_witness: auth_witness,
        resolution_info: vec_map::empty(),
    });
}

/// Key for deriving RwaRule from registry
public struct RwaRuleKey<phantom T>() has copy, drop, store;

/// Create a new RwaToken from a Balance<T>
/// Requires authorization witness U to prove caller is the token creator
///
/// This wraps a Balance<T> into an RwaToken<T> for transfers via the receiving pattern.
/// Only the token creator (verified via witness) can create tokens from balances.
/// TODO can be as transfer request. -> wrapRequest or depositRequest
public fun new_token<T, U: drop>(
    rule: &RwaRule<T>,
    balance: Balance<T>,
    _stamp: U,
    ctx: &mut TxContext,
): RwaToken<T> {
    rule.assert_is_valid_creator_proof<T, U>();
    token::new(balance, ctx)
}

/// Extract Balance<T> from an RwaToken<T>
/// Requires authorization witness U to prove caller is the token creator
///
/// This unwraps an RwaToken<T> back into Balance<T> (destroying the token object).
/// Only the token creator (verified via witness) can extract balances from tokens.
/// Typically used after receiving a token to convert it back to balance for vault storage.
/// TODO can be as transfer request. -> extractRequest
public fun extract<T, U: drop>(
    rule: &RwaRule<T>,
    token: RwaToken<T>,
    _stamp: U,
): Balance<T> {
    rule.assert_is_valid_creator_proof<T, U>();
    let balance = token.extract();
    balance
}

/// U is a witness, which has to match the rule's witness.
/// This is callable by the smart contract that has to approve a transfer.
public fun resolve_transfer<T, U: drop>(
    rule: &RwaRule<T>,
    request: RwaTransferRequest<T>,
    _stamp: U,
) {
    rule.assert_is_valid_creator_proof<T, U>();
    // destructuring the request to finalize the transfer.
    request.resolve();
}

/// Allows the creator to clawback tokens from vaults, as long as it is allowed.
public fun clawback<T, U: drop>(
    rule: &RwaRule<T>,
    vault: &mut RwaVault,
    amount: u64,
    _stamp: U,
): Balance<T> {
    assert!(rule.clawback_allowed, EClawbackNotAllowed);
    rule.assert_is_valid_creator_proof<T, U>();

    vault.withdraw_balance<T>(amount)
}

fun assert_is_valid_creator_proof<T, U: drop>(rule: &RwaRule<T>) {
    assert!(type_name::with_defining_ids<U>() == rule.auth_witness, EInvalidProof);
}

// ========== Action Management ==========

/// Add a validator for a specific action type
/// U: authorization witness (token creator)
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

/// Get the authorization witness type
public fun get_authorization_witness<T>(rule: &RwaRule<T>): TypeName {
    rule.auth_witness
}

/// Get move command for an action
public fun get_action_command<T>(rule: &RwaRule<T>, action_type: &TypeName): &MoveCommand {
    rule.resolution_info.get(action_type)
}
