// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

import { bcs } from '@mysten/sui/bcs';
import { SuiClientTypes } from '@mysten/sui/client';
import { type Transaction, type TransactionObjectArgument } from '@mysten/sui/transactions';
import { normalizeStructTag } from '@mysten/sui/utils';

import { Field, VecMap } from './bcs.js';
import { ResolutionInfo } from './contracts/pas/rule.js';
import { Command, MoveCall } from './contracts/ptb/ptb.js';
import { PASClientError } from './error.js';
import type { PASPackageConfig } from './types.js';

const OBJECT_BY_ID_EXT = 'object_by_id';
const OBJECT_BY_TYPE_EXT = 'object_by_type';
const RECEIVING_BY_ID_EXT = 'receiving_by_id';

/**
 * Supported PAS action types that can be resolved via Rules.
 */
export enum PASActionType {
	/** Transfer funds between vaults */
	TransferFunds = 'TransferFunds',
	/** Unlock funds from a vault */
	UnlockFunds = 'UnlockFunds',
}

/**
 * Builds the full typename for a PAS action.
 *
 * @param actionType - The action type (TransferFunds or UnlockFunds)
 * @param assetType - The asset type (e.g., "0x2::sui::SUI")
 * @param packageConfig - PAS package configuration
 * @returns The full typename (e.g., "0x123::transfer_funds_request::TransferFundsRequest<0x2::sui::SUI>")
 */
export function buildActionTypeName(
	actionType: PASActionType,
	assetType: string,
	packageConfig: PASPackageConfig,
): string {
	const { packageId } = packageConfig;

	switch (actionType) {
		case PASActionType.TransferFunds:
			return `${packageId}::transfer_funds_request::TransferFundsRequest<${assetType}>`;
		case PASActionType.UnlockFunds:
			return `${packageId}::unlock_funds_request::UnlockFundsRequest<${assetType}>`;
		default:
			throw new PASClientError(`Unknown action type: ${actionType}`);
	}
}

/**
 * Resolves a Command from a Rule's resolution_info map.
 *
 * The resolution_info is a VecMap<TypeName, Command> where:
 * - TypeName is the action type (e.g., "0x123::transfer_funds_request::TransferFundsRequest<0x2::sui::SUI>")
 * - Command is the move call instruction to execute for that action
 *
 * @param rule - The parsed Rule object
 * @param actionType - The full typename of the action (e.g., "0x123::transfer_funds_request::TransferFundsRequest<0x2::sui::SUI>")
 * @returns The Command object for this action type, or undefined if not found
 */
export function getCommandForAction(
	object: SuiClientTypes.Object<{ content: true }>,
	actionType: string,
): ReturnType<typeof parseCommand> | undefined {
	// Parse the Dynamic Field.
	const df = Field(ResolutionInfo, VecMap(bcs.String, Command)).parse(object.content);
	// The resolution_info is a VecMap<TypeName, Command>
	// VecMap has a 'contents' field which is an array of { key: TypeName, value: Command }
	const resolutionMap = df.value;

	// The resolution map stored in the DF is `VecMap<String, Command>`
	const command = resolutionMap.contents.find(
		(entry) =>
			normalizeStructTag(entry.key).toString() === normalizeStructTag(actionType).toString(),
	);

	return command?.value ? parseCommand(command.value) : undefined;
}

// TODO: Discuss why this is interpreted as `(number | number[])[])` instead of `[number, number[]]`
// and if there's a way to solve that.
export function parseCommand([key, cmd]: ReturnType<typeof Command.parse>) {
	// Support only `Command` for now.
	if (key !== 0) throw new Error(`Unknown command type: ${key}`);

	// TODO: switch to support more commands like `TransferObjects` etc.
	return MoveCall.parse(new Uint8Array(cmd as number[]));
}

/**
 * Context provided when building a PTB from a command
 */
export interface CommandBuildContext {
	/** The transaction builder */
	tx: Transaction;
	/** The sender vault (for transfers/unlocks) */
	senderVault?: TransactionObjectArgument;
	/** The receiver vault (for transfers) */
	receiverVault?: TransactionObjectArgument;
	/** The rule object */
	rule?: TransactionObjectArgument;
	/** The transfer/unlock request */
	request?: TransactionObjectArgument;
	/** The system type T (e.g., "0x2::sui::SUI") */
	systemType?: string;
	/** Additional custom arguments */
	customArgs?: Map<string, TransactionObjectArgument>;
}

