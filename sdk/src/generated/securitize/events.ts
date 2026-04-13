/**************************************************************
 * THIS FILE IS GENERATED AND SHOULD NOT BE MANUALLY MODIFIED *
 **************************************************************/


/**
 * Module: events
 * 
 * Centralized event definitions for the Securitize DS Token protocol. Contains all
 * event structs emitted across the protocol for tracking token operations,
 * investor management, compliance changes, and role assignments.
 */

import { MoveStruct } from '../utils/index.js';
import { bcs } from '@mysten/sui/bcs';
import * as type_name from './deps/std/type_name.js';
import * as type_name_1 from './deps/std/type_name.js';
import * as type_name_2 from './deps/std/type_name.js';
import * as type_name_3 from './deps/std/type_name.js';
const $moduleName = '@securitize/securitize::events';
export const DeployerAdded = new MoveStruct({ name: `${$moduleName}::DeployerAdded`, fields: {
        deployer: bcs.Address
    } });
export const DeployerRemoved = new MoveStruct({ name: `${$moduleName}::DeployerRemoved`, fields: {
        deployer: bcs.Address
    } });
export const AdminSwitched = new MoveStruct({ name: `${$moduleName}::AdminSwitched`, fields: {
        old_admin: bcs.Address,
        new_admin: bcs.Address
    } });
export const Issue = new MoveStruct({ name: `${$moduleName}::Issue<phantom T>`, fields: {
        to: bcs.Address,
        value: bcs.u64(),
        value_locked: bcs.u64()
    } });
export const Burn = new MoveStruct({ name: `${$moduleName}::Burn<phantom T>`, fields: {
        burner: bcs.Address,
        value: bcs.u64(),
        reason: bcs.string()
    } });
export const Seize = new MoveStruct({ name: `${$moduleName}::Seize<phantom T>`, fields: {
        from: bcs.Address,
        to: bcs.Address,
        value: bcs.u64(),
        reason: bcs.string()
    } });
export const Transfer = new MoveStruct({ name: `${$moduleName}::Transfer<phantom T>`, fields: {
        from: bcs.Address,
        to: bcs.Address,
        value: bcs.u64()
    } });
export const Pause = new MoveStruct({ name: `${$moduleName}::Pause<phantom T>`, fields: {
        pauser: bcs.Address
    } });
export const Unpause = new MoveStruct({ name: `${$moduleName}::Unpause<phantom T>`, fields: {
        pauser: bcs.Address
    } });
export const NameUpdated = new MoveStruct({ name: `${$moduleName}::NameUpdated<phantom T>`, fields: {
        old_name: bcs.string(),
        new_name: bcs.string()
    } });
export const DescriptionUpdated = new MoveStruct({ name: `${$moduleName}::DescriptionUpdated<phantom T>`, fields: {
        old_description: bcs.string(),
        new_description: bcs.string()
    } });
export const IconUriUpdated = new MoveStruct({ name: `${$moduleName}::IconUriUpdated<phantom T>`, fields: {
        old_icon_uri: bcs.string(),
        new_icon_uri: bcs.string()
    } });
export const DSTrustServiceRoleAdded = new MoveStruct({ name: `${$moduleName}::DSTrustServiceRoleAdded<phantom T>`, fields: {
        target_address: bcs.Address,
        role: type_name.TypeName,
        sender: bcs.Address
    } });
export const DSTrustServiceRoleRemoved = new MoveStruct({ name: `${$moduleName}::DSTrustServiceRoleRemoved<phantom T>`, fields: {
        target_address: bcs.Address,
        role: type_name_1.TypeName,
        sender: bcs.Address
    } });
export const DSRegistryServiceInvestorAdded = new MoveStruct({ name: `${$moduleName}::DSRegistryServiceInvestorAdded<phantom T>`, fields: {
        investor_id: bcs.string(),
        sender: bcs.Address
    } });
export const DSRegistryServiceInvestorRemoved = new MoveStruct({ name: `${$moduleName}::DSRegistryServiceInvestorRemoved<phantom T>`, fields: {
        investor_id: bcs.string(),
        sender: bcs.Address
    } });
export const DSRegistryServiceInvestorCountryChanged = new MoveStruct({ name: `${$moduleName}::DSRegistryServiceInvestorCountryChanged<phantom T>`, fields: {
        investor_id: bcs.string(),
        country: bcs.string(),
        sender: bcs.Address
    } });
export const DSRegistryServiceInvestorAttributeChanged = new MoveStruct({ name: `${$moduleName}::DSRegistryServiceInvestorAttributeChanged<phantom T>`, fields: {
        investor_id: bcs.string(),
        attribute_id: bcs.u64(),
        value: bcs.u64(),
        expiry: bcs.u64(),
        sender: bcs.Address
    } });
