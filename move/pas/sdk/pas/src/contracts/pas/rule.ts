/**************************************************************
 * THIS FILE IS GENERATED AND SHOULD NOT BE MANUALLY MODIFIED *
 **************************************************************/
import { bcs, type BcsType } from '@mysten/sui/bcs';
import { type Transaction } from '@mysten/sui/transactions';

import {
	MoveStruct,
	MoveTuple,
	normalizeMoveArguments,
	type RawTransactionArgument,
} from '../utils/index.js';
import * as type_name from './deps/std/type_name.js';

const $moduleName = '@mysten/pas::rule';
export const Rule = new MoveStruct({
	name: `${$moduleName}::Rule`,
	fields: {
		id: bcs.Address,
		/**
		 * The typename used to prove that the "smart contract" agrees with an action for a
		 * given `T`. Initially, this only means it approves "transfers", "clawbacks" and
		 * "mints (managed scenario)". In the future, there might be NFT version of these
		 * rules.
		 */
		auth_witness: type_name.TypeName,
	},
});
export const ResolutionInfo = new MoveTuple({
	name: `${$moduleName}::ResolutionInfo`,
	fields: [bcs.bool()],
});
export const FundsClawbackState = new MoveTuple({
	name: `${$moduleName}::FundsClawbackState`,
	fields: [bcs.bool()],
});
export interface NewArguments<U extends BcsType<any>> {
	namespace: RawTransactionArgument<string>;
	_: RawTransactionArgument<string>;
	Stamp: RawTransactionArgument<U>;
}
export interface NewOptions<U extends BcsType<any>> {
	package?: string;
	arguments:
		| NewArguments<U>
		| [
				namespace: RawTransactionArgument<string>,
				_: RawTransactionArgument<string>,
				Stamp: RawTransactionArgument<U>,
		  ];
	typeArguments: [string, string];
}
/**
 * Create a new `Rule` for `T`. We use `Permit<T>` as the proof of ownership for
 * `T`.
 */
export function _new<U extends BcsType<any>>(options: NewOptions<U>) {
	const packageAddress = options.package ?? '@mysten/pas';
	const argumentsTypes = [null, null, `${options.typeArguments[1]}`] satisfies (string | null)[];
	const parameterNames = ['namespace', '_', 'Stamp'];
	return (tx: Transaction) =>
		tx.moveCall({
			package: packageAddress,
			module: 'rule',
			function: 'new',
			arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
			typeArguments: options.typeArguments,
		});
}
export interface ShareArguments {
	rule: RawTransactionArgument<string>;
}
export interface ShareOptions {
	package?: string;
	arguments: ShareArguments | [rule: RawTransactionArgument<string>];
	typeArguments: [string];
}
export function share(options: ShareOptions) {
	const packageAddress = options.package ?? '@mysten/pas';
	const argumentsTypes = [null] satisfies (string | null)[];
	const parameterNames = ['rule'];
	return (tx: Transaction) =>
		tx.moveCall({
			package: packageAddress,
			module: 'rule',
			function: 'share',
			arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
			typeArguments: options.typeArguments,
		});
}
export interface EnableFundsManagementArguments {
	rule: RawTransactionArgument<string>;
	_: RawTransactionArgument<string>;
	clawbackAllowed: RawTransactionArgument<boolean>;
}
export interface EnableFundsManagementOptions {
	package?: string;
	arguments:
		| EnableFundsManagementArguments
		| [
				rule: RawTransactionArgument<string>,
				_: RawTransactionArgument<string>,
				clawbackAllowed: RawTransactionArgument<boolean>,
		  ];
	typeArguments: [string];
}
/**
 * Enables funds management for a given `T`, adding a DF that tracks the clawback
 * status (true/false). This can only be called once. After calling it, the
 * clawback status can never change!
 */
export function enableFundsManagement(options: EnableFundsManagementOptions) {
	const packageAddress = options.package ?? '@mysten/pas';
	const argumentsTypes = [null, null, 'bool'] satisfies (string | null)[];
	const parameterNames = ['rule', '_', 'clawbackAllowed'];
	return (tx: Transaction) =>
		tx.moveCall({
			package: packageAddress,
			module: 'rule',
			function: 'enable_funds_management',
			arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
			typeArguments: options.typeArguments,
		});
}
export interface ResolveUnlockFundsArguments<U extends BcsType<any>> {
	rule: RawTransactionArgument<string>;
	request: RawTransactionArgument<string>;
	Stamp: RawTransactionArgument<U>;
}
export interface ResolveUnlockFundsOptions<U extends BcsType<any>> {
	package?: string;
	arguments:
		| ResolveUnlockFundsArguments<U>
		| [
				rule: RawTransactionArgument<string>,
				request: RawTransactionArgument<string>,
				Stamp: RawTransactionArgument<U>,
		  ];
	typeArguments: [string, string];
}
/**
 * Resolve an unlock funds request by verifying the authorization witness and
 * finalizing the unlock.
 */
