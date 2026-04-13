/**************************************************************
 * THIS FILE IS GENERATED AND SHOULD NOT BE MANUALLY MODIFIED *
 **************************************************************/


/**
 * Module: version
 * 
 * Manages package versioning to ensure users interact with the latest contract
 * version. Provides version validation and migration support for package upgrades.
 */

import { MoveStruct, normalizeMoveArguments, type RawTransactionArgument } from '../utils/index.js';
import { bcs } from '@mysten/sui/bcs';
import { type Transaction } from '@mysten/sui/transactions';
const $moduleName = '@securitize/securitize::version';
export const Version = new MoveStruct({ name: `${$moduleName}::Version`, fields: {
        id: bcs.Address,
        version: bcs.u64()
    } });
export interface CheckIsValidArguments {
    self: RawTransactionArgument<string>;
}
export interface CheckIsValidOptions {
    package?: string;
    arguments: CheckIsValidArguments | [
        self: RawTransactionArgument<string>
    ];
}
/**
 * Function checking that the package-version matches the `Version` object.
 *
 * # Aborts
 *
 * - `EInvalidPackageVersion` - If the package version does not match the Version
 *   object
 */
export function checkIsValid(options: CheckIsValidOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'version',
        function: 'check_is_valid',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}