/**************************************************************
 * THIS FILE IS GENERATED AND SHOULD NOT BE MANUALLY MODIFIED *
 **************************************************************/


/**
 * Module: setup
 * 
 * Handles the initialization and deployment of new DS Token instances. Manages
 * authorized deployers and provides the entry point for creating new security
 * tokens with their associated services.
 */

import { MoveStruct, normalizeMoveArguments, type RawTransactionArgument } from '../utils/index.js';
import { bcs } from '@mysten/sui/bcs';
import { type Transaction } from '@mysten/sui/transactions';
import * as vec_set from './deps/sui/vec_set.js';
const $moduleName = '@securitize/securitize::setup';
export const SetupRegistry = new MoveStruct({ name: `${$moduleName}::SetupRegistry`, fields: {
        id: bcs.Address,
        /** Set of addresses authorized to deploy tokens */
        deployers: vec_set.VecSet(bcs.Address),
        /** Admin address with permission to add/remove deployers */
        admin: bcs.Address
    } });
export const SetupFinalize = new MoveStruct({ name: `${$moduleName}::SetupFinalize`, fields: {
        dummy_field: bcs.bool()
    } });
export interface SetupArguments {
    setupRegistry: RawTransactionArgument<string>;
    namespace: RawTransactionArgument<string>;
    treasuryCap: RawTransactionArgument<string>;
    metadataCap: RawTransactionArgument<string>;
    version: RawTransactionArgument<string>;
}
export interface SetupOptions {
    package?: string;
    arguments: SetupArguments | [
        setupRegistry: RawTransactionArgument<string>,
        namespace: RawTransactionArgument<string>,
        treasuryCap: RawTransactionArgument<string>,
        metadataCap: RawTransactionArgument<string>,
        version: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/**
 * Sets up a new securitized token system for the given coin type T. This function
 * validates that the caller is an authorized deployer and initializes the
 * treasury, investor registry, and compliance modules for the token.
 *
 * # Aborts
 *
 * - `ENotDeployer` - If the caller is not in the authorized deployers list
 * - `ENonZeroSupply` - If the TreasuryCap already has a non-zero supply
 */
export function setup(options: SetupOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        null,
        null,
        null,
        null
    ] satisfies (string | null)[];
    const parameterNames = ["setupRegistry", "namespace", "treasuryCap", "metadataCap", "version"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'setup',
        function: 'setup',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface FinalizeSetupArguments {
    finalize: RawTransactionArgument<string>;
    auth: RawTransactionArgument<string>;
    treasury: RawTransactionArgument<string>;
    investorInfo: RawTransactionArgument<string>;
    compliance: RawTransactionArgument<string>;
    version: RawTransactionArgument<string>;
}
export interface FinalizeSetupOptions {
    package?: string;
    arguments: FinalizeSetupArguments | [
        finalize: RawTransactionArgument<string>,
        auth: RawTransactionArgument<string>,
        treasury: RawTransactionArgument<string>,
        investorInfo: RawTransactionArgument<string>,
        compliance: RawTransactionArgument<string>,
        version: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/**
 * Finalizes the setup process by sharing the Auth, Treasury, InvestorInfo and
 * ComplianceConfig objects, and by resolving the SetupFinalize hot potato.
 */
export function finalizeSetup(options: FinalizeSetupOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        null,
        null,
        null,
        null,
        null
    ] satisfies (string | null)[];
    const parameterNames = ["finalize", "auth", "treasury", "investorInfo", "compliance", "version"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'setup',
        function: 'finalize_setup',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface AddDeployerArguments {
    registry: RawTransactionArgument<string>;
    deployer: RawTransactionArgument<string>;
    version: RawTransactionArgument<string>;
}
export interface AddDeployerOptions {
    package?: string;
    arguments: AddDeployerArguments | [
        registry: RawTransactionArgument<string>,
        deployer: RawTransactionArgument<string>,
        version: RawTransactionArgument<string>
    ];
}
/**
 * Adds a new address to the list of authorized deployers. Only the admin can call
 * this function.
 *
 * # Aborts
 *
 * - `ENotAdmin` - If the caller is not the admin
 */
export function addDeployer(options: AddDeployerOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        'address',
        null
    ] satisfies (string | null)[];
    const parameterNames = ["registry", "deployer", "version"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'setup',
        function: 'add_deployer',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface RemoveDeployerArguments {
    registry: RawTransactionArgument<string>;
    deployer: RawTransactionArgument<string>;
    version: RawTransactionArgument<string>;
}
export interface RemoveDeployerOptions {
    package?: string;
    arguments: RemoveDeployerArguments | [
        registry: RawTransactionArgument<string>,
        deployer: RawTransactionArgument<string>,
        version: RawTransactionArgument<string>
    ];
}
/**
 * Removes an address from the list of authorized deployers. Only the admin can
 * call this function.
 *
 * # Aborts
 *
 * - `ENotAdmin` - If the caller is not the admin
 */
export function removeDeployer(options: RemoveDeployerOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        'address',
        null
    ] satisfies (string | null)[];
    const parameterNames = ["registry", "deployer", "version"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'setup',
        function: 'remove_deployer',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface SwitchAdminArguments {
    registry: RawTransactionArgument<string>;
    newAdmin: RawTransactionArgument<string>;
    version: RawTransactionArgument<string>;
}
export interface SwitchAdminOptions {
    package?: string;
    arguments: SwitchAdminArguments | [
        registry: RawTransactionArgument<string>,
        newAdmin: RawTransactionArgument<string>,
        version: RawTransactionArgument<string>
    ];
}
/**
 * Switches the admin to a new address. Only the current admin can call this
 * function.
 *
 * # Aborts
 *
 * - `ENotAdmin` - If the caller is not the admin
 */
export function switchAdmin(options: SwitchAdminOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        'address',
        null
    ] satisfies (string | null)[];
    const parameterNames = ["registry", "newAdmin", "version"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'setup',
        function: 'switch_admin',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface MigrateVersionArguments {
    registry: RawTransactionArgument<string>;
    version: RawTransactionArgument<string>;
}
export interface MigrateVersionOptions {
    package?: string;
    arguments: MigrateVersionArguments | [
        registry: RawTransactionArgument<string>,
        version: RawTransactionArgument<string>
    ];
}
/**
 * Migrates the version object to the latest package version. Only the admin can
 * call this.
 *
 * # Aborts
 *
 * - `ENotAdmin` - If the caller is not the admin
 */
export function migrateVersion(options: MigrateVersionOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        null
    ] satisfies (string | null)[];
    const parameterNames = ["registry", "version"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'setup',
        function: 'migrate_version',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface IsDeployerArguments {
    registry: RawTransactionArgument<string>;
    addr: RawTransactionArgument<string>;
}
export interface IsDeployerOptions {
    package?: string;
    arguments: IsDeployerArguments | [
        registry: RawTransactionArgument<string>,
        addr: RawTransactionArgument<string>
    ];
}
/** Checks if the given address is an authorized deployer. */
export function isDeployer(options: IsDeployerOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        'address'
    ] satisfies (string | null)[];
    const parameterNames = ["registry", "addr"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'setup',
        function: 'is_deployer',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface AdminArguments {
    registry: RawTransactionArgument<string>;
}
export interface AdminOptions {
    package?: string;
    arguments: AdminArguments | [
        registry: RawTransactionArgument<string>
    ];
}
export function admin(options: AdminOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["registry"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'setup',
        function: 'admin',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}