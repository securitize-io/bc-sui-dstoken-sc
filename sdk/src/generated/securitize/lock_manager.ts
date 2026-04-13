/**************************************************************
 * THIS FILE IS GENERATED AND SHOULD NOT BE MANUALLY MODIFIED *
 **************************************************************/


/**
 * Module: lock_manager
 * 
 * Manages token locks for investors, including full account locks, liquidate-only
 * restrictions, and time-based lock records for specific token amounts.
 */

import { type Transaction } from '@mysten/sui/transactions';
import { normalizeMoveArguments, type RawTransactionArgument } from '../utils/index.js';
export interface LockInvestorArguments {
    registry: RawTransactionArgument<string>;
    investor: RawTransactionArgument<string>;
    auth: RawTransactionArgument<string>;
    version: RawTransactionArgument<string>;
}
export interface LockInvestorOptions {
    package?: string;
    arguments: LockInvestorArguments | [
        registry: RawTransactionArgument<string>,
        investor: RawTransactionArgument<string>,
        auth: RawTransactionArgument<string>,
        version: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/**
 * Fully locks an investor's account, preventing all transfers.
 *
 * # Aborts
 *
 * - `ENotAuthorized` - If caller lacks LockInvestor ability
 * - `EAlreadyLocked` - If the investor is already fully locked
 */
export function lockInvestor(options: LockInvestorOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        '0x1::string::String',
        null,
        null
    ] satisfies (string | null)[];
    const parameterNames = ["registry", "investor", "auth", "version"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'lock_manager',
        function: 'lock_investor',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface UnlockInvestorArguments {
    registry: RawTransactionArgument<string>;
    investor: RawTransactionArgument<string>;
    auth: RawTransactionArgument<string>;
    version: RawTransactionArgument<string>;
}
export interface UnlockInvestorOptions {
    package?: string;
    arguments: UnlockInvestorArguments | [
        registry: RawTransactionArgument<string>,
        investor: RawTransactionArgument<string>,
        auth: RawTransactionArgument<string>,
        version: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/**
 * Unlocks a fully locked investor's account, allowing transfers again.
 *
 * # Aborts
 *
 * - `ENotAuthorized` - If caller lacks UnlockInvestor ability
 * - `ENotLocked` - If the investor is not fully locked
 */
export function unlockInvestor(options: UnlockInvestorOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        '0x1::string::String',
        null,
        null
    ] satisfies (string | null)[];
    const parameterNames = ["registry", "investor", "auth", "version"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'lock_manager',
        function: 'unlock_investor',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface SetLiquidateOnlyArguments {
    registry: RawTransactionArgument<string>;
    investor: RawTransactionArgument<string>;
    enabled: RawTransactionArgument<boolean>;
    auth: RawTransactionArgument<string>;
    version: RawTransactionArgument<string>;
}
export interface SetLiquidateOnlyOptions {
    package?: string;
    arguments: SetLiquidateOnlyArguments | [
        registry: RawTransactionArgument<string>,
        investor: RawTransactionArgument<string>,
        enabled: RawTransactionArgument<boolean>,
        auth: RawTransactionArgument<string>,
        version: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/**
 * Sets the liquidate-only restriction for an investor. When enabled, the investor
 * is not allowed to receive tokens.
 *
 * # Aborts
 *
 * - `ENotAuthorized` - If caller lacks SetLiquidateOnly ability
 */
export function setLiquidateOnly(options: SetLiquidateOnlyOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        '0x1::string::String',
        'bool',
        null,
        null
    ] satisfies (string | null)[];
    const parameterNames = ["registry", "investor", "enabled", "auth", "version"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'lock_manager',
        function: 'set_liquidate_only',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface AddLockArguments {
    registry: RawTransactionArgument<string>;
    investor: RawTransactionArgument<string>;
    value: RawTransactionArgument<number | bigint>;
    reasonCode: RawTransactionArgument<number | bigint>;
    reasonString: RawTransactionArgument<string>;
    releaseTimeMs: RawTransactionArgument<number | bigint>;
    auth: RawTransactionArgument<string>;
    version: RawTransactionArgument<string>;
}
export interface AddLockOptions {
    package?: string;
    arguments: AddLockArguments | [
        registry: RawTransactionArgument<string>,
        investor: RawTransactionArgument<string>,
        value: RawTransactionArgument<number | bigint>,
        reasonCode: RawTransactionArgument<number | bigint>,
        reasonString: RawTransactionArgument<string>,
        releaseTimeMs: RawTransactionArgument<number | bigint>,
        auth: RawTransactionArgument<string>,
        version: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/**
 * Adds a time-based lock record for a specific token amount (external). This is
 * the public entry point that requires authorization.
 *
 * # Aborts
 *
 * - `ENotAuthorized` - If caller lacks AddLockRecord ability
 * - `EInvalidValue` - If the value is zero
 * - `EInvalidTime` - If the release time is non-zero and in the past
 * - `ETooManyLocks` - If the investor already has the maximum number of locks
 */
export function addLock(options: AddLockOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        '0x1::string::String',
        'u64',
        'u64',
        '0x1::string::String',
        'u64',
        null,
        null,
        '0x2::clock::Clock'
    ] satisfies (string | null)[];
    const parameterNames = ["registry", "investor", "value", "reasonCode", "reasonString", "releaseTimeMs", "auth", "version"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'lock_manager',
        function: 'add_lock',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface RemoveLockArguments {
    registry: RawTransactionArgument<string>;
    investor: RawTransactionArgument<string>;
    index: RawTransactionArgument<number | bigint>;
    auth: RawTransactionArgument<string>;
    version: RawTransactionArgument<string>;
}
export interface RemoveLockOptions {
    package?: string;
    arguments: RemoveLockArguments | [
        registry: RawTransactionArgument<string>,
        investor: RawTransactionArgument<string>,
        index: RawTransactionArgument<number | bigint>,
        auth: RawTransactionArgument<string>,
        version: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/**
 * Removes a lock record at the specified index.
 *
 * # Aborts
 *
 * - `ENotAuthorized` - If caller lacks RemoveLockRecord ability
 * - `EIndexOutOfRange` - If the index is out of range
 */
export function removeLock(options: RemoveLockOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        '0x1::string::String',
        'u64',
        null,
        null
    ] satisfies (string | null)[];
    const parameterNames = ["registry", "investor", "index", "auth", "version"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'lock_manager',
        function: 'remove_lock',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface ComputeTransferableArguments {
    registry: RawTransactionArgument<string>;
    investor: RawTransactionArgument<string>;
    balance: RawTransactionArgument<number | bigint>;
    timestampMs: RawTransactionArgument<number | bigint>;
}
export interface ComputeTransferableOptions {
    package?: string;
    arguments: ComputeTransferableArguments | [
        registry: RawTransactionArgument<string>,
        investor: RawTransactionArgument<string>,
        balance: RawTransactionArgument<number | bigint>,
        timestampMs: RawTransactionArgument<number | bigint>
    ];
    typeArguments: [
        string
    ];
}
export function computeTransferable(options: ComputeTransferableOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        '0x1::string::String',
        'u64',
        'u64'
    ] satisfies (string | null)[];
    const parameterNames = ["registry", "investor", "balance", "timestampMs"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'lock_manager',
        function: 'compute_transferable',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface IsLiquidateOnlyArguments {
    registry: RawTransactionArgument<string>;
    investor: RawTransactionArgument<string>;
}
export interface IsLiquidateOnlyOptions {
    package?: string;
    arguments: IsLiquidateOnlyArguments | [
        registry: RawTransactionArgument<string>,
        investor: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
export function isLiquidateOnly(options: IsLiquidateOnlyOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        '0x1::string::String'
    ] satisfies (string | null)[];
    const parameterNames = ["registry", "investor"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'lock_manager',
        function: 'is_liquidate_only',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface IsInvestorLockedArguments {
    registry: RawTransactionArgument<string>;
    investor: RawTransactionArgument<string>;
}
export interface IsInvestorLockedOptions {
    package?: string;
    arguments: IsInvestorLockedArguments | [
        registry: RawTransactionArgument<string>,
        investor: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
export function isInvestorLocked(options: IsInvestorLockedOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        '0x1::string::String'
    ] satisfies (string | null)[];
    const parameterNames = ["registry", "investor"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'lock_manager',
        function: 'is_investor_locked',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface LockCountArguments {
    registry: RawTransactionArgument<string>;
    investor: RawTransactionArgument<string>;
}
export interface LockCountOptions {
    package?: string;
    arguments: LockCountArguments | [
        registry: RawTransactionArgument<string>,
        investor: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
export function lockCount(options: LockCountOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        '0x1::string::String'
    ] satisfies (string | null)[];
    const parameterNames = ["registry", "investor"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'lock_manager',
        function: 'lock_count',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}