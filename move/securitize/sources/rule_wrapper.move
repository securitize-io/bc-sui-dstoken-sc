/// Module: rule_wrapper
///
/// Generic hot potato wrappers for compliance rule flows.
module securitize::rule_wrapper;

/// Hot potato wrapper used during *rule creation*.
/// Must be resolved (unwrapped) in the same transaction.
public struct RuleInitWrapper<phantom T, R> {
    rule: R,
}

/// Hot potato wrapper used during *rule updates*.
/// Must be resolved (unwrapped) in the same transaction.
public struct RuleUpdateWrapper<phantom T, R> {
    rule: R,
}

/// Creation flow

/// Create a wrapper for rule initialization.
public(package) fun new_init<T, R>(rule: R): RuleInitWrapper<T, R> {
    RuleInitWrapper { rule }
}

/// Borrow an immutable reference to the rule being initialized.
public(package) fun borrow_init<T, R>(wrapper: &RuleInitWrapper<T, R>): &R {
    &wrapper.rule
}

/// Borrow a mutable reference to the rule being initialized.
public(package) fun borrow_init_mut<T, R>(wrapper: &mut RuleInitWrapper<T, R>): &mut R {
    &mut wrapper.rule
}

/// Consume the wrapper and return the initialized rule.
public(package) fun unwrap_init<T, R>(wrapper: RuleInitWrapper<T, R>): R {
    let RuleInitWrapper { rule } = wrapper;
    rule
}

/// Update flow

/// Create a wrapper for rule updates.
public(package) fun new_update<T, R>(rule: R): RuleUpdateWrapper<T, R> {
    RuleUpdateWrapper { rule }
}

/// Borrow an immutable reference to the rule being updated.
public(package) fun borrow_update<T, R>(wrapper: &RuleUpdateWrapper<T, R>): &R {
    &wrapper.rule
}

/// Borrow a mutable reference to the rule being updated.
public(package) fun borrow_update_mut<T, R>(wrapper: &mut RuleUpdateWrapper<T, R>): &mut R {
    &mut wrapper.rule
}

/// Consume the wrapper and return the updated rule.
public(package) fun unwrap_update<T, R>(wrapper: RuleUpdateWrapper<T, R>): R {
    let RuleUpdateWrapper { rule } = wrapper;
    rule
}
