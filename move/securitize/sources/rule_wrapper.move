/// Module: rule_wrapper
///
/// Generic hot potato wrapper for compliance rules.
module securitize::rule_wrapper;

/// A hot potato wrapper that holds a rule of type Τ.
/// Since this struct has no abilities, it must be resolved (unwrapped)
/// in the same transaction it was created - it cannot be stored or dropped.
public struct RuleWrapper<T> {
    rule: T,
}

/// Create a new RuleWrapper containing the given rule.
/// The caller must resolve this wrapper before the transaction ends.
public(package) fun new<T>(rule: T): RuleWrapper<T> {
    RuleWrapper { rule }
}

/// Borrow an immutable reference to the wrapped rule.
public(package) fun borrow<T>(wrapper: &RuleWrapper<T>): &T {
    &wrapper.rule
}

/// Borrow a mutable reference to the wrapped rule.
public(package) fun borrow_mut<T>(wrapper: &mut RuleWrapper<T>): &mut T {
    &mut wrapper.rule
}

/// Unwrap and return the inner rule, consuming the hot potato wrapper.
/// This must be called to complete any operation that created a wrapper.
public(package) fun unwrap<T>(wrapper: RuleWrapper<T>): T {
    let RuleWrapper { rule } = wrapper;
    rule
}
