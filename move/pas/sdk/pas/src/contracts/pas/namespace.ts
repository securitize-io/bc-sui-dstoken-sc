/**************************************************************
 * THIS FILE IS GENERATED AND SHOULD NOT BE MANUALLY MODIFIED *
 **************************************************************/

/**
 * The Namespace module.
 *
 * Namespace is responsible for creating objects that are easy to query & find:
 *
 * 1.  Vaults
 * 2.  Rules ... any other module we might add in the future
 */

import { bcs } from '@mysten/sui/bcs';
import { type Transaction } from '@mysten/sui/transactions';

import { MoveStruct, normalizeMoveArguments, type RawTransactionArgument } from '../utils/index.js';

const $moduleName = '@mysten/pas::namespace';
export const Namespace = new MoveStruct({
	name: `${$moduleName}::Namespace`,
	fields: {
		id: bcs.Address,
	},
});
export interface RuleExistsArguments {
	namespace: RawTransactionArgument<string>;
}
export interface RuleExistsOptions {
	package?: string;
	arguments: RuleExistsArguments | [namespace: RawTransactionArgument<string>];
	typeArguments: [string];
}
/** Check if `Rule<T>` exists in the namespace */
export function ruleExists(options: RuleExistsOptions) {
	const packageAddress = options.package ?? '@mysten/pas';
	const argumentsTypes = [null] satisfies (string | null)[];
	const parameterNames = ['namespace'];
	return (tx: Transaction) =>
		tx.moveCall({
			package: packageAddress,
			module: 'namespace',
			function: 'rule_exists',
			arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
			typeArguments: options.typeArguments,
		});
}
export interface RuleAddressArguments {
	namespace: RawTransactionArgument<string>;
}
export interface RuleAddressOptions {
	package?: string;
	arguments: RuleAddressArguments | [namespace: RawTransactionArgument<string>];
	typeArguments: [string];
}
/** The derived address for `Rule<T>` */
export function ruleAddress(options: RuleAddressOptions) {
	const packageAddress = options.package ?? '@mysten/pas';
	const argumentsTypes = [null] satisfies (string | null)[];
	const parameterNames = ['namespace'];
	return (tx: Transaction) =>
		tx.moveCall({
			package: packageAddress,
			module: 'namespace',
			function: 'rule_address',
			arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
			typeArguments: options.typeArguments,
		});
}
export interface VaultExistsArguments {
	namespace: RawTransactionArgument<string>;
	owner: RawTransactionArgument<string>;
}
export interface VaultExistsOptions {
	package?: string;
	arguments:
		| VaultExistsArguments
		| [namespace: RawTransactionArgument<string>, owner: RawTransactionArgument<string>];
}
export function vaultExists(options: VaultExistsOptions) {
	const packageAddress = options.package ?? '@mysten/pas';
	const argumentsTypes = [null, 'address'] satisfies (string | null)[];
	const parameterNames = ['namespace', 'owner'];
	return (tx: Transaction) =>
		tx.moveCall({
			package: packageAddress,
			module: 'namespace',
			function: 'vault_exists',
			arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
		});
}
export interface VaultAddressArguments {
	namespace: RawTransactionArgument<string>;
	owner: RawTransactionArgument<string>;
}
export interface VaultAddressOptions {
	package?: string;
	arguments:
		| VaultAddressArguments
		| [namespace: RawTransactionArgument<string>, owner: RawTransactionArgument<string>];
}
export function vaultAddress(options: VaultAddressOptions) {
	const packageAddress = options.package ?? '@mysten/pas';
	const argumentsTypes = [null, 'address'] satisfies (string | null)[];
	const parameterNames = ['namespace', 'owner'];
	return (tx: Transaction) =>
		tx.moveCall({
			package: packageAddress,
			module: 'namespace',
			function: 'vault_address',
			arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
		});
}
