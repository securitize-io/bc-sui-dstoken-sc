/**************************************************************
 * THIS FILE IS GENERATED AND SHOULD NOT BE MANUALLY MODIFIED *
 **************************************************************/


/**
 * Module: trust_service
 * 
 * This is the main module for role management. The core structure here is Auth as
 * an independent shared object. three main administrative roles: Master, Issuer,
 * and TransferAgent.
 */

import { MoveTuple, MoveStruct, normalizeMoveArguments, type RawTransactionArgument } from '../utils/index.js';
import { bcs } from '@mysten/sui/bcs';
import { type Transaction } from '@mysten/sui/transactions';
import * as vec_map from './deps/sui/vec_map.js';
import * as type_name from './deps/std/type_name.js';
import * as vec_map_1 from './deps/sui/vec_map.js';
import * as type_name_1 from './deps/std/type_name.js';
import * as vec_set from './deps/sui/vec_set.js';
import * as type_name_2 from './deps/std/type_name.js';
import * as bag from './deps/sui/bag.js';
const $moduleName = '@securitize/securitize::trust_service';
export const TrustServiceKey = new MoveTuple({ name: `${$moduleName}::TrustServiceKey<phantom T>`, fields: [bcs.bool()] });
export const Auth = new MoveStruct({ name: `${$moduleName}::Auth<phantom T>`, fields: {
        id: bcs.Address,
        roles: vec_map.VecMap(type_name.TypeName, bcs.u32()),
        /** Abilities are witness types mapped per role */
        roles_abilities: vec_map_1.VecMap(type_name_1.TypeName, vec_set.VecSet(type_name_2.TypeName)),
        /** Role keys registry (Bag of AddressKey structs) */
        roles_owners: bag.Bag
    } });
export const AddressKey = new MoveStruct({ name: `${$moduleName}::AddressKey`, fields: {
        owner: bcs.Address
    } });
export const Master = new MoveStruct({ name: `${$moduleName}::Master`, fields: {
        dummy_field: bcs.bool()
    } });
export const Issuer = new MoveStruct({ name: `${$moduleName}::Issuer`, fields: {
        dummy_field: bcs.bool()
    } });
export const TransferAgent = new MoveStruct({ name: `${$moduleName}::TransferAgent`, fields: {
        dummy_field: bcs.bool()
    } });
export const Exchange = new MoveStruct({ name: `${$moduleName}::Exchange`, fields: {
        dummy_field: bcs.bool()
    } });
export const None = new MoveStruct({ name: `${$moduleName}::None`, fields: {
        dummy_field: bcs.bool()
    } });
