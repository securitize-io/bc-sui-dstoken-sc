module pas::keys;

/// Key for deriving `Rule<T>` from the namespace
public struct RuleKey<phantom T>() has copy, drop, store;

/// Key for deriving `Vault` from the namespace
public struct VaultKey(address) has copy, drop, store;

/// WARNING: these should only be used internally.
public(package) fun rule_key<T>(): RuleKey<T> { RuleKey<T>() }

public(package) fun vault_key(owner: address): VaultKey { VaultKey(owner) }
