// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/**
 * Base error class for PAS client errors
 */
export class PASClientError extends Error {
	constructor(message: string) {
		super(message);
		this.name = 'PASClientError';
	}
}

export class VaultNotFoundError extends PASClientError {
	constructor(address: string) {
		super(`Vault not found for address ${address}.`);
		this.name = 'VaultNotFoundError';
	}
}

export class RuleNotFoundError extends PASClientError {
	constructor(assetType: string, message?: string) {
		super(message ?? `Rule not found for asset type ${assetType}.`);
		this.name = 'RuleNotFoundError';
	}
}
