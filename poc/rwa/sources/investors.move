module rwa_poc::investors;

use sui::table::{Self, Table};
use std::string::String;

const ENotRegistered: u64 = 0;

public struct InvestorRegistry<phantom T> has key {
    id: UID,
    investors: Table<address, InvestorInfo>,
}

public struct InvestorInfo has store {
    country: String,
    wallet: address,
}

public(package) fun new<T>(ctx: &mut TxContext) {
    let registry = InvestorRegistry<T> {
        id: object::new(ctx),
        investors: table::new<address, InvestorInfo>(ctx),
    };
    transfer::share_object(registry);
}

public fun register_investor<T>(
    registry: &mut InvestorRegistry<T>,
    investor: address,
    country: String,
    wallet: address,
) {
    let info = InvestorInfo {
        country,
        wallet,
    };
    registry.investors.add(investor, info);
}

public fun get_country<T>(
    registry: &InvestorRegistry<T>,
    investor: address,
): String {
    assert!(registry.investors.contains(investor), ENotRegistered);
    let info = registry.investors.borrow(investor);
    info.country
}

public fun get_total_investors<T>(
    registry: &InvestorRegistry<T>,
): u64 {
    registry.investors.length()
}
