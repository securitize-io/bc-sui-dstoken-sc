module pas::transfer_funds_request;

use sui::balance::{Self, Balance};

/// A transfer request that is generated once a Permissioned Funds Transfer is initiated.
///
/// A hot potato that is issued when a transfer is initiated.
/// It can only be resolved by presenting a witness `U` that is the witness of `Rule<T>`
///
/// This enables the `resolve` function of each smart contract to
/// be flexible and implement its own mechanisms for validation.
/// The individual resolution module can:
///   - Check whitelists/blacklists
///   - Enforce holding periods
///   - Collect fees
///   - Emit regulatory events
///   - Handle dividends/distributions
///   - Implement any jurisdiction-specific rules
public struct TransferFundsRequest<phantom T> {
    /// `sender` is the wallet OR object address, NOT the vault address
    sender: address,
    /// `recipient` is the wallet OR object address, NOT the vault address
    recipient: address,
    /// The ID of the vault the funds are coming from
    sender_vault_id: ID,
    /// The ID of the vault the funds are going to
    recipient_vault_id: ID,
    /// The amount being transferred (original)
    amount: u64,
    /// The actual balance being transferred
    balance: Balance<T>,
}

public fun sender<T>(request: &TransferFundsRequest<T>): address { request.sender }

public fun recipient<T>(request: &TransferFundsRequest<T>): address { request.recipient }

public fun sender_vault_id<T>(request: &TransferFundsRequest<T>): ID { request.sender_vault_id }

public fun recipient_vault_id<T>(request: &TransferFundsRequest<T>): ID {
    request.recipient_vault_id
}

public fun amount<T>(request: &TransferFundsRequest<T>): u64 { request.amount }

public(package) fun new<T>(
    sender: address,
    recipient: address,
    sender_vault_id: ID,
    recipient_vault_id: ID,
    balance: Balance<T>,
): TransferFundsRequest<T> {
    TransferFundsRequest {
        sender,
        recipient,
        sender_vault_id,
        recipient_vault_id,
        amount: balance.value(),
        balance,
    }
}

/// Internal function to resolve a transfer request.
/// WARNING: This must only be called by `rule.move` after verifying the witness,
/// it should never become public.
public(package) fun resolve<T>(request: TransferFundsRequest<T>) {
    let TransferFundsRequest { balance, recipient_vault_id, .. } = request;
    balance::send_funds(balance, recipient_vault_id.to_address());
}
