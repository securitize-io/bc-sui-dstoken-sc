module pas::rule;

use pas::{
    command::Command,
    keys,
    namespace::Namespace,
    transfer_funds_request::TransferFundsRequest,
    unlock_funds_request::UnlockFundsRequest,
    vault::Vault
};
use std::type_name::{Self, TypeName};
use sui::{balance::Balance, derived_object, dynamic_field, vec_map::{Self, VecMap}};

#[error(code = 0)]
const EInvalidProof: vector<u8> =
    b"The authorization witness does not match the rule's expected witness type.";
#[error(code = 1)]
const EClawbackNotAllowed: vector<u8> =
    b"Attempted to clawback tokens when clawback is not enabled for this rule.";
#[error(code = 2)]
const ERuleAlreadyExists: vector<u8> = b"A rule for this token type already exists.";
#[error(code = 3)]
const EFundManagementNotEnabled: vector<u8> = b"Fund management is not enabled for this rule.";
#[error(code = 4)]
const EFundManagementAlreadyEnabled: vector<u8> =
    b"Fund management is already enabled for this rule.";

/// A rule is set by the owner of `T`, and points to a `TypeName` that needs
/// to be verified by the entity's contract.
///
/// This is derived from `namespace, TypeName<T>`
public struct Rule<phantom T> has key {
    id: UID,
    /// The typename used to prove that the "smart contract" agrees with an action for a given `T`.
    /// Initially, this only means it approves "transfers", "clawbacks" and "mints (managed scenario)".
    /// In the future, there might be NFT version of these rules.
    auth_witness: TypeName,
    // TODO: Align on the `MoveCommand` architecture for making it easy to SDKs to resolve actions.
    // `TypeName` is the "action". E.g. `TransferFundsRequest`.
    // We make it a VecMap to allow expanding to support further actions in the standard.
    resolution_info: VecMap<TypeName, Command>,
}

/// A flag saved as <FundsClawbackState(), bool> to check if claw-backs are enabled
/// for a given asset.
public struct FundsClawbackState() has copy, drop, store;

/// Create a new `Rule` for `T`.
/// We use `Permit<T>` as the proof of ownership for `T`.
public fun new<T, U: drop>(
    namespace: &mut Namespace,
    _: internal::Permit<T>,
    // The author can specify a custom witness type `U` for approving actions of the system.
    // That could also be `Permit<T>` if there's no need for separation.
    _stamp: U,
): Rule<T> {
    assert!(!namespace.rule_exists<T>(), ERuleAlreadyExists);

    Rule<T> {
        id: derived_object::claim(namespace.uid_mut(), keys::rule_key<T>()),
        auth_witness: type_name::with_defining_ids<U>(),
        resolution_info: vec_map::empty(),
    }
}

public fun share<T>(rule: Rule<T>) {
    transfer::share_object(rule);
}

/// Enables funds management for a given `T`, adding a DF that tracks the clawback status (true/false).
/// This can only be called once. After calling it, the clawback status can never change!
public fun enable_funds_management<T, U: drop>(
    rule: &mut Rule<T>,
    _stamp: U,
    clawback_allowed: bool,
) {
    rule.assert_is_valid_issuer_proof<_, U>();
    assert!(!rule.is_fund_management_enabled(), EFundManagementAlreadyEnabled);
    dynamic_field::add(&mut rule.id, FundsClawbackState(), clawback_allowed);
}

/// Resolve an unlock funds request by verifying the authorization witness and finalizing the unlock.
public fun resolve_unlock_funds<T, U: drop>(
    rule: &Rule<T>,
    request: UnlockFundsRequest<T>,
    _stamp: U,
): Balance<T> {
    rule.assert_is_valid_issuer_proof<_, U>();
    rule.assert_is_fund_management_enabled();
    request.resolve()
}

/// Resolve a transfer request by verifying the authorization witness and finalizing the transfer.
/// Aborts with `EInvalidProof` if the witness does not match the rule's authorization witness.
public fun resolve_transfer_funds<T, U: drop>(
    rule: &Rule<T>,
    request: TransferFundsRequest<T>,
    _stamp: U,
) {
    rule.assert_is_valid_issuer_proof<_, U>();
    rule.assert_is_fund_management_enabled();
    // destructuring the request to finalize the transfer.
    request.resolve();
}

/// Clawbacks `amount` of balance from a Vault, returning `Balance<T>` by value.
///
/// WARNING: This does not guarantee that the funds will not go out of the controlled system.
/// Use with caution.
public fun clawback_funds<T, U: drop>(
    rule: &Rule<T>,
    from: &mut Vault,
    amount: u64,
    _stamp: U,
): Balance<T> {
    assert!(rule.is_fund_clawback_allowed(), EClawbackNotAllowed);
    rule.assert_is_valid_issuer_proof<_, U>();

    from.withdraw<T>(amount)
}

/// Check if clawback is allowed or not.
/// Aborts early if the management for funds has not been enabled for `T`.
public fun is_fund_clawback_allowed<T>(rule: &Rule<T>): bool {
    rule.assert_is_fund_management_enabled();
    *dynamic_field::borrow(&rule.id, FundsClawbackState())
}

/// Set the move command for a specific action type.
/// NOTE: If the action type already exists, it will be replaced.
public fun set_action_command<T, U: drop, A>(rule: &mut Rule<T>, command: Command, _stamp: U) {
    rule.assert_is_valid_issuer_proof<_, U>();
    let action_type = type_name::with_defining_ids<A>();

    // Remove if already exists (as this is a setter).
    if (rule.resolution_info.contains(&action_type)) {
        rule.resolution_info.remove(&action_type);
    };

    rule.resolution_info.insert(action_type, command);
}

/// Check if fund management is enabled for a given `T`.
public(package) fun is_fund_management_enabled<T>(rule: &Rule<T>): bool {
    dynamic_field::exists_(&rule.id, FundsClawbackState())
}

public fun auth_witness<T>(rule: &Rule<T>): TypeName { rule.auth_witness }

fun assert_is_fund_management_enabled<T>(rule: &Rule<T>) {
    assert!(rule.is_fund_management_enabled(), EFundManagementNotEnabled);
}

fun assert_is_valid_issuer_proof<T, U: drop>(rule: &Rule<T>) {
    assert!(type_name::with_defining_ids<U>() == rule.auth_witness, EInvalidProof);
}
