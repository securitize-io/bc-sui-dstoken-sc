/// Module: rule_wrapper
///
/// Generic hot potato wrappers for compliance rule flows.
module securitize::rule_wrapper;

/// Hot potato wrapper used during *rule creation*.
/// Must be resolved (unwrapped) in the same transaction.
public struct RuleInitWrapper<T> {
    rule: T,
}

/// Hot potato wrapper used during *rule updates*.
/// Must be resolved (unwrapped) in the same transaction.
public struct RuleUpdateWrapper<T> {
    rule: T,
}

/// Creation flow

/// Create a wrapper for rule initialization.
public(package) fun new_init<T>(rule: T): RuleInitWrapper<T> {
    RuleInitWrapper { rule }
}

/// Borrow an immutable reference to the rule being initialized.
public(package) fun borrow_init<T>(wrapper: &RuleInitWrapper<T>): &T {
    &wrapper.rule
}

/// Borrow a mutable reference to the rule being initialized.
public(package) fun borrow_init_mut<T>(wrapper: &mut RuleInitWrapper<T>): &mut T {
    &mut wrapper.rule
}

/// Consume the wrapper and return the initialized rule.
public(package) fun unwrap_init<T>(wrapper: RuleInitWrapper<T>): T {
    let RuleInitWrapper { rule } = wrapper;
    rule
}

/// Update flow

/// Create a wrapper for rule updates.
public(package) fun new_update<T>(rule: T): RuleUpdateWrapper<T> {
    RuleUpdateWrapper { rule }
}

/// Borrow an immutable reference to the rule being updated.
public(package) fun borrow_update<T>(wrapper: &RuleUpdateWrapper<T>): &T {
    &wrapper.rule
}

/// Borrow a mutable reference to the rule being updated.
public(package) fun borrow_update_mut<T>(wrapper: &mut RuleUpdateWrapper<T>): &mut T {
    &mut wrapper.rule
}

/// Consume the wrapper and return the updated rule.
public(package) fun unwrap_update<T>(wrapper: RuleUpdateWrapper<T>): T {
    let RuleUpdateWrapper { rule } = wrapper;
    rule
}
