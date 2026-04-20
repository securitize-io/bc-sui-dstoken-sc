/**************************************************************
 * THIS FILE IS GENERATED AND SHOULD NOT BE MANUALLY MODIFIED *
 **************************************************************/


/**
 * Module: abilities
 * 
 * Defines all capability types used for fine-grained access control. These ability
 * structs are used by the trust service to authorize specific actions across the
 * DS Token ecosystem.
 */

import { MoveTuple } from '../utils/index.js';
import { bcs } from '@mysten/sui/bcs';
const $moduleName = '@securitize/securitize::abilities';
export const IssueTokens = new MoveTuple({ name: `${$moduleName}::IssueTokens`, fields: [bcs.bool()] });
export const BurnTokens = new MoveTuple({ name: `${$moduleName}::BurnTokens`, fields: [bcs.bool()] });
export const SeizeTokens = new MoveTuple({ name: `${$moduleName}::SeizeTokens`, fields: [bcs.bool()] });
export const MetadataUpdate = new MoveTuple({ name: `${$moduleName}::MetadataUpdate`, fields: [bcs.bool()] });
export const SetTemplateCommand = new MoveTuple({ name: `${$moduleName}::SetTemplateCommand`, fields: [bcs.bool()] });
export const AccessPolicyCap = new MoveTuple({ name: `${$moduleName}::AccessPolicyCap`, fields: [bcs.bool()] });
export const Pauser = new MoveTuple({ name: `${$moduleName}::Pauser`, fields: [bcs.bool()] });
export const SetServiceOwner = new MoveTuple({ name: `${$moduleName}::SetServiceOwner`, fields: [bcs.bool()] });
export const SetTransferAgent = new MoveTuple({ name: `${$moduleName}::SetTransferAgent`, fields: [bcs.bool()] });
export const SetIssuer = new MoveTuple({ name: `${$moduleName}::SetIssuer`, fields: [bcs.bool()] });
export const SetExchange = new MoveTuple({ name: `${$moduleName}::SetExchange`, fields: [bcs.bool()] });
export const SetAbilities = new MoveTuple({ name: `${$moduleName}::SetAbilities`, fields: [bcs.bool()] });
export const SetRoleTypes = new MoveTuple({ name: `${$moduleName}::SetRoleTypes`, fields: [bcs.bool()] });
export const RegisterRule = new MoveTuple({ name: `${$moduleName}::RegisterRule`, fields: [bcs.bool()] });
export const UnregisterRule = new MoveTuple({ name: `${$moduleName}::UnregisterRule`, fields: [bcs.bool()] });
export const SetCountryCompliance = new MoveTuple({ name: `${$moduleName}::SetCountryCompliance`, fields: [bcs.bool()] });
export const ManageRules = new MoveTuple({ name: `${$moduleName}::ManageRules`, fields: [bcs.bool()] });
export const LockInvestor = new MoveTuple({ name: `${$moduleName}::LockInvestor`, fields: [bcs.bool()] });
export const UnlockInvestor = new MoveTuple({ name: `${$moduleName}::UnlockInvestor`, fields: [bcs.bool()] });
export const SetLiquidateOnly = new MoveTuple({ name: `${$moduleName}::SetLiquidateOnly`, fields: [bcs.bool()] });
export const AddLockRecord = new MoveTuple({ name: `${$moduleName}::AddLockRecord`, fields: [bcs.bool()] });
export const RemoveLockRecord = new MoveTuple({ name: `${$moduleName}::RemoveLockRecord`, fields: [bcs.bool()] });
export const RegisterInvestor = new MoveTuple({ name: `${$moduleName}::RegisterInvestor`, fields: [bcs.bool()] });
export const RemoveInvestor = new MoveTuple({ name: `${$moduleName}::RemoveInvestor`, fields: [bcs.bool()] });
export const UpdateInvestor = new MoveTuple({ name: `${$moduleName}::UpdateInvestor`, fields: [bcs.bool()] });
export const SetInvestorCounts = new MoveTuple({ name: `${$moduleName}::SetInvestorCounts`, fields: [bcs.bool()] });
export const SetCountry = new MoveTuple({ name: `${$moduleName}::SetCountry`, fields: [bcs.bool()] });
export const SetAttribute = new MoveTuple({ name: `${$moduleName}::SetAttribute`, fields: [bcs.bool()] });
export const AddWallet = new MoveTuple({ name: `${$moduleName}::AddWallet`, fields: [bcs.bool()] });
export const RemoveWallet = new MoveTuple({ name: `${$moduleName}::RemoveWallet`, fields: [bcs.bool()] });
export const SetIssuerWallet = new MoveTuple({ name: `${$moduleName}::SetIssuerWallet`, fields: [bcs.bool()] });
export const SetPlatformWallet = new MoveTuple({ name: `${$moduleName}::SetPlatformWallet`, fields: [bcs.bool()] });
export const RemoveSpecialWallet = new MoveTuple({ name: `${$moduleName}::RemoveSpecialWallet`, fields: [bcs.bool()] });