export const DSRegistryServiceWalletAdded = new MoveStruct({ name: `${$moduleName}::DSRegistryServiceWalletAdded<phantom T>`, fields: {
        wallet: bcs.Address,
        investor_id: bcs.string(),
        sender: bcs.Address
    } });
export const DSRegistryServiceWalletRemoved = new MoveStruct({ name: `${$moduleName}::DSRegistryServiceWalletRemoved<phantom T>`, fields: {
        wallet: bcs.Address,
        investor_id: bcs.string(),
        sender: bcs.Address
    } });
export const DSComplianceRuleAdded = new MoveStruct({ name: `${$moduleName}::DSComplianceRuleAdded<phantom T>`, fields: {
        rule_type: type_name_2.TypeName
    } });
export const DSComplianceRuleRemoved = new MoveStruct({ name: `${$moduleName}::DSComplianceRuleRemoved<phantom T>`, fields: {
        rule_type: type_name_3.TypeName
    } });
export const DSComplianceTransferRecorded = new MoveStruct({ name: `${$moduleName}::DSComplianceTransferRecorded<phantom T>`, fields: {
        from: bcs.Address,
        to: bcs.Address,
        amount: bcs.u64()
    } });
export const DSComplianceIssuanceRecorded = new MoveStruct({ name: `${$moduleName}::DSComplianceIssuanceRecorded<phantom T>`, fields: {
        to: bcs.Address,
        amount: bcs.u64()
    } });
export const DSComplianceBurnRecorded = new MoveStruct({ name: `${$moduleName}::DSComplianceBurnRecorded<phantom T>`, fields: {
        from: bcs.Address,
        amount: bcs.u64()
    } });
export const DSComplianceSeizeRecorded = new MoveStruct({ name: `${$moduleName}::DSComplianceSeizeRecorded<phantom T>`, fields: {
        from: bcs.Address,
        amount: bcs.u64()
    } });
export const InvestorFullyLocked = new MoveStruct({ name: `${$moduleName}::InvestorFullyLocked<phantom T>`, fields: {
        investor_id: bcs.string()
    } });
export const InvestorFullyUnlocked = new MoveStruct({ name: `${$moduleName}::InvestorFullyUnlocked<phantom T>`, fields: {
        investor_id: bcs.string()
    } });
export const InvestorLiquidateOnlySet = new MoveStruct({ name: `${$moduleName}::InvestorLiquidateOnlySet<phantom T>`, fields: {
        investor_id: bcs.string(),
        enabled: bcs.bool()
    } });
export const HolderLocked = new MoveStruct({ name: `${$moduleName}::HolderLocked<phantom T>`, fields: {
        holder_id: bcs.string(),
        value: bcs.u64(),
        reason: bcs.u64(),
        reason_string: bcs.string(),
        release_time_ms: bcs.u64()
    } });
export const HolderUnlocked = new MoveStruct({ name: `${$moduleName}::HolderUnlocked<phantom T>`, fields: {
        holder_id: bcs.string(),
        value: bcs.u64(),
        reason: bcs.u64(),
        reason_string: bcs.string(),
        release_time_ms: bcs.u64()
    } });
export const DSWalletManagerSpecialWalletAdded = new MoveStruct({ name: `${$moduleName}::DSWalletManagerSpecialWalletAdded<phantom T>`, fields: {
        wallet: bcs.Address,
        wallet_type: bcs.u64(),
        caller: bcs.Address
    } });
export const DSWalletManagerSpecialWalletRemoved = new MoveStruct({ name: `${$moduleName}::DSWalletManagerSpecialWalletRemoved<phantom T>`, fields: {
        wallet: bcs.Address,
        old_type: bcs.u64(),
        caller: bcs.Address
    } });
export const DSComplianceUIntRuleSet = new MoveStruct({ name: `${$moduleName}::DSComplianceUIntRuleSet<phantom T>`, fields: {
        rule_name: bcs.string(),
        prev_value: bcs.u64(),
        new_value: bcs.u64()
    } });
export const DSComplianceBoolRuleSet = new MoveStruct({ name: `${$moduleName}::DSComplianceBoolRuleSet<phantom T>`, fields: {
        rule_name: bcs.string(),
        prev_value: bcs.bool(),
        new_value: bcs.bool()
    } });
export const DSComplianceStringToUIntMapRuleSet = new MoveStruct({ name: `${$moduleName}::DSComplianceStringToUIntMapRuleSet<phantom T>`, fields: {
        rule_name: bcs.string(),
        key_value: bcs.string(),
        prev_value: bcs.u64(),
        new_value: bcs.u64()
    } });