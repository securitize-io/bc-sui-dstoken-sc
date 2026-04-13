/**************************************************************
 * THIS FILE IS GENERATED AND SHOULD NOT BE MANUALLY MODIFIED *
 **************************************************************/


/**
 * Module: authorized_securities
 * 
 * Rule that validates issuance against a maximum authorized securities limit. This
 * ensures the total supply never exceeds the authorized amount, maintaining
 * compliance with regulatory requirements for authorized offerings.
 * 
 * When max_supply is 0, the check is disabled unlimited issuance allowed.
 */

import { MoveStruct, normalizeMoveArguments, type RawTransactionArgument } from '../utils/index.js';
import { bcs } from '@mysten/sui/bcs';
import { type Transaction } from '@mysten/sui/transactions';
const $moduleName = '@securitize/securitize::authorized_securities';
export const AuthorizedSecurities = new MoveStruct({ name: `${$moduleName}::AuthorizedSecurities`, fields: {
        max_supply: bcs.u64()
    } });
export interface NewArguments {
    auth: RawTransactionArgument<string>;
    maxSupply: RawTransactionArgument<number | bigint>;
    version: RawTransactionArgument<string>;
}
export interface NewOptions {
    package?: string;
    arguments: NewArguments | [
        auth: RawTransactionArgument<string>,
        maxSupply: RawTransactionArgument<number | bigint>,
        version: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/**
 * Create a new AuthorizedSecurities rule Starts with max_supply of 0 (unlimited)
 *
 * # Aborts
 *
 * - `ENotAuthorized` - If caller lacks ManageRules ability
 */
export function _new(options: NewOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        'u64',
        null
    ] satisfies (string | null)[];
    const parameterNames = ["auth", "maxSupply", "version"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'authorized_securities',
        function: 'new',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface SetMaxSupplyArguments {
    auth: RawTransactionArgument<string>;
    wrapper: RawTransactionArgument<string>;
    maxSupply: RawTransactionArgument<number | bigint>;
    version: RawTransactionArgument<string>;
}
export interface SetMaxSupplyOptions {
    package?: string;
    arguments: SetMaxSupplyArguments | [
        auth: RawTransactionArgument<string>,
        wrapper: RawTransactionArgument<string>,
        maxSupply: RawTransactionArgument<number | bigint>,
        version: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/**
 * Set the maximum authorized securities (max supply)
 *
 * # Aborts
 *
 * - `ENotAuthorized` - If caller lacks RegisterRule ability
 */
export function setMaxSupply(options: SetMaxSupplyOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        null,
        'u64',
        null
    ] satisfies (string | null)[];
    const parameterNames = ["auth", "wrapper", "maxSupply", "version"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'authorized_securities',
        function: 'set_max_supply',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface ValidateRuleArguments {
    rule: RawTransactionArgument<string>;
    totalSupply: RawTransactionArgument<number | bigint>;
    issuanceValue: RawTransactionArgument<number | bigint>;
}
export interface ValidateRuleOptions {
    package?: string;
    arguments: ValidateRuleArguments | [
        rule: RawTransactionArgument<string>,
        totalSupply: RawTransactionArgument<number | bigint>,
        issuanceValue: RawTransactionArgument<number | bigint>
    ];
}
/**
 * Validate that issuance does not exceed max authorized securities.
 *
 * # Aborts
 *
 * - `EMaxAuthorizedSecuritiesExceeded` - If total supply plus issuance exceeds
 *   max_supply
 */
export function validateRule(options: ValidateRuleOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        'u64',
        'u64'
    ] satisfies (string | null)[];
    const parameterNames = ["rule", "totalSupply", "issuanceValue"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'authorized_securities',
        function: 'validate_rule',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface MaxSupplyArguments {
    rule: RawTransactionArgument<string>;
}
export interface MaxSupplyOptions {
    package?: string;
    arguments: MaxSupplyArguments | [
        rule: RawTransactionArgument<string>
    ];
}
/** Get the max authorized securities limit */
export function maxSupply(options: MaxSupplyOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["rule"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'authorized_securities',
        function: 'max_supply',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface IsEnforcedArguments {
    rule: RawTransactionArgument<string>;
}
export interface IsEnforcedOptions {
    package?: string;
    arguments: IsEnforcedArguments | [
        rule: RawTransactionArgument<string>
    ];
}
/** Check if the limit is enforced (max_supply > 0) */
export function isEnforced(options: IsEnforcedOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["rule"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'authorized_securities',
        function: 'is_enforced',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}