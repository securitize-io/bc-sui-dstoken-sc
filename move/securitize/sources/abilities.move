module securitize::abilities;

// ==== Ds Token Abilities ====

public struct IssueTokens() has drop;

public struct BurnTokens() has drop;

public struct SeizeTokens() has drop;

public struct MetadataUpdate() has drop;

public struct Pauser() has drop;

// ==================== Trust Service Abilities ====================

public struct SetServiceOwner has drop {}

public struct SetTransferAgent has drop {}

public struct SetIssuer has drop {}

public struct SetExchange has drop {}

public struct SetAbilities has drop {}

public struct SetRoleTypes has drop {}

// ==== Compliance Abilities ====

public struct RegisterRule() has drop;

public struct UnregisterRule() has drop;

public struct SetCountryCompliance() has drop;

public struct ManageRules() has drop;

// ==== Lock Manager Abilities ====

public struct LockInvestor has drop {}

public struct UnlockInvestor has drop {}

public struct SetLiquidateOnly has drop {}

public struct AddLockRecord has drop {}

public struct RemoveLockRecord has drop {}

// ==== Registry Service Abilities ====

/// Ability to register new investors
public struct RegisterInvestor() has drop;

/// Ability to remove investors from the registry
public struct RemoveInvestor() has drop;

/// Ability to update investor information
public struct UpdateInvestor() has drop;

/// Ability to set investor country
public struct SetCountry() has drop;

/// Ability to set investor attributes
public struct SetAttribute() has drop;

/// Ability to add wallets to investors
public struct AddWallet() has drop;

/// Ability to remove wallets from investors
public struct RemoveWallet() has drop;

// ==== Wallet Manager Abilities ====

/// Ability to set issuer wallets
public struct SetIssuerWallet() has drop;

/// Ability to set platform wallets
public struct SetPlatformWallet() has drop;

/// Ability to remove special wallets
public struct RemoveSpecialWallet() has drop;
