/**************************************************************
 * THIS FILE IS GENERATED AND SHOULD NOT BE MANUALLY MODIFIED *
 **************************************************************/


/**
 * Module: compliance_service
 * 
 * Core compliance engine that validates all token transfers against registered
 * rules. Manages compliance rules configuration, country-level restrictions, and
 * coordinates with the registry service to enforce transfer policies.
 */

import { MoveTuple, MoveStruct, normalizeMoveArguments, type RawTransactionArgument } from '../utils/index.js';
import { bcs } from '@mysten/sui/bcs';
import { type Transaction } from '@mysten/sui/transactions';
import * as bag from './deps/sui/bag.js';
import * as type_name from './deps/std/type_name.js';
const $moduleName = '@securitize/securitize::compliance_service';
export const ComplianceServiceKey = new MoveTuple({ name: `${$moduleName}::ComplianceServiceKey<phantom T>`, fields: [bcs.bool()] });
export const ComplianceConfig = new MoveStruct({ name: `${$moduleName}::ComplianceConfig<phantom T>`, fields: {
        id: bcs.Address,
        /** Type names -> rule objects */
        rules_bag: bag.Bag,
        /** Set of rules for the asset T */
        rules: bcs.vector(type_name.TypeName)
    } });
export const TransferInfo = new MoveStruct({ name: `${$moduleName}::TransferInfo`, fields: {
        amount: bcs.u64(),
        equal_country: bcs.bool(),
        equal_region: bcs.bool(),
        timestamp_ms: bcs.u64()
    } });
export const IssuanceInfo = new MoveStruct({ name: `${$moduleName}::IssuanceInfo`, fields: {
        amount: bcs.u64(),
        total_supply: bcs.u64(),
        timestamp_ms: bcs.u64()
    } });
export const PartyInfo = new MoveStruct({ name: `${$moduleName}::PartyInfo`, fields: {
        addr: bcs.Address,
        investor_id: bcs.option(bcs.string()),
        country: bcs.string(),
        region: bcs.u64(),
        balance: bcs.u64(),
        transferable_balance: bcs.u64(),
        is_accredited: bcs.bool(),
        is_qualified: bcs.bool(),
        is_exit_investor: bcs.bool(),
        is_new_investor: bcs.bool(),
        is_special_wallet: bcs.bool()
    } });
export interface RegisterRuleArguments {
    self: RawTransactionArgument<string>;
    auth: RawTransactionArgument<string>;
    wrapper: RawTransactionArgument<string>;
    version: RawTransactionArgument<string>;
}
export interface RegisterRuleOptions {
    package?: string;
    arguments: RegisterRuleArguments | [
        self: RawTransactionArgument<string>,
        auth: RawTransactionArgument<string>,
        wrapper: RawTransactionArgument<string>,
        version: RawTransactionArgument<string>
    ];
    typeArguments: [
        string,
        string
    ];
}
/**
 * Register a new rule to type `T`. Adds the rule object to the rules bag and
 * registers its type.
 *
 * # Aborts
 *
 * - `ENotAuthorized` - If caller lacks RegisterRule ability
 * - `ERuleAlreadyExists` - If the rule type is already registered
 */
