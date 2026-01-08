/// This module is only used for off-chain metadata.
///
/// It enables SDKs to discover how to resolve a custom transfer request for any arbitrary T,
/// as long as the creator has set the appropriate ruleset here.
///
/// WARNING: The existence of a Command provides NO guarantees that this will be functional, but offers a
/// discoverable way for PTB building.
#[allow(unused_field)]
module pas::command;

use std::{ascii, string, type_name::TypeName};

/// A `Command`
public struct Command has copy, drop, store {
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

/// A type argument can be a System (the `T` of the token (or the NFT in the future),
/// generally T is derived from `Rule<T>`), or any explicit typename.
public enum TypeArgument has copy, drop, store {
    System,
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
    /// Custom arguments that can be modified depending on the implementation.
    ///
    /// Examples of supported values for the vault system (for fungible tokens):
    /// - Custom("sender_vault")
    /// - Custom("receiver_vault")
    /// - Custom("rule")
    /// - Custom("transfer_request")
    Custom(string::String),
    /// A custom argument, which also has a "value" (in bytes format), in case we want to encode
    /// any specific metadata in the future.
    CustomWithValue(string::String, vector<u8>),
}