/**
 * Adds the `tx.moveCall()` as it is resolved from `Command`.
 *
 * This function translates the Command structure into actual moveCall operations
 * in the transaction, resolving placeholders like "sender_vault", "receiver_vault", etc.
 *
 * @param command - The parsed Command object
 * @param context - The build context with required objects
 * @returns The result of the moveCall
 */
export function addMoveCallFromCommand(
	command: ReturnType<typeof parseCommand>,
	context: CommandBuildContext,
) {
	const { tx } = context;

	// Resolve arguments
	const resolvedArgs: TransactionObjectArgument[] = [];

	for (const arg of command.arguments) {
		if (arg.Ext) throw new PASClientError(`There are no supported ext arguments in this client.`);
		else if (arg.GasCoin) resolvedArgs.push(tx.gas);
		else if (arg.NestedResult)
			resolvedArgs.push({
				$kind: 'NestedResult',
				NestedResult: [arg.NestedResult[0], arg.NestedResult[1]],
			});
		else if (arg.Result) resolvedArgs.push({ $kind: 'Result', Result: arg.Result });
		else if (arg.Input) {
			if (arg.Input.Pure) resolvedArgs.push(tx.pure(new Uint8Array(arg.Input.Pure)));
			else if (arg.Input.Object) {
				switch (arg.Input.Object.$kind) {
					case 'ImmOrOwnedObject':
						resolvedArgs.push(
							tx.objectRef({
								objectId: arg.Input.Object.ImmOrOwnedObject.object_id,
								version: arg.Input.Object.ImmOrOwnedObject.sequence_number,
								digest: arg.Input.Object.ImmOrOwnedObject.digest,
							}),
						);
						break;
					case 'SharedObject':
						resolvedArgs.push(
							tx.sharedObjectRef({
								objectId: arg.Input.Object.SharedObject.object_id,
								initialSharedVersion: arg.Input.Object.SharedObject.initial_shared_version,
								mutable: arg.Input.Object.SharedObject.is_mutable,
							}),
						);
						break;
					case 'Receiving':
						resolvedArgs.push(
							tx.receivingRef({
								objectId: arg.Input.Object.Receiving.object_id,
								version: arg.Input.Object.Receiving.sequence_number,
								digest: arg.Input.Object.Receiving.digest,
							}),
						);
						break;
					case 'Ext':
						const [kind, value] = arg.Input.Object.Ext.split(':');

						switch (kind) {
							case OBJECT_BY_ID_EXT:
							case RECEIVING_BY_ID_EXT:
								resolvedArgs.push(tx.object(value));
								break;
							case OBJECT_BY_TYPE_EXT:
								throw new PASClientError(
									`There are no supported object by type arguments in this client.`,
								);
							default:
								throw new PASClientError(`Unknown external object argument: ${kind}`);
						}
						break;
					default:
						throw new PASClientError(
							`Not supported object argument: ${JSON.stringify(arg.Input.Object)}`,
						);
				}
			} else if (arg.Input.Ext) {
				resolvedArgs.push(resolvePasRequest(context, arg.Input.Ext));
			} else {
				throw new PASClientError(`Unsupported input kind: ${arg.Input.$kind}`);
			}
		}
	}

	// Resolve type arguments
	const typeArgs: string[] = [];
	for (const typeArg of command.type_arguments)
		typeArgs.push(normalizeStructTag(typeArg).toString());

	// Build the moveCall
	if (!command.module_name || !command.function)
		throw new PASClientError(
			'Module name or function name is missing from the on-chain rule. This means that the issuer has not set up the rule correctly.',
		);

	return tx.moveCall({
		target: `${command.package_id}::${command.module_name}::${command.function}`,
		arguments: resolvedArgs,
		typeArguments: typeArgs.length > 0 ? typeArgs : [],
	});
}

/// Handle the special resolvers for PAS.
/// This includes the `rul`, the `request`, the `sender_vault` as well as the `receiver_vault`.
function resolvePasRequest(context: CommandBuildContext, value: string) {
	switch (value) {
		case 'pas:request':
			if (!context.request) throw new PASClientError(`Request is not set in the context.`);
			return context.request;
		case 'pas:rule':
			if (!context.rule) throw new PASClientError(`Rule is not set in the context.`);
			return context.rule;
		case 'pas:sender_vault':
			if (!context.senderVault) throw new PASClientError(`Sender vault is not set in the context.`);
			return context.senderVault;
		case 'pas:receiver_vault':
			if (!context.receiverVault)
				throw new PASClientError(`Receiver vault is not set in the context.`);
			return context.receiverVault;
		default:
			throw new PASClientError(`Unknown pas request: ${value}`);
	}
}
