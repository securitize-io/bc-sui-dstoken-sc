/**************************************************************
 * THIS FILE IS GENERATED AND SHOULD NOT BE MANUALLY MODIFIED *
 **************************************************************/

/** Vault logic */

import { bcs } from '@mysten/sui/bcs';
import { type Transaction } from '@mysten/sui/transactions';

import {
	MoveStruct,
	MoveTuple,
	normalizeMoveArguments,
	type RawTransactionArgument,
} from '../utils/index.js';

const $moduleName = '@mysten/pas::vault';
export const Vault = new MoveStruct({
	name: `${$moduleName}::Vault`,
	fields: {
		id: bcs.Address,
		/** The owner of the vault (address or object) */
		owner: bcs.Address,
		/**
		 * The ID of the namespace that created this vault. There's ONLY ONE namespace in
		 * the system, but this helps us avoid having `&Namespace` inputs in all functions
		 * that need to derive the IDs.
		 */
		namespace_id: bcs.Address,
	},
});
export const Auth = new MoveTuple({ name: `${$moduleName}::Auth`, fields: [bcs.Address] });
export interface CreateArguments {
	namespace: RawTransactionArgument<string>;
	owner: RawTransactionArgument<string>;
}
export interface CreateOptions {
	package?: string;
	arguments:
		| CreateArguments
		| [namespace: RawTransactionArgument<string>, owner: RawTransactionArgument<string>];
}
/** Create a new vault for `owner`. This is a permission-less action. */
export function create(options: CreateOptions) {
	const packageAddress = options.package ?? '@mysten/pas';
	const argumentsTypes = [null, 'address'] satisfies (string | null)[];
	const parameterNames = ['namespace', 'owner'];
	return (tx: Transaction) =>
		tx.moveCall({
			package: packageAddress,
			module: 'vault',
			function: 'create',
			arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
		});
}
export interface ShareArguments {
	vault: RawTransactionArgument<string>;
}
export interface ShareOptions {
	package?: string;
	arguments: ShareArguments | [vault: RawTransactionArgument<string>];
}
/**
 * The only way to finalize the TX is by sharing the vault. All vaults are shared
 * by default.
 */
export function share(options: ShareOptions) {
	const packageAddress = options.package ?? '@mysten/pas';
	const argumentsTypes = [null] satisfies (string | null)[];
	const parameterNames = ['vault'];
	return (tx: Transaction) =>
		tx.moveCall({
			package: packageAddress,
			module: 'vault',
			function: 'share',
			arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
		});
}
export interface CreateAndShareArguments {
	namespace: RawTransactionArgument<string>;
	owner: RawTransactionArgument<string>;
}
export interface CreateAndShareOptions {
	package?: string;
	arguments:
		| CreateAndShareArguments
		| [namespace: RawTransactionArgument<string>, owner: RawTransactionArgument<string>];
}
/** Create and share a vault in a single step. */
export function createAndShare(options: CreateAndShareOptions) {
	const packageAddress = options.package ?? '@mysten/pas';
	const argumentsTypes = [null, 'address'] satisfies (string | null)[];
	const parameterNames = ['namespace', 'owner'];
	return (tx: Transaction) =>
		tx.moveCall({
			package: packageAddress,
			module: 'vault',
			function: 'create_and_share',
			arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
		});
}
export interface UnlockFundsArguments {
	vault: RawTransactionArgument<string>;
	auth: RawTransactionArgument<string>;
	amount: RawTransactionArgument<number | bigint>;
}
export interface UnlockFundsOptions {
	package?: string;
	arguments:
		| UnlockFundsArguments
		| [
				vault: RawTransactionArgument<string>,
				auth: RawTransactionArgument<string>,
				amount: RawTransactionArgument<number | bigint>,
		  ];
	typeArguments: [string];
}
/**
 * Enables a fund unlock flow. This is useful for assets that are not managed by a
 * Rule within the system, or if there's a special case where an issuer allows
 * balances to flow out of the system.
 */
