/**************************************************************
 * THIS FILE IS GENERATED AND SHOULD NOT BE MANUALLY MODIFIED *
 **************************************************************/


/**
 * Module: ds_token
 * 
 * The main security token module that implements the DS Token standard. Provides
 * treasury management, token issuance, burning, seizing, and transfers with
 * integrated compliance validation through the compliance service.
 */

import { MoveTuple, MoveStruct, normalizeMoveArguments, type RawTransactionArgument } from '../utils/index.js';
import { bcs } from '@mysten/sui/bcs';
import { type Transaction } from '@mysten/sui/transactions';
import * as coin_registry from './deps/sui/coin_registry.js';
const $moduleName = '@securitize/securitize::ds_token';
export const TransferApproval = new MoveTuple({ name: `${$moduleName}::TransferApproval<phantom T>`, fields: [bcs.bool()] });
export const ClawbackApproval = new MoveTuple({ name: `${$moduleName}::ClawbackApproval<phantom T>`, fields: [bcs.bool()] });
export const DsTokenKey = new MoveTuple({ name: `${$moduleName}::DsTokenKey<phantom T>`, fields: [bcs.bool()] });
export const Treasury = new MoveStruct({ name: `${$moduleName}::Treasury<phantom T>`, fields: {
        id: bcs.Address,
        /** Capability to manage token metadata (name, description, icon) */
        metadata_cap: coin_registry.MetadataCap,
        paused: bcs.bool()
    } });
export const TreasuryCapKey = new MoveTuple({ name: `${$moduleName}::TreasuryCapKey`, fields: [bcs.bool()] });
export const PolicyCapKey = new MoveTuple({ name: `${$moduleName}::PolicyCapKey`, fields: [bcs.bool()] });
export interface IssueTokensArguments {
    treasury: RawTransactionArgument<string>;
    auth: RawTransactionArgument<string>;
    investors: RawTransactionArgument<string>;
    complianceConfig: RawTransactionArgument<string>;
    to: RawTransactionArgument<string>;
    toAddress: RawTransactionArgument<string>;
    value: RawTransactionArgument<number | bigint>;
    reasonCode: RawTransactionArgument<number | bigint>;
    reasonString: RawTransactionArgument<string>;
    version: RawTransactionArgument<string>;
    valuesLocked: RawTransactionArgument<Array<number | bigint>>;
    releaseTimes: RawTransactionArgument<Array<number | bigint>>;
    issuanceTimeMs: RawTransactionArgument<number | bigint>;
}
export interface IssueTokensOptions {
    package?: string;
    arguments: IssueTokensArguments | [
        treasury: RawTransactionArgument<string>,
        auth: RawTransactionArgument<string>,
        investors: RawTransactionArgument<string>,
        complianceConfig: RawTransactionArgument<string>,
        to: RawTransactionArgument<string>,
        toAddress: RawTransactionArgument<string>,
        value: RawTransactionArgument<number | bigint>,
        reasonCode: RawTransactionArgument<number | bigint>,
        reasonString: RawTransactionArgument<string>,
        version: RawTransactionArgument<string>,
        valuesLocked: RawTransactionArgument<Array<number | bigint>>,
        releaseTimes: RawTransactionArgument<Array<number | bigint>>,
        issuanceTimeMs: RawTransactionArgument<number | bigint>
    ];
    typeArguments: [
        string
    ];
}
/**
 * Issues new tokens and deposits them into the specified account. Only authorized
 * addresses with the IssueTokens ability can call this function.
 *
 * # Aborts
 *
 * - `ENotAuthorized` - If the sender does not have the IssueTokens ability
 * - `EAccountOwnerMismatch` - If the account owner does not match to_address
 */
