// All ability types from abilities.move
export type AbilityType =
    // DS Token abilities
    | 'IssueTokens'
    | 'BurnTokens'
    | 'SeizeTokens'
    | 'MetadataUpdate'
    | 'SetTemplateCommand'
    | 'AccessPolicyCap'
    | 'Pauser'
    // Trust Service abilities
    | 'SetServiceOwner'
    | 'SetTransferAgent'
    | 'SetIssuer'
    | 'SetExchange'
    | 'SetAbilities'
    | 'SetRoleTypes'
    // Compliance abilities
    | 'RegisterRule'
    | 'UnregisterRule'
    | 'SetCountryCompliance'
    | 'ManageRules'
    // Lock Manager abilities
    | 'LockInvestor'
    | 'UnlockInvestor'
    | 'SetLiquidateOnly'
    | 'AddLockRecord'
    | 'RemoveLockRecord'
    // Registry Service abilities
    | 'RegisterInvestor'
    | 'RemoveInvestor'
    | 'UpdateInvestor'
    | 'SetInvestorCounts'
    | 'SetCountry'
    | 'SetAttribute'
    | 'AddWallet'
    | 'RemoveWallet'
    // Wallet Manager abilities
    | 'SetIssuerWallet'
    | 'SetPlatformWallet'
    | 'RemoveSpecialWallet';