export interface GetRoleArguments {
    self: RawTransactionArgument<string>;
    owner: RawTransactionArgument<string>;
}
export interface GetRoleOptions {
    package?: string;
    arguments: GetRoleArguments | [
        self: RawTransactionArgument<string>,
        owner: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/**
 * Returns the role TypeName for the given address. If no role is assigned, returns
 * the TypeName of `None`.
 */
export function getRole(options: GetRoleOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        'address'
    ] satisfies (string | null)[];
    const parameterNames = ["self", "owner"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'trust_service',
        function: 'get_role',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface SetExchangeArguments {
    self: RawTransactionArgument<string>;
    owner: RawTransactionArgument<string>;
    version: RawTransactionArgument<string>;
}
export interface SetExchangeOptions {
    package?: string;
    arguments: SetExchangeArguments | [
        self: RawTransactionArgument<string>,
        owner: RawTransactionArgument<string>,
        version: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/**
 * Set/grant a role Exchange to an owner address. Creates an AddressKey and stores
 * it in the roles Bag.
 *
 * # Aborts
 *
 * - `ENotEnoughPermissions` - If the sender does not have the SetExchange ability
 */
export function setExchange(options: SetExchangeOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        'address',
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self", "owner", "version"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'trust_service',
        function: 'set_exchange',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface RemoveExchangeArguments {
    self: RawTransactionArgument<string>;
    owner: RawTransactionArgument<string>;
    version: RawTransactionArgument<string>;
}
export interface RemoveExchangeOptions {
    package?: string;
    arguments: RemoveExchangeArguments | [
        self: RawTransactionArgument<string>,
        owner: RawTransactionArgument<string>,
        version: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/**
 * Remove a role Exchange from an owner address.
 *
 * # Aborts
 *
 * - `ENotEnoughPermissions` - If the sender does not have the SetExchange ability
 */
export function removeExchange(options: RemoveExchangeOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        'address',
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self", "owner", "version"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'trust_service',
        function: 'remove_exchange',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface SetTransferAgentArguments {
    self: RawTransactionArgument<string>;
    owner: RawTransactionArgument<string>;
    version: RawTransactionArgument<string>;
}
export interface SetTransferAgentOptions {
    package?: string;
    arguments: SetTransferAgentArguments | [
        self: RawTransactionArgument<string>,
        owner: RawTransactionArgument<string>,
        version: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/**
 * Set/grant a role TransferAgent to an owner address. Creates an AddressKey and
 * stores it in the roles Bag.
 *
 * # Aborts
 *
 * - `ENotEnoughPermissions` - If the sender does not have the SetTransferAgent
 *   ability
 */
export function setTransferAgent(options: SetTransferAgentOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        'address',
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self", "owner", "version"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'trust_service',
        function: 'set_transfer_agent',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface RemoveTransferAgentArguments {
    self: RawTransactionArgument<string>;
    owner: RawTransactionArgument<string>;
    version: RawTransactionArgument<string>;
}
export interface RemoveTransferAgentOptions {
    package?: string;
    arguments: RemoveTransferAgentArguments | [
        self: RawTransactionArgument<string>,
        owner: RawTransactionArgument<string>,
        version: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/**
 * Remove a role TransferAgent from an owner address.
 *
 * # Aborts
 *
 * - `ENotEnoughPermissions` - If the sender does not have the SetTransferAgent
 *   ability
 */
export function removeTransferAgent(options: RemoveTransferAgentOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        'address',
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self", "owner", "version"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'trust_service',
        function: 'remove_transfer_agent',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface SetIssuerArguments {
    self: RawTransactionArgument<string>;
    owner: RawTransactionArgument<string>;
    version: RawTransactionArgument<string>;
}
export interface SetIssuerOptions {
    package?: string;
    arguments: SetIssuerArguments | [
        self: RawTransactionArgument<string>,
        owner: RawTransactionArgument<string>,
        version: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/**
 * Set/grant a role Issuer to an owner address. Creates an AddressKey and stores it
 * in the roles Bag.
 *
 * # Aborts
 *
 * - `ENotEnoughPermissions` - If the sender does not have the SetIssuer ability
 */
export function setIssuer(options: SetIssuerOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        'address',
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self", "owner", "version"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'trust_service',
        function: 'set_issuer',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface RemoveIssuerArguments {
    self: RawTransactionArgument<string>;
    owner: RawTransactionArgument<string>;
    version: RawTransactionArgument<string>;
}
export interface RemoveIssuerOptions {
    package?: string;
    arguments: RemoveIssuerArguments | [
        self: RawTransactionArgument<string>,
        owner: RawTransactionArgument<string>,
        version: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/**
 * Remove a role Issuer from an owner address.
 *
 * # Aborts
 *
 * - `ENotEnoughPermissions` - If the sender does not have the SetIssuer ability
 */
export function removeIssuer(options: RemoveIssuerOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        'address',
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self", "owner", "version"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'trust_service',
        function: 'remove_issuer',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface SetServiceOwnerArguments {
    self: RawTransactionArgument<string>;
    owner: RawTransactionArgument<string>;
    version: RawTransactionArgument<string>;
}
export interface SetServiceOwnerOptions {
    package?: string;
    arguments: SetServiceOwnerArguments | [
        self: RawTransactionArgument<string>,
        owner: RawTransactionArgument<string>,
        version: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/**
 * Set/transfer service ownership (reassigns Master role).
 *
 * # Aborts
 *
 * - `ESelfTransferNotAllowed` - If attempting to transfer ownership to self
 * - `ENotEnoughPermissions` - If the sender does not have the SetServiceOwner
 *   ability
 */
export function setServiceOwner(options: SetServiceOwnerOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        'address',
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self", "owner", "version"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'trust_service',
        function: 'set_service_owner',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface AddRoleAbilityArguments {
    self: RawTransactionArgument<string>;
    version: RawTransactionArgument<string>;
}
export interface AddRoleAbilityOptions {
    package?: string;
    arguments: AddRoleAbilityArguments | [
        self: RawTransactionArgument<string>,
        version: RawTransactionArgument<string>
    ];
    typeArguments: [
        string,
        string,
        string
    ];
}
/**
 * Add an ability A to role R. This grants all holders of role R the ability to
 * perform actions requiring A.
 *
 * # Aborts
 *
 * - `ENotEnoughPermissions` - If the sender does not have the SetAbilities ability
 * - `EAbilityReservedForMaster` - If ability A is SetServiceOwner and R is not
 *   Master
 * - `ERoleNotFound` - If the role type R is not registered
 * - `ERoleAbilitiesNotFound` - If the role's abilities mapping is not found
 * - `EAbilityAlreadyExists` - If the ability A is already assigned to role R
 */
export function addRoleAbility(options: AddRoleAbilityOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self", "version"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'trust_service',
        function: 'add_role_ability',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface RemoveRoleAbilityArguments {
    self: RawTransactionArgument<string>;
    version: RawTransactionArgument<string>;
}
export interface RemoveRoleAbilityOptions {
    package?: string;
    arguments: RemoveRoleAbilityArguments | [
        self: RawTransactionArgument<string>,
        version: RawTransactionArgument<string>
    ];
    typeArguments: [
        string,
        string,
        string
    ];
}
/**
 * Remove an ability A from role R. This revokes the ability to perform actions
 * requiring A from all holders of role R.
 *
 * # Aborts
 *
 * - `ENotEnoughPermissions` - If the sender does not have the SetAbilities ability
 * - `ECannotRemoveMaster` - If attempting to remove SetAbilities from Master role
 * - `ERoleNotFound` - If the role type R is not registered
 * - `ERoleAbilitiesNotFound` - If the role's abilities mapping is not found
 * - `EAbilityNotFound` - If the ability A is not found for role R
 */
export function removeRoleAbility(options: RemoveRoleAbilityOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self", "version"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'trust_service',
        function: 'remove_role_ability',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface AddRoleTypeArguments {
    self: RawTransactionArgument<string>;
    version: RawTransactionArgument<string>;
}
export interface AddRoleTypeOptions {
    package?: string;
    arguments: AddRoleTypeArguments | [
        self: RawTransactionArgument<string>,
        version: RawTransactionArgument<string>
    ];
    typeArguments: [
        string,
        string,
        string
    ];
}
/**
 * Add a new role type R to the system. When a new role is added, Master
 * automatically gets the ability to set it.
 *
 * # Aborts
 *
 * - `ENotEnoughPermissions` - If the sender does not have the SetRoleTypes ability
 * - `ERoleAlreadyExists` - If the role type R already exists
 */
export function addRoleType(options: AddRoleTypeOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self", "version"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'trust_service',
        function: 'add_role_type',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface RemoveRoleTypeArguments {
    self: RawTransactionArgument<string>;
    version: RawTransactionArgument<string>;
}
export interface RemoveRoleTypeOptions {
    package?: string;
    arguments: RemoveRoleTypeArguments | [
        self: RawTransactionArgument<string>,
        version: RawTransactionArgument<string>
    ];
    typeArguments: [
        string,
        string
    ];
}
/**
 * Remove a role type R from the system. Can only remove if no addresses currently
 * have this role (counter == 0). Also cleans up the role's ability set.
 *
 * # Aborts
 *
 * - `ENotEnoughPermissions` - If the sender does not have the SetRoleTypes ability
 * - `ECannotRemoveMaster` - If attempting to remove the Master role
 * - `ERoleNotFound` - If the role type R is not registered
 * - `ERoleHasActiveMembers` - If the role has active members (counter > 0)
 * - `ERoleAbilitiesNotFound` - If the role's abilities mapping is not found
 */
export function removeRoleType(options: RemoveRoleTypeOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        null
    ] satisfies (string | null)[];
    const parameterNames = ["self", "version"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'trust_service',
        function: 'remove_role_type',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}