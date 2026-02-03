/**************************************************************
 * THIS FILE IS GENERATED AND SHOULD NOT BE MANUALLY MODIFIED *
 **************************************************************/
import { bcs } from '@mysten/sui/bcs';
import { type Transaction } from '@mysten/sui/transactions';

import { MoveStruct, normalizeMoveArguments, type RawTransactionArgument } from '../utils/index.js';
import * as balance from './deps/sui/balance.js';

const $moduleName = '@mysten/pas::transfer_funds_request';
export const TransferFundsRequest = new MoveStruct({
	name: `${$moduleName}::TransferFundsRequest`,
	fields: {
		/** `sender` is the wallet OR object address, NOT the vault address */
		sender: bcs.Address,
		/** `recipient` is the wallet OR object address, NOT the vault address */
		recipient: bcs.Address,
		/** The ID of the vault the funds are coming from */
		sender_vault_id: bcs.Address,
		/** The ID of the vault the funds are going to */
		recipient_vault_id: bcs.Address,
		/** The amount being transferred (original) */
		amount: bcs.u64(),
		/** The actual balance being transferred */
		balance: balance.Balance,
	},
});
export interface SenderArguments {
	request: RawTransactionArgument<string>;
}
export interface SenderOptions {
	package?: string;
	arguments: SenderArguments | [request: RawTransactionArgument<string>];
	typeArguments: [string];
}
export function sender(options: SenderOptions) {
	const packageAddress = options.package ?? '@mysten/pas';
	const argumentsTypes = [null] satisfies (string | null)[];
	const parameterNames = ['request'];
	return (tx: Transaction) =>
		tx.moveCall({
			package: packageAddress,
			module: 'transfer_funds_request',
			function: 'sender',
			arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
			typeArguments: options.typeArguments,
		});
}
export interface RecipientArguments {
	request: RawTransactionArgument<string>;
}
export interface RecipientOptions {
	package?: string;
	arguments: RecipientArguments | [request: RawTransactionArgument<string>];
	typeArguments: [string];
}
export function recipient(options: RecipientOptions) {
	const packageAddress = options.package ?? '@mysten/pas';
	const argumentsTypes = [null] satisfies (string | null)[];
	const parameterNames = ['request'];
	return (tx: Transaction) =>
		tx.moveCall({
			package: packageAddress,
			module: 'transfer_funds_request',
			function: 'recipient',
			arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
			typeArguments: options.typeArguments,
		});
}
export interface SenderVaultIdArguments {
	request: RawTransactionArgument<string>;
}
export interface SenderVaultIdOptions {
	package?: string;
	arguments: SenderVaultIdArguments | [request: RawTransactionArgument<string>];
	typeArguments: [string];
}
export function senderVaultId(options: SenderVaultIdOptions) {
	const packageAddress = options.package ?? '@mysten/pas';
	const argumentsTypes = [null] satisfies (string | null)[];
	const parameterNames = ['request'];
	return (tx: Transaction) =>
		tx.moveCall({
			package: packageAddress,
			module: 'transfer_funds_request',
			function: 'sender_vault_id',
			arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
			typeArguments: options.typeArguments,
		});
}
export interface RecipientVaultIdArguments {
	request: RawTransactionArgument<string>;
}
export interface RecipientVaultIdOptions {
	package?: string;
	arguments: RecipientVaultIdArguments | [request: RawTransactionArgument<string>];
	typeArguments: [string];
}
export function recipientVaultId(options: RecipientVaultIdOptions) {
	const packageAddress = options.package ?? '@mysten/pas';
	const argumentsTypes = [null] satisfies (string | null)[];
	const parameterNames = ['request'];
	return (tx: Transaction) =>
		tx.moveCall({
			package: packageAddress,
			module: 'transfer_funds_request',
			function: 'recipient_vault_id',
			arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
			typeArguments: options.typeArguments,
		});
}
export interface AmountArguments {
	request: RawTransactionArgument<string>;
}
export interface AmountOptions {
	package?: string;
	arguments: AmountArguments | [request: RawTransactionArgument<string>];
	typeArguments: [string];
}
export function amount(options: AmountOptions) {
	const packageAddress = options.package ?? '@mysten/pas';
	const argumentsTypes = [null] satisfies (string | null)[];
	const parameterNames = ['request'];
	return (tx: Transaction) =>
		tx.moveCall({
			package: packageAddress,
			module: 'transfer_funds_request',
			function: 'amount',
			arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
			typeArguments: options.typeArguments,
		});
}
