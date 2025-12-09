/// This module is meant to be used only off-chain, for SDKs to be able to construct
/// arbitrary PTBs.
#[allow(unused_field)]
module rwa::move_command;

use std::{ascii, type_name::TypeName};

/// A MoveCommand
public struct MoveCommand has copy, drop, store {
    address: ContractAddress,
    module_name: ascii::String,
    function_name: ascii::String,
    arguments: vector<Argument>,
    type_arguments: vector<TypeArgument>,
}

/// A contract address can be a static address, or a MVR name.
public enum ContractAddress has copy, drop, store {
    Address(address),
    Mvr(ascii::String),
}

/// A type argument can be a placeholder (the `T` of the token),
/// or a generic typename.
public enum TypeArgument has copy, drop, store {
    Placeholder,
    TypeName(TypeName),
}

/// The acceptable arguments for a contract are:
/// - Immutable reference of a shared object
/// - Mutable reference of a shared object
/// - Reference of an immutable object
/// - Payment of a specific type and amount
/// - App specific arguments / placeholders (like the known vaults, the rule, the transfer request)
public enum Argument has copy, drop, store {
    /// Expect a shared reference of a shared object
    SharedObjectRef(ID),
    /// Expect a mutable reference of a shared object
    SharedObjectMutRef(ID),
    /// Expect an immutable reference
    ImmutableObjectRef(ID),
    /// Expect a payment of `type` and `amount`.
    Payment(TypeName, u64),
    /// Standard specific placeholders. Maybe we can have a `StandardPlaceholder(String)`
    /// and do validation differently.
    SenderVaultPlaceholder,
    ReceiverVaultPlaceholder,
    RulePlaceholder,
    TransferRequestPlaceholder,
}
