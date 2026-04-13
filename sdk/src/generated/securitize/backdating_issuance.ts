/**************************************************************
 * THIS FILE IS GENERATED AND SHOULD NOT BE MANUALLY MODIFIED *
 **************************************************************/


/**
 * Module: backdating_issuance
 * 
 * Configuration rule that controls whether backdating is allowed for issuances.
 * The compliance service reads this configuration to determine the effective
 * issuance timestamp.
 */

import { MoveStruct, normalizeMoveArguments, type RawTransactionArgument } from '../utils/index.js';
import { bcs } from '@mysten/sui/bcs';
import { type Transaction } from '@mysten/sui/transactions';
const $moduleName = '@securitize/securitize::backdating_issuance';
export const BackdatingIssuance = new MoveStruct({ name: `${$moduleName}::BackdatingIssuance`, fields: {
        /** Whether backdating is allowed for issuances */
        disallow_backdating: bcs.bool()
    } });
export interface NewArguments {
    auth: RawTransactionArgument<string>;
    disallowBackdating: RawTransactionArgument<boolean>;
    version: RawTransactionArgument<string>;
}
export interface NewOptions {
    package?: string;
    arguments: NewArguments | [
        auth: RawTransactionArgument<string>,
        disallowBackdating: RawTransactionArgument<boolean>,
        version: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/**
 * Create a new BackdatingIssuance rule
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
        null
    ] satisfies (string | null)[];
    const parameterNames = ["auth", "disallowBackdating", "version"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'backdating_issuance',
        function: 'new',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface SetDisallowBackdatingArguments {
    auth: RawTransactionArgument<string>;
    wrapper: RawTransactionArgument<string>;
    disallow: RawTransactionArgument<boolean>;
    version: RawTransactionArgument<string>;
}
export interface SetDisallowBackdatingOptions {
    package?: string;
    arguments: SetDisallowBackdatingArguments | [
        auth: RawTransactionArgument<string>,
        wrapper: RawTransactionArgument<string>,
        disallow: RawTransactionArgument<boolean>,
        version: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/**
 * Set whether backdating is allowed
 *
 * # Aborts
 *
 * - `ENotAuthorized` - If caller lacks ManageRules ability
 */
export function setDisallowBackdating(options: SetDisallowBackdatingOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        null,
        'bool',
        null
    ] satisfies (string | null)[];
    const parameterNames = ["auth", "wrapper", "disallow", "version"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'backdating_issuance',
        function: 'set_disallow_backdating',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface IsBackdatingAllowedArguments {
    rule: RawTransactionArgument<string>;
}
export interface IsBackdatingAllowedOptions {
    package?: string;
    arguments: IsBackdatingAllowedArguments | [
        rule: RawTransactionArgument<string>
    ];
}
/** Check if backdating is allowed */
export function isBackdatingAllowed(options: IsBackdatingAllowedOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["rule"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'backdating_issuance',
        function: 'is_backdating_allowed',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}