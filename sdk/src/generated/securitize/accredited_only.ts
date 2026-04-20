/**************************************************************
 * THIS FILE IS GENERATED AND SHOULD NOT BE MANUALLY MODIFIED *
 **************************************************************/


/**
 * Module: accredited_only
 * 
 * Rule that restricts transfers to only accredited investors. Can be configured
 * globally or for specific jurisdictions.
 */

import { MoveStruct, normalizeMoveArguments, type RawTransactionArgument } from '../utils/index.js';
import { bcs } from '@mysten/sui/bcs';
import { type Transaction } from '@mysten/sui/transactions';
const $moduleName = '@securitize/securitize::accredited_only';
export const AccreditedOnly = new MoveStruct({ name: `${$moduleName}::AccreditedOnly`, fields: {
        /** Require accreditation globally */
        force_accredited: bcs.bool(),
        /** Require US accreditation for US investors */
        force_us_accredited: bcs.bool()
    } });
export interface NewArguments {
    auth: RawTransactionArgument<string>;
    forceAccredited: RawTransactionArgument<boolean>;
    forceUsAccredited: RawTransactionArgument<boolean>;
    version: RawTransactionArgument<string>;
}
export interface NewOptions {
    package?: string;
    arguments: NewArguments | [
        auth: RawTransactionArgument<string>,
        forceAccredited: RawTransactionArgument<boolean>,
        forceUsAccredited: RawTransactionArgument<boolean>,
        version: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/**
 * Create a new AccreditedOnly rule
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
    const parameterNames = ["auth", "forceAccredited", "forceUsAccredited", "version"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'accredited_only',
        function: 'new',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface SetForceAccreditedArguments {
    auth: RawTransactionArgument<string>;
    wrapper: RawTransactionArgument<string>;
    force: RawTransactionArgument<boolean>;
    version: RawTransactionArgument<string>;
}
export interface SetForceAccreditedOptions {
    package?: string;
    arguments: SetForceAccreditedArguments | [
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
 * Set global accreditation requirement
 *
 * # Aborts
 *
 * - `ENotAuthorized` - If caller lacks ManageRules ability
 */
export function setForceAccredited(options: SetForceAccreditedOptions) {
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
        module: 'accredited_only',
        function: 'set_force_accredited',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface SetForceUsAccreditedArguments {
    auth: RawTransactionArgument<string>;
    wrapper: RawTransactionArgument<string>;
    force: RawTransactionArgument<boolean>;
    version: RawTransactionArgument<string>;
}
export interface SetForceUsAccreditedOptions {
    package?: string;
    arguments: SetForceUsAccreditedArguments | [
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
 * Set US accreditation requirement
 *
 * # Aborts
 *
 * - `ENotAuthorized` - If caller lacks ManageRules ability
 */
export function setForceUsAccredited(options: SetForceUsAccreditedOptions) {
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
        module: 'accredited_only',
        function: 'set_force_us_accredited',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface ValidateRuleArguments {
    rule: RawTransactionArgument<string>;
    region: RawTransactionArgument<number | bigint>;
    isAccredited: RawTransactionArgument<boolean>;
}
export interface ValidateRuleOptions {
    package?: string;
    arguments: ValidateRuleArguments | [
        rule: RawTransactionArgument<string>,
        region: RawTransactionArgument<number | bigint>,
        isAccredited: RawTransactionArgument<boolean>
    ];
}
/**
 * Validate that investor is accredited based on rule configuration.
 *
 * # Aborts
 *
 * - `ENotAccredited` - If global accreditation is required and investor is not
 *   accredited
 * - `ENotUSAccredited` - If US accreditation is required, investor is in US, and
 *   not accredited
 */
export function validateRule(options: ValidateRuleOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        'u64',
        'bool'
    ] satisfies (string | null)[];
    const parameterNames = ["rule", "region", "isAccredited"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'accredited_only',
        function: 'validate_rule',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface IsForceAccreditedArguments {
    rule: RawTransactionArgument<string>;
}
export interface IsForceAccreditedOptions {
    package?: string;
    arguments: IsForceAccreditedArguments | [
        rule: RawTransactionArgument<string>
    ];
}
/** Check if global accreditation is required */
export function isForceAccredited(options: IsForceAccreditedOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["rule"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'accredited_only',
        function: 'is_force_accredited',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface IsForceUsAccreditedArguments {
    rule: RawTransactionArgument<string>;
}
export interface IsForceUsAccreditedOptions {
    package?: string;
    arguments: IsForceUsAccreditedArguments | [
        rule: RawTransactionArgument<string>
    ];
}
/** Check if US accreditation is required */
export function isForceUsAccredited(options: IsForceUsAccreditedOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["rule"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'accredited_only',
        function: 'is_force_us_accredited',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}