export function resolveUnlockFunds<U extends BcsType<any>>(options: ResolveUnlockFundsOptions<U>) {
	const packageAddress = options.package ?? '@mysten/pas';
	const argumentsTypes = [null, null, `${options.typeArguments[1]}`] satisfies (string | null)[];
	const parameterNames = ['rule', 'request', 'Stamp'];
	return (tx: Transaction) =>
		tx.moveCall({
			package: packageAddress,
			module: 'rule',
			function: 'resolve_unlock_funds',
			arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
			typeArguments: options.typeArguments,
		});
}
export interface ResolveTransferFundsArguments<U extends BcsType<any>> {
	rule: RawTransactionArgument<string>;
	request: RawTransactionArgument<string>;
	Stamp: RawTransactionArgument<U>;
}
export interface ResolveTransferFundsOptions<U extends BcsType<any>> {
	package?: string;
	arguments:
		| ResolveTransferFundsArguments<U>
		| [
				rule: RawTransactionArgument<string>,
				request: RawTransactionArgument<string>,
				Stamp: RawTransactionArgument<U>,
		  ];
	typeArguments: [string, string];
}
/**
 * Resolve a transfer request by verifying the authorization witness and finalizing
 * the transfer. Aborts with `EInvalidProof` if the witness does not match the
 * rule's authorization witness.
 */
export function resolveTransferFunds<U extends BcsType<any>>(
	options: ResolveTransferFundsOptions<U>,
) {
	const packageAddress = options.package ?? '@mysten/pas';
	const argumentsTypes = [null, null, `${options.typeArguments[1]}`] satisfies (string | null)[];
	const parameterNames = ['rule', 'request', 'Stamp'];
	return (tx: Transaction) =>
		tx.moveCall({
			package: packageAddress,
			module: 'rule',
			function: 'resolve_transfer_funds',
			arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
			typeArguments: options.typeArguments,
		});
}
export interface ClawbackFundsArguments<U extends BcsType<any>> {
	rule: RawTransactionArgument<string>;
	from: RawTransactionArgument<string>;
	amount: RawTransactionArgument<number | bigint>;
	Stamp: RawTransactionArgument<U>;
}
export interface ClawbackFundsOptions<U extends BcsType<any>> {
	package?: string;
	arguments:
		| ClawbackFundsArguments<U>
		| [
				rule: RawTransactionArgument<string>,
				from: RawTransactionArgument<string>,
				amount: RawTransactionArgument<number | bigint>,
				Stamp: RawTransactionArgument<U>,
		  ];
	typeArguments: [string, string];
}
/**
 * Clawbacks `amount` of balance from a Vault, returning `Balance<T>` by value.
 *
 * WARNING: This does not guarantee that the funds will not go out of the
 * controlled system. Use with caution.
 */
export function clawbackFunds<U extends BcsType<any>>(options: ClawbackFundsOptions<U>) {
	const packageAddress = options.package ?? '@mysten/pas';
	const argumentsTypes = [null, null, 'u64', `${options.typeArguments[1]}`] satisfies (
		| string
		| null
	)[];
	const parameterNames = ['rule', 'from', 'amount', 'Stamp'];
	return (tx: Transaction) =>
		tx.moveCall({
			package: packageAddress,
			module: 'rule',
			function: 'clawback_funds',
			arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
			typeArguments: options.typeArguments,
		});
}
export interface IsFundClawbackAllowedArguments {
	rule: RawTransactionArgument<string>;
}
export interface IsFundClawbackAllowedOptions {
	package?: string;
	arguments: IsFundClawbackAllowedArguments | [rule: RawTransactionArgument<string>];
	typeArguments: [string];
}
/**
 * Check if clawback is allowed or not. Aborts early if the management for funds
 * has not been enabled for `T`.
 */
export function isFundClawbackAllowed(options: IsFundClawbackAllowedOptions) {
	const packageAddress = options.package ?? '@mysten/pas';
	const argumentsTypes = [null] satisfies (string | null)[];
	const parameterNames = ['rule'];
	return (tx: Transaction) =>
		tx.moveCall({
			package: packageAddress,
			module: 'rule',
			function: 'is_fund_clawback_allowed',
			arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
			typeArguments: options.typeArguments,
		});
}
export interface SetActionCommandArguments<U extends BcsType<any>> {
	rule: RawTransactionArgument<string>;
	command: RawTransactionArgument<string>;
	Stamp: RawTransactionArgument<U>;
}
export interface SetActionCommandOptions<U extends BcsType<any>> {
	package?: string;
	arguments:
		| SetActionCommandArguments<U>
		| [
				rule: RawTransactionArgument<string>,
				command: RawTransactionArgument<string>,
				Stamp: RawTransactionArgument<U>,
		  ];
	typeArguments: [string, string, string];
}
/**
 * Set the move command for a specific action type. NOTE: If the action type
 * already exists, it will be replaced.
 */
export function setActionCommand<U extends BcsType<any>>(options: SetActionCommandOptions<U>) {
	const packageAddress = options.package ?? '@mysten/pas';
	const argumentsTypes = [null, null, `${options.typeArguments[1]}`] satisfies (string | null)[];
	const parameterNames = ['rule', 'command', 'Stamp'];
	return (tx: Transaction) =>
		tx.moveCall({
			package: packageAddress,
			module: 'rule',
			function: 'set_action_command',
			arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
			typeArguments: options.typeArguments,
		});
}
export interface AuthWitnessArguments {
	rule: RawTransactionArgument<string>;
}
export interface AuthWitnessOptions {
	package?: string;
	arguments: AuthWitnessArguments | [rule: RawTransactionArgument<string>];
	typeArguments: [string];
}
export function authWitness(options: AuthWitnessOptions) {
	const packageAddress = options.package ?? '@mysten/pas';
	const argumentsTypes = [null] satisfies (string | null)[];
	const parameterNames = ['rule'];
	return (tx: Transaction) =>
		tx.moveCall({
			package: packageAddress,
			module: 'rule',
			function: 'auth_witness',
			arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
			typeArguments: options.typeArguments,
		});
}
