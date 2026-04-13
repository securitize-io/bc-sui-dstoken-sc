/**************************************************************
 * THIS FILE IS GENERATED AND SHOULD NOT BE MANUALLY MODIFIED *
 **************************************************************/


/**
 * Module: flowback_restriction
 * 
 * Rule that prevents non-US investors from transferring tokens to US investors
 * during a specified Regulation S distribution period flowback restriction.
 */

import { MoveStruct, normalizeMoveArguments, type RawTransactionArgument } from '../utils/index.js';
import { bcs } from '@mysten/sui/bcs';
import { type Transaction } from '@mysten/sui/transactions';
const $moduleName = '@securitize/securitize::flowback_restriction';
export const FlowbackRestriction = new MoveStruct({ name: `${$moduleName}::FlowbackRestriction`, fields: {
        /** End time (in ms) for the flowback restriction period (0 = transfer restriction) */
        block_flowback_end_time_ms: bcs.u64()
    } });
export interface NewArguments {
    auth: RawTransactionArgument<string>;
    blockFlowbackEndTimeMs: RawTransactionArgument<number | bigint>;
    version: RawTransactionArgument<string>;
}
export interface NewOptions {
    package?: string;
    arguments: NewArguments | [
        auth: RawTransactionArgument<string>,
        blockFlowbackEndTimeMs: RawTransactionArgument<number | bigint>,
        version: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/**
 * Create a new FlowbackRestriction rule with an end time
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
        null
    ] satisfies (string | null)[];
    const parameterNames = ["auth", "blockFlowbackEndTimeMs", "version"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'flowback_restriction',
        function: 'new',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface SetFlowbackEndTimeArguments {
    auth: RawTransactionArgument<string>;
    wrapper: RawTransactionArgument<string>;
    endTime: RawTransactionArgument<number | bigint>;
    version: RawTransactionArgument<string>;
}
export interface SetFlowbackEndTimeOptions {
    package?: string;
    arguments: SetFlowbackEndTimeArguments | [
        auth: RawTransactionArgument<string>,
        wrapper: RawTransactionArgument<string>,
        endTime: RawTransactionArgument<number | bigint>,
        version: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/**
 * Set flowback end time
 *
 * # Aborts
 *
 * - `ENotAuthorized` - If caller lacks ManageRules ability
 */
export function setFlowbackEndTime(options: SetFlowbackEndTimeOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        null,
        'u64',
        null
    ] satisfies (string | null)[];
    const parameterNames = ["auth", "wrapper", "endTime", "version"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'flowback_restriction',
        function: 'set_flowback_end_time',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface ValidateRuleArguments {
    rule: RawTransactionArgument<string>;
    fromRegion: RawTransactionArgument<number | bigint>;
    toRegion: RawTransactionArgument<number | bigint>;
    fromIsSpecialWallet: RawTransactionArgument<boolean>;
    timestampMs: RawTransactionArgument<number | bigint>;
}
export interface ValidateRuleOptions {
    package?: string;
    arguments: ValidateRuleArguments | [
        rule: RawTransactionArgument<string>,
        fromRegion: RawTransactionArgument<number | bigint>,
        toRegion: RawTransactionArgument<number | bigint>,
        fromIsSpecialWallet: RawTransactionArgument<boolean>,
        timestampMs: RawTransactionArgument<number | bigint>
    ];
}
/**
 * Validate that flowback restriction doesn't apply to this transfer.
 *
 * This checks if a non-US investor is trying to transfer to a US investor during
 * the restricted period.
 *
 * # Aborts
 *
 * - `EFlowbackRestricted` - If non-US to US transfer during active restriction
 *   period
 */
export function validateRule(options: ValidateRuleOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        'u64',
        'u64',
        'bool',
        'u64'
    ] satisfies (string | null)[];
    const parameterNames = ["rule", "fromRegion", "toRegion", "fromIsSpecialWallet", "timestampMs"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'flowback_restriction',
        function: 'validate_rule',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface FlowbackEndTimeArguments {
    rule: RawTransactionArgument<string>;
}
export interface FlowbackEndTimeOptions {
    package?: string;
    arguments: FlowbackEndTimeArguments | [
        rule: RawTransactionArgument<string>
    ];
}
/** Get flowback end time */
export function flowbackEndTime(options: FlowbackEndTimeOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["rule"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'flowback_restriction',
        function: 'flowback_end_time',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface IsActiveArguments {
    rule: RawTransactionArgument<string>;
}
export interface IsActiveOptions {
    package?: string;
    arguments: IsActiveArguments | [
        rule: RawTransactionArgument<string>
    ];
}
/** Check if flowback restriction is currently active */
export function isActive(options: IsActiveOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        '0x2::clock::Clock'
    ] satisfies (string | null)[];
    const parameterNames = ["rule"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'flowback_restriction',
        function: 'is_active',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}