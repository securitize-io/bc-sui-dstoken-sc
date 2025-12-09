module rwa::token;

use sui::{balance::Balance, transfer::Receiving};

/// An `RwaToken` is a token that can only be transferred through this framework.
/// Unlike `Coin<T>`, it cannot be received / transferred.
public struct RwaToken<phantom T> has key {
    id: UID,
    balance: Balance<T>,
}

/// Squash two `Token<T>` into one.
public fun join<T>(token: &mut RwaToken<T>, other: RwaToken<T>) {
    let RwaToken { id, balance } = other;
    id.delete();
    token.balance.join(balance);
}

public(package) fun new<T>(balance: Balance<T>, ctx: &mut TxContext): RwaToken<T> {
    RwaToken {
        id: object::new(ctx),
        balance,
    }
}

public(package) fun extract<T>(token: RwaToken<T>): Balance<T> {
    let RwaToken { id, balance } = token;
    id.delete();
    balance
}

public(package) fun balance<T>(token: &RwaToken<T>): u64 {
    token.balance.value()
}

public(package) fun receive<T>(parent: &mut UID, token: Receiving<RwaToken<T>>): RwaToken<T> {
    transfer::receive(parent, token)
}

public(package) fun transfer<T>(token: RwaToken<T>, to: address) {
    transfer::transfer(token, to);
}
