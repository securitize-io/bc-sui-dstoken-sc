/**************************************************************
 * THIS FILE IS GENERATED AND SHOULD NOT BE MANUALLY MODIFIED *
 **************************************************************/


/**
 * Module: lockup_restriction
 * 
 * Rule that enforces lock-up periods on token issuances. Tokens are locked for a
 * configurable period after issuance, with separate lock periods for US and non-US
 * investors.
 * 
 * This module validates that transfers do not exceed the amount of unlocked
 * (transferable) tokens based on issuance timestamps tracked in InvestorInfo.
 */

import { MoveStruct, normalizeMoveArguments, type RawTransactionArgument } from '../utils/index.js';
import { bcs } from '@mysten/sui/bcs';
import { type Transaction } from '@mysten/sui/transactions';
const $moduleName = '@securitize/securitize::lockup_restriction';
export const LockupRestriction = new MoveStruct({ name: `${$moduleName}::LockupRestriction`, fields: {
        /** Lock period for US investors (in milliseconds) */
        us_lock_period_ms: bcs.u64(),
        /** Lock period for non-US investors (in milliseconds) */
        non_us_lock_period_ms: bcs.u64()
    } });
export interface NewArguments {
    auth: RawTransactionArgument<string>;
    usLockPeriodMs: RawTransactionArgument<number | bigint>;
    nonUsLockPeriodMs: RawTransactionArgument<number | bigint>;
    version: RawTransactionArgument<string>;
}
export interface NewOptions {
    package?: string;
    arguments: NewArguments | [
        auth: RawTransactionArgument<string>,
        usLockPeriodMs: RawTransactionArgument<number | bigint>,
        nonUsLockPeriodMs: RawTransactionArgument<number | bigint>,
        version: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/**
 * Create a new LockupRestriction rule with configurable lock periods.
 *
 * # Aborts
 *
 * - `ENotAuthorized` - If caller lacks RegisterRule ability
 * - `ELockPeriodTooLong` - If either lock period exceeds maximum (200 years)
 */
export function _new(options: NewOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        'u64',
        'u64',
        null
    ] satisfies (string | null)[];
    const parameterNames = ["auth", "usLockPeriodMs", "nonUsLockPeriodMs", "version"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'lockup_restriction',
        function: 'new',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface SetUsLockPeriodArguments {
    auth: RawTransactionArgument<string>;
    wrapper: RawTransactionArgument<string>;
    periodMs: RawTransactionArgument<number | bigint>;
    version: RawTransactionArgument<string>;
}
export interface SetUsLockPeriodOptions {
    package?: string;
    arguments: SetUsLockPeriodArguments | [
        auth: RawTransactionArgument<string>,
        wrapper: RawTransactionArgument<string>,
        periodMs: RawTransactionArgument<number | bigint>,
        version: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/**
 * Set US lock period (in milliseconds).
 *
 * # Aborts
 *
 * - `ENotAuthorized` - If caller lacks ManageRules ability
 * - `ELockPeriodTooLong` - If period exceeds maximum (200 years)
 */
export function setUsLockPeriod(options: SetUsLockPeriodOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        null,
        'u64',
        null
    ] satisfies (string | null)[];
    const parameterNames = ["auth", "wrapper", "periodMs", "version"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'lockup_restriction',
        function: 'set_us_lock_period',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface SetNonUsLockPeriodArguments {
    auth: RawTransactionArgument<string>;
    wrapper: RawTransactionArgument<string>;
    periodMs: RawTransactionArgument<number | bigint>;
    version: RawTransactionArgument<string>;
}
export interface SetNonUsLockPeriodOptions {
    package?: string;
    arguments: SetNonUsLockPeriodArguments | [
        auth: RawTransactionArgument<string>,
        wrapper: RawTransactionArgument<string>,
        periodMs: RawTransactionArgument<number | bigint>,
        version: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/**
 * Set non-US lock period (in milliseconds).
 *
 * # Aborts
 *
 * - `ENotAuthorized` - If caller lacks ManageRules ability
 * - `ELockPeriodTooLong` - If period exceeds maximum (200 years)
 */
export function setNonUsLockPeriod(options: SetNonUsLockPeriodOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        null,
        'u64',
        null
    ] satisfies (string | null)[];
    const parameterNames = ["auth", "wrapper", "periodMs", "version"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'lockup_restriction',
        function: 'set_non_us_lock_period',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface ValidateRuleArguments {
    rule: RawTransactionArgument<string>;
    investorIssuances: RawTransactionArgument<Array<string>>;
    amount: RawTransactionArgument<number | bigint>;
    fromRegion: RawTransactionArgument<number | bigint>;
    fromIsSpecialWallet: RawTransactionArgument<boolean>;
    currentTransferableBalance: RawTransactionArgument<number | bigint>;
    timestampMs: RawTransactionArgument<number | bigint>;
}
export interface ValidateRuleOptions {
    package?: string;
    arguments: ValidateRuleArguments | [
        rule: RawTransactionArgument<string>,
        investorIssuances: RawTransactionArgument<Array<string>>,
        amount: RawTransactionArgument<number | bigint>,
        fromRegion: RawTransactionArgument<number | bigint>,
        fromIsSpecialWallet: RawTransactionArgument<boolean>,
        currentTransferableBalance: RawTransactionArgument<number | bigint>,
        timestampMs: RawTransactionArgument<number | bigint>
    ];
}
/**
 * Validate that a transfer does not exceed the transferable (issuances unlocked)
 * token amount.
 *
 * # Aborts
 *
 * - `EUnderLockup` - If transfer amount exceeds transferable balance
 */
export function validateRule(options: ValidateRuleOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        'vector<null>',
        'u64',
        'u64',
        'bool',
        'u64',
        'u64'
    ] satisfies (string | null)[];
    const parameterNames = ["rule", "investorIssuances", "amount", "fromRegion", "fromIsSpecialWallet", "currentTransferableBalance", "timestampMs"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'lockup_restriction',
        function: 'validate_rule',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface ComputeTransferableTokensArguments {
    rule: RawTransactionArgument<string>;
    investorIssuances: RawTransactionArgument<Array<string>>;
    region: RawTransactionArgument<number | bigint>;
    balance: RawTransactionArgument<number | bigint>;
    timestampMs: RawTransactionArgument<number | bigint>;
}
export interface ComputeTransferableTokensOptions {
    package?: string;
    arguments: ComputeTransferableTokensArguments | [
        rule: RawTransactionArgument<string>,
        investorIssuances: RawTransactionArgument<Array<string>>,
        region: RawTransactionArgument<number | bigint>,
        balance: RawTransactionArgument<number | bigint>,
        timestampMs: RawTransactionArgument<number | bigint>
    ];
}
/**
 * Compute the number of transferable (unlocked) tokens for an investor.
 *
 * This calculates the balance minus any tokens still under lockup from issuances.
 */
export function computeTransferableTokens(options: ComputeTransferableTokensOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        'vector<null>',
        'u64',
        'u64',
        'u64'
    ] satisfies (string | null)[];
    const parameterNames = ["rule", "investorIssuances", "region", "balance", "timestampMs"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'lockup_restriction',
        function: 'compute_transferable_tokens',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface IsIssuanceLockedArguments {
    rule: RawTransactionArgument<string>;
    issuance: RawTransactionArgument<string>;
    region: RawTransactionArgument<number | bigint>;
    timestampMs: RawTransactionArgument<number | bigint>;
}
export interface IsIssuanceLockedOptions {
    package?: string;
    arguments: IsIssuanceLockedArguments | [
        rule: RawTransactionArgument<string>,
        issuance: RawTransactionArgument<string>,
        region: RawTransactionArgument<number | bigint>,
        timestampMs: RawTransactionArgument<number | bigint>
    ];
}
/** Check if a specific issuance is still under lockup */
export function isIssuanceLocked(options: IsIssuanceLockedOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        null,
        'u64',
        'u64'
    ] satisfies (string | null)[];
    const parameterNames = ["rule", "issuance", "region", "timestampMs"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'lockup_restriction',
        function: 'is_issuance_locked',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface GetLockPeriodArguments {
    rule: RawTransactionArgument<string>;
    region: RawTransactionArgument<number | bigint>;
}
export interface GetLockPeriodOptions {
    package?: string;
    arguments: GetLockPeriodArguments | [
        rule: RawTransactionArgument<string>,
        region: RawTransactionArgument<number | bigint>
    ];
}
export function getLockPeriod(options: GetLockPeriodOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        'u64'
    ] satisfies (string | null)[];
    const parameterNames = ["rule", "region"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'lockup_restriction',
        function: 'get_lock_period',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface UsLockPeriodArguments {
    rule: RawTransactionArgument<string>;
}
export interface UsLockPeriodOptions {
    package?: string;
    arguments: UsLockPeriodArguments | [
        rule: RawTransactionArgument<string>
    ];
}
/** Get US lock period */
export function usLockPeriod(options: UsLockPeriodOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["rule"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'lockup_restriction',
        function: 'us_lock_period',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface NonUsLockPeriodArguments {
    rule: RawTransactionArgument<string>;
}
export interface NonUsLockPeriodOptions {
    package?: string;
    arguments: NonUsLockPeriodArguments | [
        rule: RawTransactionArgument<string>
    ];
}
/** Get non-US lock period */
export function nonUsLockPeriod(options: NonUsLockPeriodOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["rule"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'lockup_restriction',
        function: 'non_us_lock_period',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface LockPeriodForRegionArguments {
    rule: RawTransactionArgument<string>;
    region: RawTransactionArgument<number | bigint>;
}
export interface LockPeriodForRegionOptions {
    package?: string;
    arguments: LockPeriodForRegionArguments | [
        rule: RawTransactionArgument<string>,
        region: RawTransactionArgument<number | bigint>
    ];
}
/** Get the lock period for a specific region */
export function lockPeriodForRegion(options: LockPeriodForRegionOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        'u64'
    ] satisfies (string | null)[];
    const parameterNames = ["rule", "region"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'lockup_restriction',
        function: 'lock_period_for_region',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}