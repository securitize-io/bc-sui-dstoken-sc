/**************************************************************
 * THIS FILE IS GENERATED AND SHOULD NOT BE MANUALLY MODIFIED *
 **************************************************************/


/**
 * Module: force_full_transfer
 * 
 * Rule that requires investors to transfer their entire token balance. Can be
 * configured separately for US investors or applied worldwide.
 */

import { MoveStruct, normalizeMoveArguments, type RawTransactionArgument } from '../utils/index.js';
import { bcs } from '@mysten/sui/bcs';
import { type Transaction } from '@mysten/sui/transactions';
const $moduleName = '@securitize/securitize::force_full_transfer';
export const ForceFullTransfer = new MoveStruct({ name: `${$moduleName}::ForceFullTransfer`, fields: {
        /** Require US investors to transfer entire balance */
        force_full_transfer_us: bcs.bool(),
        /** Require all investors worldwide to transfer entire balance */
        force_full_transfer_worldwide: bcs.bool()
    } });
export interface NewArguments {
    auth: RawTransactionArgument<string>;
    forceFullTransferUs: RawTransactionArgument<boolean>;
    forceFullTransferWorldwide: RawTransactionArgument<boolean>;
    version: RawTransactionArgument<string>;
}
export interface NewOptions {
    package?: string;
    arguments: NewArguments | [
        auth: RawTransactionArgument<string>,
        forceFullTransferUs: RawTransactionArgument<boolean>,
        forceFullTransferWorldwide: RawTransactionArgument<boolean>,
        version: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/**
 * Create a new ForceFullTransfer rule
 *
 * # Aborts
 *
 * - `ENotAuthorized` - If caller lacks RegisterRule ability
 */
export function _new(options: NewOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        'bool',
        'bool',
        null
    ] satisfies (string | null)[];
    const parameterNames = ["auth", "forceFullTransferUs", "forceFullTransferWorldwide", "version"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'force_full_transfer',
        function: 'new',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface SetForceUsArguments {
    auth: RawTransactionArgument<string>;
    wrapper: RawTransactionArgument<string>;
    force: RawTransactionArgument<boolean>;
    version: RawTransactionArgument<string>;
}
export interface SetForceUsOptions {
    package?: string;
    arguments: SetForceUsArguments | [
        auth: RawTransactionArgument<string>,
        wrapper: RawTransactionArgument<string>,
        force: RawTransactionArgument<boolean>,
        version: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/**
 * Set force full transfer for US investors
 *
 * # Aborts
 *
 * - `ENotAuthorized` - If caller lacks ManageRules ability
 */
export function setForceUs(options: SetForceUsOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        null,
        'bool',
        null
    ] satisfies (string | null)[];
    const parameterNames = ["auth", "wrapper", "force", "version"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'force_full_transfer',
        function: 'set_force_us',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface SetForceWorldwideArguments {
    auth: RawTransactionArgument<string>;
    wrapper: RawTransactionArgument<string>;
    force: RawTransactionArgument<boolean>;
    version: RawTransactionArgument<string>;
}
export interface SetForceWorldwideOptions {
    package?: string;
    arguments: SetForceWorldwideArguments | [
        auth: RawTransactionArgument<string>,
        wrapper: RawTransactionArgument<string>,
        force: RawTransactionArgument<boolean>,
        version: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/**
 * Set force full transfer worldwide
 *
 * # Aborts
 *
 * - `ENotAuthorized` - If caller lacks ManageRules ability
 */
export function setForceWorldwide(options: SetForceWorldwideOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        null,
        'bool',
        null
    ] satisfies (string | null)[];
    const parameterNames = ["auth", "wrapper", "force", "version"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'force_full_transfer',
        function: 'set_force_worldwide',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface ValidateRuleArguments {
    rule: RawTransactionArgument<string>;
    fromRegion: RawTransactionArgument<number | bigint>;
    fromIsSpecialWallet: RawTransactionArgument<boolean>;
    fromIsExitInvestor: RawTransactionArgument<boolean>;
}
export interface ValidateRuleOptions {
    package?: string;
    arguments: ValidateRuleArguments | [
        rule: RawTransactionArgument<string>,
        fromRegion: RawTransactionArgument<number | bigint>,
        fromIsSpecialWallet: RawTransactionArgument<boolean>,
        fromIsExitInvestor: RawTransactionArgument<boolean>
    ];
}
/**
 * Validate that transfer complies with force full transfer rules.
 *
 * # Aborts
 *
 * - `EPartialTransferNotAllowed` - If partial transfer when full transfer is
 *   required
 */
export function validateRule(options: ValidateRuleOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        'u64',
        'bool',
        'bool'
    ] satisfies (string | null)[];
    const parameterNames = ["rule", "fromRegion", "fromIsSpecialWallet", "fromIsExitInvestor"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'force_full_transfer',
        function: 'validate_rule',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface IsForceUsArguments {
    rule: RawTransactionArgument<string>;
}
export interface IsForceUsOptions {
    package?: string;
    arguments: IsForceUsArguments | [
        rule: RawTransactionArgument<string>
    ];
}
/** Check if US investors must transfer full balance */
export function isForceUs(options: IsForceUsOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["rule"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'force_full_transfer',
        function: 'is_force_us',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface IsForceWorldwideArguments {
    rule: RawTransactionArgument<string>;
}
export interface IsForceWorldwideOptions {
    package?: string;
    arguments: IsForceWorldwideArguments | [
        rule: RawTransactionArgument<string>
    ];
}
/** Check if all investors must transfer full balance */
export function isForceWorldwide(options: IsForceWorldwideOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["rule"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'force_full_transfer',
        function: 'is_force_worldwide',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}