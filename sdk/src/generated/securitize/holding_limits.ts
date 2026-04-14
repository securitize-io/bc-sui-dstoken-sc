/**************************************************************
 * THIS FILE IS GENERATED AND SHOULD NOT BE MANUALLY MODIFIED *
 **************************************************************/


/**
 * Module: holding_limits
 * 
 * Rule that enforces minimum and maximum holding amounts per investor. Supports
 * region-specific minimum holdings.
 */

import { MoveStruct, normalizeMoveArguments, type RawTransactionArgument } from '../utils/index.js';
import { bcs } from '@mysten/sui/bcs';
import { type Transaction } from '@mysten/sui/transactions';
import * as vec_map from './deps/sui/vec_map.js';
const $moduleName = '@securitize/securitize::holding_limits';
export const HoldingLimits = new MoveStruct({ name: `${$moduleName}::HoldingLimits`, fields: {
        /** Minimum holdings per investor (0 = no minimum) */
        min_holdings_per_investor: bcs.u64(),
        /** Maximum holdings per investor (0 = no maximum) */
        max_holdings_per_investor: bcs.u64(),
        /** Region-specific minimum holdings (e.g., US, EU) */
        region_min_tokens: vec_map.VecMap(bcs.u64(), bcs.u64())
    } });
export interface NewArguments {
    auth: RawTransactionArgument<string>;
    minHoldingsPerInvestor: RawTransactionArgument<number | bigint>;
    maxHoldingsPerInvestor: RawTransactionArgument<number | bigint>;
    regions: RawTransactionArgument<Array<number | bigint>>;
    regionMins: RawTransactionArgument<Array<number | bigint>>;
    version: RawTransactionArgument<string>;
}
export interface NewOptions {
    package?: string;
    arguments: NewArguments | [
        auth: RawTransactionArgument<string>,
        minHoldingsPerInvestor: RawTransactionArgument<number | bigint>,
        maxHoldingsPerInvestor: RawTransactionArgument<number | bigint>,
        regions: RawTransactionArgument<Array<number | bigint>>,
        regionMins: RawTransactionArgument<Array<number | bigint>>,
        version: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/**
 * Create with region-specific minimums.
 *
 * # Aborts
 *
 * - `ENotAuthorized` - If caller lacks RegisterRule ability
 */
export function _new(options: NewOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        'u64',
        'u64',
        'vector<u64>',
        'vector<u64>',
        null
    ] satisfies (string | null)[];
    const parameterNames = ["auth", "minHoldingsPerInvestor", "maxHoldingsPerInvestor", "regions", "regionMins", "version"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'holding_limits',
        function: 'new',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface SetMinHoldingsArguments {
    auth: RawTransactionArgument<string>;
    wrapper: RawTransactionArgument<string>;
    min: RawTransactionArgument<number | bigint>;
    version: RawTransactionArgument<string>;
}
export interface SetMinHoldingsOptions {
    package?: string;
    arguments: SetMinHoldingsArguments | [
        auth: RawTransactionArgument<string>,
        wrapper: RawTransactionArgument<string>,
        min: RawTransactionArgument<number | bigint>,
        version: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/**
 * Set minimum holdings
 *
 * # Aborts
 *
 * - `ENotAuthorized` - If caller lacks ManageRules ability
 */
export function setMinHoldings(options: SetMinHoldingsOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        null,
        'u64',
        null
    ] satisfies (string | null)[];
    const parameterNames = ["auth", "wrapper", "min", "version"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'holding_limits',
        function: 'set_min_holdings',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface SetMaxHoldingsArguments {
    auth: RawTransactionArgument<string>;
    wrapper: RawTransactionArgument<string>;
    max: RawTransactionArgument<number | bigint>;
    version: RawTransactionArgument<string>;
}
export interface SetMaxHoldingsOptions {
    package?: string;
    arguments: SetMaxHoldingsArguments | [
        auth: RawTransactionArgument<string>,
        wrapper: RawTransactionArgument<string>,
        max: RawTransactionArgument<number | bigint>,
        version: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/**
 * Set maximum holdings
 *
 * # Aborts
 *
 * - `ENotAuthorized` - If caller lacks ManageRules ability
 */
export function setMaxHoldings(options: SetMaxHoldingsOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        null,
        'u64',
        null
    ] satisfies (string | null)[];
    const parameterNames = ["auth", "wrapper", "max", "version"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'holding_limits',
        function: 'set_max_holdings',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface SetRegionMinHoldingsArguments {
    auth: RawTransactionArgument<string>;
    wrapper: RawTransactionArgument<string>;
    region: RawTransactionArgument<number | bigint>;
    min: RawTransactionArgument<number | bigint>;
    version: RawTransactionArgument<string>;
}
export interface SetRegionMinHoldingsOptions {
    package?: string;
    arguments: SetRegionMinHoldingsArguments | [
        auth: RawTransactionArgument<string>,
        wrapper: RawTransactionArgument<string>,
        region: RawTransactionArgument<number | bigint>,
        min: RawTransactionArgument<number | bigint>,
        version: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/**
 * Set region-specific minimum holdings.
 *
 * # Aborts
 *
 * - `ENotAuthorized` - If caller lacks ManageRules ability
 */
export function setRegionMinHoldings(options: SetRegionMinHoldingsOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        null,
        'u64',
        'u64',
        null
    ] satisfies (string | null)[];
    const parameterNames = ["auth", "wrapper", "region", "min", "version"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'holding_limits',
        function: 'set_region_min_holdings',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface RemoveRegionMinHoldingsArguments {
    auth: RawTransactionArgument<string>;
    wrapper: RawTransactionArgument<string>;
    region: RawTransactionArgument<number | bigint>;
    version: RawTransactionArgument<string>;
}
export interface RemoveRegionMinHoldingsOptions {
    package?: string;
    arguments: RemoveRegionMinHoldingsArguments | [
        auth: RawTransactionArgument<string>,
        wrapper: RawTransactionArgument<string>,
        region: RawTransactionArgument<number | bigint>,
        version: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/**
 * Remove region-specific minimum
 *
 * # Aborts
 *
 * - `ENotAuthorized` - If caller lacks ManageRules ability
 */
export function removeRegionMinHoldings(options: RemoveRegionMinHoldingsOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        null,
        'u64',
        null
    ] satisfies (string | null)[];
    const parameterNames = ["auth", "wrapper", "region", "version"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'holding_limits',
        function: 'remove_region_min_holdings',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface ValidateHoldingLimitsForTransferArguments {
    rule: RawTransactionArgument<string>;
    amount: RawTransactionArgument<number | bigint>;
    fromIsSpecialWallet: RawTransactionArgument<boolean>;
    fromBalance: RawTransactionArgument<number | bigint>;
    fromRegion: RawTransactionArgument<number | bigint>;
    toBalance: RawTransactionArgument<number | bigint>;
    toRegion: RawTransactionArgument<number | bigint>;
}
export interface ValidateHoldingLimitsForTransferOptions {
    package?: string;
    arguments: ValidateHoldingLimitsForTransferArguments | [
        rule: RawTransactionArgument<string>,
        amount: RawTransactionArgument<number | bigint>,
        fromIsSpecialWallet: RawTransactionArgument<boolean>,
        fromBalance: RawTransactionArgument<number | bigint>,
        fromRegion: RawTransactionArgument<number | bigint>,
        toBalance: RawTransactionArgument<number | bigint>,
        toRegion: RawTransactionArgument<number | bigint>
    ];
}
export function validateHoldingLimitsForTransfer(options: ValidateHoldingLimitsForTransferOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        'u64',
        'bool',
        'u64',
        'u64',
        'u64',
        'u64'
    ] satisfies (string | null)[];
    const parameterNames = ["rule", "amount", "fromIsSpecialWallet", "fromBalance", "fromRegion", "toBalance", "toRegion"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'holding_limits',
        function: 'validate_holding_limits_for_transfer',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface ValidateHoldingLimitsForIssuanceArguments {
    rule: RawTransactionArgument<string>;
    amount: RawTransactionArgument<number | bigint>;
    toBalance: RawTransactionArgument<number | bigint>;
    toRegion: RawTransactionArgument<number | bigint>;
}
export interface ValidateHoldingLimitsForIssuanceOptions {
    package?: string;
    arguments: ValidateHoldingLimitsForIssuanceArguments | [
        rule: RawTransactionArgument<string>,
        amount: RawTransactionArgument<number | bigint>,
        toBalance: RawTransactionArgument<number | bigint>,
        toRegion: RawTransactionArgument<number | bigint>
    ];
}
/** Validate holding limits for issuance (receiver only) */
export function validateHoldingLimitsForIssuance(options: ValidateHoldingLimitsForIssuanceOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        'u64',
        'u64',
        'u64'
    ] satisfies (string | null)[];
    const parameterNames = ["rule", "amount", "toBalance", "toRegion"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'holding_limits',
        function: 'validate_holding_limits_for_issuance',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface ValidateMinHoldingsArguments {
    rule: RawTransactionArgument<string>;
    balanceAfter: RawTransactionArgument<number | bigint>;
    region: RawTransactionArgument<number | bigint>;
}
export interface ValidateMinHoldingsOptions {
    package?: string;
    arguments: ValidateMinHoldingsArguments | [
        rule: RawTransactionArgument<string>,
        balanceAfter: RawTransactionArgument<number | bigint>,
        region: RawTransactionArgument<number | bigint>
    ];
}
/**
 * Validate only MINIMUM holdings (global + region).
 *
 * # Aborts
 *
 * - `EBelowMinHolding` - If balance is below global or region minimum
 */
export function validateMinHoldings(options: ValidateMinHoldingsOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        'u64',
        'u64'
    ] satisfies (string | null)[];
    const parameterNames = ["rule", "balanceAfter", "region"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'holding_limits',
        function: 'validate_min_holdings',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface ValidateMaxHoldingsArguments {
    rule: RawTransactionArgument<string>;
    balanceAfter: RawTransactionArgument<number | bigint>;
}
export interface ValidateMaxHoldingsOptions {
    package?: string;
    arguments: ValidateMaxHoldingsArguments | [
        rule: RawTransactionArgument<string>,
        balanceAfter: RawTransactionArgument<number | bigint>
    ];
}
/**
 * Validate only MAXIMUM holdings (global).
 *
 * # Aborts
 *
 * - `EAboveMaxHolding` - If balance exceeds maximum
 */
export function validateMaxHoldings(options: ValidateMaxHoldingsOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        'u64'
    ] satisfies (string | null)[];
    const parameterNames = ["rule", "balanceAfter"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'holding_limits',
        function: 'validate_max_holdings',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface MinHoldingsArguments {
    rule: RawTransactionArgument<string>;
}
export interface MinHoldingsOptions {
    package?: string;
    arguments: MinHoldingsArguments | [
        rule: RawTransactionArgument<string>
    ];
}
/** Get minimum holdings */
export function minHoldings(options: MinHoldingsOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["rule"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'holding_limits',
        function: 'min_holdings',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface MaxHoldingsArguments {
    rule: RawTransactionArgument<string>;
}
export interface MaxHoldingsOptions {
    package?: string;
    arguments: MaxHoldingsArguments | [
        rule: RawTransactionArgument<string>
    ];
}
/** Get maximum holdings */
export function maxHoldings(options: MaxHoldingsOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["rule"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'holding_limits',
        function: 'max_holdings',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface RegionMinHoldingsArguments {
    rule: RawTransactionArgument<string>;
    region: RawTransactionArgument<number | bigint>;
}
export interface RegionMinHoldingsOptions {
    package?: string;
    arguments: RegionMinHoldingsArguments | [
        rule: RawTransactionArgument<string>,
        region: RawTransactionArgument<number | bigint>
    ];
}
/**
 * Get region-specific minimum holdings.
 *
 * # Aborts
 *
 * - `ERegionNotFound` - If the region does not have a minimum configured
 */
export function regionMinHoldings(options: RegionMinHoldingsOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        'u64'
    ] satisfies (string | null)[];
    const parameterNames = ["rule", "region"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'holding_limits',
        function: 'region_min_holdings',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}