export function registerRule(options: RegisterRuleOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        null,
        null,
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self", "auth", "wrapper", "version"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'compliance_service',
        function: 'register_rule',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface UnregisterRuleArguments {
    self: RawTransactionArgument<string>;
    auth: RawTransactionArgument<string>;
    version: RawTransactionArgument<string>;
}
export interface UnregisterRuleOptions {
    package?: string;
    arguments: UnregisterRuleArguments | [
        self: RawTransactionArgument<string>,
        auth: RawTransactionArgument<string>,
        version: RawTransactionArgument<string>
    ];
    typeArguments: [
        string,
        string
    ];
}
/**
 * Unregister a rule from type `T`. Removes the rule object from the rules bag and
 * unregisters its type.
 *
 * # Aborts
 *
 * - `ENotAuthorized` - If caller lacks UnregisterRule ability
 * - `ERuleNotFound` - If the rule type is not registered
 */
export function unregisterRule(options: UnregisterRuleOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        null,
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self", "auth", "version"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'compliance_service',
        function: 'unregister_rule',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface HasRuleArguments {
    config: RawTransactionArgument<string>;
}
export interface HasRuleOptions {
    package?: string;
    arguments: HasRuleArguments | [
        config: RawTransactionArgument<string>
    ];
    typeArguments: [
        string,
        string
    ];
}
/** Check if a specific rule type is registered */
export function hasRule(options: HasRuleOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["config"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'compliance_service',
        function: 'has_rule',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface GetRuleArguments {
    self: RawTransactionArgument<string>;
    auth: RawTransactionArgument<string>;
    version: RawTransactionArgument<string>;
}
export interface GetRuleOptions {
    package?: string;
    arguments: GetRuleArguments | [
        self: RawTransactionArgument<string>,
        auth: RawTransactionArgument<string>,
        version: RawTransactionArgument<string>
    ];
    typeArguments: [
        string,
        string
    ];
}
/**
 * Get a rule configuration wrapped in a hot potato. The rule is removed from the
 * bag and must be returned via `return_rule`.
 *
 * # Aborts
 *
 * - `ENotAuthorized` - If caller lacks ManageRules ability
 */
export function getRule(options: GetRuleOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        null,
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self", "auth", "version"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'compliance_service',
        function: 'get_rule',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface ReturnRuleArguments {
    self: RawTransactionArgument<string>;
    auth: RawTransactionArgument<string>;
    wrapper: RawTransactionArgument<string>;
    version: RawTransactionArgument<string>;
}
export interface ReturnRuleOptions {
    package?: string;
    arguments: ReturnRuleArguments | [
        self: RawTransactionArgument<string>,
        auth: RawTransactionArgument<string>,
        wrapper: RawTransactionArgument<string>,
        version: RawTransactionArgument<string>
    ];
    typeArguments: [
        string,
        string
    ];
}
/**
 * Return a rule back to the compliance config. Consumes the hot potato wrapper and
 * adds the rule back to the bag.
 *
 * # Aborts
 *
 * - `ENotAuthorized` - If caller lacks ManageRules ability
 */
export function returnRule(options: ReturnRuleOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        null,
        null,
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self", "auth", "wrapper", "version"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'compliance_service',
        function: 'return_rule',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface BorrowRuleArguments {
    self: RawTransactionArgument<string>;
}
export interface BorrowRuleOptions {
    package?: string;
    arguments: BorrowRuleArguments | [
        self: RawTransactionArgument<string>
    ];
    typeArguments: [
        string,
        string
    ];
}
/**
 * Borrow an immutable reference to a rule configuration. Use this for read-only
 * access to rule state.
 */
export function borrowRule(options: BorrowRuleOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'compliance_service',
        function: 'borrow_rule',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface RulesVectorArguments {
    self: RawTransactionArgument<string>;
}
export interface RulesVectorOptions {
    package?: string;
    arguments: RulesVectorArguments | [
        self: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/** Get immutable reference to the rules vector */
export function rulesVector(options: RulesVectorOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'compliance_service',
        function: 'rules_vector',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface SetCountryComplianceArguments {
    registry: RawTransactionArgument<string>;
    country: RawTransactionArgument<string>;
    complianceRegion: RawTransactionArgument<number | bigint>;
    auth: RawTransactionArgument<string>;
    version: RawTransactionArgument<string>;
}
export interface SetCountryComplianceOptions {
    package?: string;
    arguments: SetCountryComplianceArguments | [
        registry: RawTransactionArgument<string>,
        country: RawTransactionArgument<string>,
        complianceRegion: RawTransactionArgument<number | bigint>,
        auth: RawTransactionArgument<string>,
        version: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/**
 * Set compliance region for a country.
 *
 * # Aborts
 *
 * - `ENotAuthorized` - If caller lacks SetCountryCompliance ability
 */
export function setCountryCompliance(options: SetCountryComplianceOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        '0x1::string::String',
        'u64',
        null,
        null
    ] satisfies (string | null)[];
    const parameterNames = ["registry", "country", "complianceRegion", "auth", "version"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'compliance_service',
        function: 'set_country_compliance',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface GetCountryComplianceArguments {
    registry: RawTransactionArgument<string>;
    country: RawTransactionArgument<string>;
}
export interface GetCountryComplianceOptions {
    package?: string;
    arguments: GetCountryComplianceArguments | [
        registry: RawTransactionArgument<string>,
        country: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/** Get compliance region for a country */
export function getCountryCompliance(options: GetCountryComplianceOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        '0x1::string::String'
    ] satisfies (string | null)[];
    const parameterNames = ["registry", "country"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'compliance_service',
        function: 'get_country_compliance',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}