export function issueTokens(options: IssueTokensOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        null,
        null,
        null,
        null,
        'address',
        'u64',
        'u64',
        '0x1::string::String',
        null,
        'vector<u64>',
        'vector<u64>',
        'u64',
        '0x2::clock::Clock'
    ] satisfies (string | null)[];
    const parameterNames = ["treasury", "auth", "investors", "complianceConfig", "to", "toAddress", "value", "reasonCode", "reasonString", "version", "valuesLocked", "releaseTimes", "issuanceTimeMs"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'ds_token',
        function: 'issue_tokens',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface IssueTokensNoAccountArguments {
    treasury: RawTransactionArgument<string>;
    auth: RawTransactionArgument<string>;
    investors: RawTransactionArgument<string>;
    complianceConfig: RawTransactionArgument<string>;
    namespace: RawTransactionArgument<string>;
    to: RawTransactionArgument<string>;
    value: RawTransactionArgument<number | bigint>;
    reasonCode: RawTransactionArgument<number | bigint>;
    reasonString: RawTransactionArgument<string>;
    version: RawTransactionArgument<string>;
    valuesLocked: RawTransactionArgument<Array<number | bigint>>;
    releaseTimes: RawTransactionArgument<Array<number | bigint>>;
    issuanceTimeMs: RawTransactionArgument<number | bigint>;
}
export interface IssueTokensNoAccountOptions {
    package?: string;
    arguments: IssueTokensNoAccountArguments | [
        treasury: RawTransactionArgument<string>,
        auth: RawTransactionArgument<string>,
        investors: RawTransactionArgument<string>,
        complianceConfig: RawTransactionArgument<string>,
        namespace: RawTransactionArgument<string>,
        to: RawTransactionArgument<string>,
        value: RawTransactionArgument<number | bigint>,
        reasonCode: RawTransactionArgument<number | bigint>,
        reasonString: RawTransactionArgument<string>,
        version: RawTransactionArgument<string>,
        valuesLocked: RawTransactionArgument<Array<number | bigint>>,
        releaseTimes: RawTransactionArgument<Array<number | bigint>>,
        issuanceTimeMs: RawTransactionArgument<number | bigint>
    ];
    typeArguments: [
        string
    ];
}
/**
 * Issues new tokens and deposits them to the account derived by the provided
 * address. Meant to be used in combination with the investor registration when
 * investors' account is not yet created. Only authorized addresses with the
 * IssueTokens ability can call this function.
 *
 * # Aborts
 *
 * - `ENotAuthorized` - If the sender does not have the IssueTokens ability
 */
export function issueTokensNoAccount(options: IssueTokensNoAccountOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        null,
        null,
        null,
        null,
        'address',
        'u64',
        'u64',
        '0x1::string::String',
        null,
        'vector<u64>',
        'vector<u64>',
        'u64',
        '0x2::clock::Clock'
    ] satisfies (string | null)[];
    const parameterNames = ["treasury", "auth", "investors", "complianceConfig", "namespace", "to", "value", "reasonCode", "reasonString", "version", "valuesLocked", "releaseTimes", "issuanceTimeMs"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'ds_token',
        function: 'issue_tokens_no_account',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface BurnArguments {
    treasury: RawTransactionArgument<string>;
    auth: RawTransactionArgument<string>;
    investors: RawTransactionArgument<string>;
    policy: RawTransactionArgument<string>;
    request: RawTransactionArgument<string>;
    reason: RawTransactionArgument<string>;
    version: RawTransactionArgument<string>;
}
export interface BurnOptions {
    package?: string;
    arguments: BurnArguments | [
        treasury: RawTransactionArgument<string>,
        auth: RawTransactionArgument<string>,
        investors: RawTransactionArgument<string>,
        policy: RawTransactionArgument<string>,
        request: RawTransactionArgument<string>,
        reason: RawTransactionArgument<string>,
        version: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/**
 * Burns tokens from the specified account, reducing the total supply. Only
 * authorized addresses with the BurnTokens ability can call this function.
 *
 * # Aborts
 *
 * - `ENotAuthorized` - If the sender does not have the BurnTokens ability
 * - `EAccountOwnerMismatch` - If the account owner does not match from_address
 */
export function burn(options: BurnOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        null,
        null,
        null,
        null,
        '0x1::string::String',
        null
    ] satisfies (string | null)[];
    const parameterNames = ["treasury", "auth", "investors", "policy", "request", "reason", "version"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'ds_token',
        function: 'burn',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface SeizeArguments {
    auth: RawTransactionArgument<string>;
    investors: RawTransactionArgument<string>;
    policy: RawTransactionArgument<string>;
    request: RawTransactionArgument<string>;
    to: RawTransactionArgument<string>;
    toAddress: RawTransactionArgument<string>;
    reason: RawTransactionArgument<string>;
    version: RawTransactionArgument<string>;
}
export interface SeizeOptions {
    package?: string;
    arguments: SeizeArguments | [
        auth: RawTransactionArgument<string>,
        investors: RawTransactionArgument<string>,
        policy: RawTransactionArgument<string>,
        request: RawTransactionArgument<string>,
        to: RawTransactionArgument<string>,
        toAddress: RawTransactionArgument<string>,
        reason: RawTransactionArgument<string>,
        version: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/**
 * Seizes tokens from one account and transfers them to another account. Only
 * authorized addresses with the SeizeTokens ability can call this function.
 *
 * # Aborts
 *
 * - `ENotAuthorized` - If the sender does not have the SeizeTokens ability
 * - `EAccountOwnerMismatch` - If the account owner does not match the expected
 *   address
 */
export function seize(options: SeizeOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        null,
        null,
        null,
        null,
        'address',
        '0x1::string::String',
        null
    ] satisfies (string | null)[];
    const parameterNames = ["auth", "investors", "policy", "request", "to", "toAddress", "reason", "version"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'ds_token',
        function: 'seize',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface TransferArguments {
    treasury: RawTransactionArgument<string>;
    investors: RawTransactionArgument<string>;
    complianceConfig: RawTransactionArgument<string>;
    request: RawTransactionArgument<string>;
    version: RawTransactionArgument<string>;
}
export interface TransferOptions {
    package?: string;
    arguments: TransferArguments | [
        treasury: RawTransactionArgument<string>,
        investors: RawTransactionArgument<string>,
        complianceConfig: RawTransactionArgument<string>,
        request: RawTransactionArgument<string>,
        version: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/**
 * Processes a token transfer request between accounts. The treasury must not be
 * paused for the transfer to succeed.
 *
 * # Aborts
 *
 * - `EValueZero` - If the transfer value is zero
 * - `ETreasuryPaused` - If the treasury is paused and both parties are investors
 */
export function transfer(options: TransferOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        null,
        null,
        null,
        null,
        '0x2::clock::Clock'
    ] satisfies (string | null)[];
    const parameterNames = ["treasury", "investors", "complianceConfig", "request", "version"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'ds_token',
        function: 'transfer',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface SetMetadataArguments {
    treasury: RawTransactionArgument<string>;
    auth: RawTransactionArgument<string>;
    currency: RawTransactionArgument<string>;
    name: RawTransactionArgument<string | null>;
    description: RawTransactionArgument<string | null>;
    iconUrl: RawTransactionArgument<string | null>;
    version: RawTransactionArgument<string>;
}
export interface SetMetadataOptions {
    package?: string;
    arguments: SetMetadataArguments | [
        treasury: RawTransactionArgument<string>,
        auth: RawTransactionArgument<string>,
        currency: RawTransactionArgument<string>,
        name: RawTransactionArgument<string | null>,
        description: RawTransactionArgument<string | null>,
        iconUrl: RawTransactionArgument<string | null>,
        version: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/**
 * Updates the token's metadata (name, description, and/or icon URL). Only
 * authorized addresses with the MetadataUpdate ability can call this function.
 * Each metadata field is optional - only provided values will be updated.
 *
 * # Aborts
 *
 * - `ENotAuthorized` - If the sender does not have the MetadataUpdate ability
 */
export function setMetadata(options: SetMetadataOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        null,
        null,
        '0x1::option::Option<0x1::string::String>',
        '0x1::option::Option<0x1::string::String>',
        '0x1::option::Option<0x1::string::String>',
        null
    ] satisfies (string | null)[];
    const parameterNames = ["treasury", "auth", "currency", "name", "description", "iconUrl", "version"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'ds_token',
        function: 'set_metadata',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface SetTemplateCommandArguments {
    auth: RawTransactionArgument<string>;
    templates: RawTransactionArgument<string>;
    command: RawTransactionArgument<string>;
    version: RawTransactionArgument<string>;
}
export interface SetTemplateCommandOptions {
    package?: string;
    arguments: SetTemplateCommandArguments | [
        auth: RawTransactionArgument<string>,
        templates: RawTransactionArgument<string>,
        command: RawTransactionArgument<string>,
        version: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
export function setTemplateCommand(options: SetTemplateCommandOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        null,
        null,
        null
    ] satisfies (string | null)[];
    const parameterNames = ["auth", "templates", "command", "version"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'ds_token',
        function: 'set_template_command',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface UnsetTemplateCommandArguments {
    auth: RawTransactionArgument<string>;
    templates: RawTransactionArgument<string>;
    version: RawTransactionArgument<string>;
}
export interface UnsetTemplateCommandOptions {
    package?: string;
    arguments: UnsetTemplateCommandArguments | [
        auth: RawTransactionArgument<string>,
        templates: RawTransactionArgument<string>,
        version: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
export function unsetTemplateCommand(options: UnsetTemplateCommandOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        null,
        null
    ] satisfies (string | null)[];
    const parameterNames = ["auth", "templates", "version"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'ds_token',
        function: 'unset_template_command',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface PauseArguments {
    treasury: RawTransactionArgument<string>;
    auth: RawTransactionArgument<string>;
    version: RawTransactionArgument<string>;
}
export interface PauseOptions {
    package?: string;
    arguments: PauseArguments | [
        treasury: RawTransactionArgument<string>,
        auth: RawTransactionArgument<string>,
        version: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/**
 * Pauses the treasury, preventing token operations. Only authorized addresses
 * should be able to call this function.
 *
 * # Aborts
 *
 * - `ENotAuthorized` - If the sender does not have the Pauser ability
 * - `ETreasuryAlreadyPaused` - If the treasury is already paused
 */
export function pause(options: PauseOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        null,
        null
    ] satisfies (string | null)[];
    const parameterNames = ["treasury", "auth", "version"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'ds_token',
        function: 'pause',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface UnpauseArguments {
    treasury: RawTransactionArgument<string>;
    auth: RawTransactionArgument<string>;
    version: RawTransactionArgument<string>;
}
export interface UnpauseOptions {
    package?: string;
    arguments: UnpauseArguments | [
        treasury: RawTransactionArgument<string>,
        auth: RawTransactionArgument<string>,
        version: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/**
 * Unpauses the treasury, allowing token operations to resume. Only authorized
 * addresses should be able to call this function.
 *
 * # Aborts
 *
 * - `ENotAuthorized` - If the sender does not have the Pauser ability
 * - `ETreasuryNotPaused` - If the treasury is not currently paused
 */
export function unpause(options: UnpauseOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        null,
        null
    ] satisfies (string | null)[];
    const parameterNames = ["treasury", "auth", "version"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'ds_token',
        function: 'unpause',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface PolicyCapArguments {
    treasury: RawTransactionArgument<string>;
    auth: RawTransactionArgument<string>;
    version: RawTransactionArgument<string>;
}
export interface PolicyCapOptions {
    package?: string;
    arguments: PolicyCapArguments | [
        treasury: RawTransactionArgument<string>,
        auth: RawTransactionArgument<string>,
        version: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/**
 * Returns a reference to the PolicyCap stored in the Treasury. Only authorized
 * addresses with the AccessPolicyCap ability can call this function.
 *
 * # Aborts
 *
 * - `ENotAuthorized` - If the sender does not have the AccessPolicyCap ability
 */
export function policyCap(options: PolicyCapOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        null,
        null
    ] satisfies (string | null)[];
    const parameterNames = ["treasury", "auth", "version"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'ds_token',
        function: 'policy_cap',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface IsPausedArguments {
    treasury: RawTransactionArgument<string>;
}
export interface IsPausedOptions {
    package?: string;
    arguments: IsPausedArguments | [
        treasury: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/** Returns whether the treasury is currently paused. */
export function isPaused(options: IsPausedOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["treasury"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'ds_token',
        function: 'is_paused',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}