export function unlockFunds(options: UnlockFundsOptions) {
	const packageAddress = options.package ?? '@mysten/pas';
	const argumentsTypes = [null, null, 'u64'] satisfies (string | null)[];
	const parameterNames = ['vault', 'auth', 'amount'];
	return (tx: Transaction) =>
		tx.moveCall({
			package: packageAddress,
			module: 'vault',
			function: 'unlock_funds',
			arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
			typeArguments: options.typeArguments,
		});
}
export interface TransferFundsArguments {
	from: RawTransactionArgument<string>;
	auth: RawTransactionArgument<string>;
	to: RawTransactionArgument<string>;
	amount: RawTransactionArgument<number | bigint>;
}
export interface TransferFundsOptions {
	package?: string;
	arguments:
		| TransferFundsArguments
		| [
				from: RawTransactionArgument<string>,
				auth: RawTransactionArgument<string>,
				to: RawTransactionArgument<string>,
				amount: RawTransactionArgument<number | bigint>,
		  ];
	typeArguments: [string];
}
/** Initiate a transfer from vault A to vault B. */
export function transferFunds(options: TransferFundsOptions) {
	const packageAddress = options.package ?? '@mysten/pas';
	const argumentsTypes = [null, null, null, 'u64'] satisfies (string | null)[];
	const parameterNames = ['from', 'auth', 'to', 'amount'];
	return (tx: Transaction) =>
		tx.moveCall({
			package: packageAddress,
			module: 'vault',
			function: 'transfer_funds',
			arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
			typeArguments: options.typeArguments,
		});
}
export interface UnsafeTransferFundsArguments {
	from: RawTransactionArgument<string>;
	auth: RawTransactionArgument<string>;
	recipientAddress: RawTransactionArgument<string>;
	amount: RawTransactionArgument<number | bigint>;
}
export interface UnsafeTransferFundsOptions {
	package?: string;
	arguments:
		| UnsafeTransferFundsArguments
		| [
				from: RawTransactionArgument<string>,
				auth: RawTransactionArgument<string>,
				recipientAddress: RawTransactionArgument<string>,
				amount: RawTransactionArgument<number | bigint>,
		  ];
	typeArguments: [string];
}
/**
 * Transfer `amount` from vault to an address. This unlocks transfers to a vault
 * before it has been created.
 *
 * It's marked as `unsafe_` as it's easy to accidentally pick the wrong recipient
 * address.
 */
export function unsafeTransferFunds(options: UnsafeTransferFundsOptions) {
	const packageAddress = options.package ?? '@mysten/pas';
	const argumentsTypes = [null, null, 'address', 'u64'] satisfies (string | null)[];
	const parameterNames = ['from', 'auth', 'recipientAddress', 'amount'];
	return (tx: Transaction) =>
		tx.moveCall({
			package: packageAddress,
			module: 'vault',
			function: 'unsafe_transfer_funds',
			arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
			typeArguments: options.typeArguments,
		});
}
export interface NewAuthOptions {
	package?: string;
	arguments?: [];
}
/** Generate an ownership proof from the sender of the transaction. */
export function newAuth(options: NewAuthOptions = {}) {
	const packageAddress = options.package ?? '@mysten/pas';
	return (tx: Transaction) =>
		tx.moveCall({
			package: packageAddress,
			module: 'vault',
			function: 'new_auth',
		});
}
export interface NewAuthAsObjectArguments {
	uid: RawTransactionArgument<string>;
}
export interface NewAuthAsObjectOptions {
	package?: string;
	arguments: NewAuthAsObjectArguments | [uid: RawTransactionArgument<string>];
}
/** Generate an ownership proof from a `UID` object, to allow objects to own vaults. */
export function newAuthAsObject(options: NewAuthAsObjectOptions) {
	const packageAddress = options.package ?? '@mysten/pas';
	const argumentsTypes = ['0x2::object::ID'] satisfies (string | null)[];
	const parameterNames = ['uid'];
	return (tx: Transaction) =>
		tx.moveCall({
			package: packageAddress,
			module: 'vault',
			function: 'new_auth_as_object',
			arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
		});
}
export interface OwnerArguments {
	vault: RawTransactionArgument<string>;
}
export interface OwnerOptions {
	package?: string;
	arguments: OwnerArguments | [vault: RawTransactionArgument<string>];
}
export function owner(options: OwnerOptions) {
	const packageAddress = options.package ?? '@mysten/pas';
	const argumentsTypes = [null] satisfies (string | null)[];
	const parameterNames = ['vault'];
	return (tx: Transaction) =>
		tx.moveCall({
			package: packageAddress,
			module: 'vault',
			function: 'owner',
			arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
		});
}
export interface DepositFundsArguments {
	vault: RawTransactionArgument<string>;
	balance: RawTransactionArgument<string>;
}
export interface DepositFundsOptions {
	package?: string;
	arguments:
		| DepositFundsArguments
		| [vault: RawTransactionArgument<string>, balance: RawTransactionArgument<string>];
	typeArguments: [string];
}
export function depositFunds(options: DepositFundsOptions) {
	const packageAddress = options.package ?? '@mysten/pas';
	const argumentsTypes = [null, null] satisfies (string | null)[];
	const parameterNames = ['vault', 'balance'];
	return (tx: Transaction) =>
		tx.moveCall({
			package: packageAddress,
			module: 'vault',
			function: 'deposit_funds',
			arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
			typeArguments: options.typeArguments,
		});
}
