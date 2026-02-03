// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

import { bcs } from '@mysten/sui/bcs';
import { deriveObjectID, normalizeSuiAddress } from '@mysten/sui/utils';

import type { PASPackageConfig } from './types.js';

/**
 * Derives the vault address for a given owner address.
 *
 * Vaults are derived using the namespace UID and a VaultKey(owner).
 * The key structure in Move is: `VaultKey(address)`
 *
 * @param owner - The owner address (can be a user address or object address)
 * @param packageConfig - PAS package configuration
 * @returns The derived vault object ID
 */
export function deriveVaultAddress(owner: string, packageConfig: PASPackageConfig): string {
	const { packageId, namespaceId } = packageConfig;

	// Serialize the VaultKey(address) as the key
	// VaultKey is a struct with a single field: address
	const vaultKeyBcs = bcs.struct('VaultKey', {
		owner: bcs.Address,
	});

	const key = vaultKeyBcs.serialize({ owner: normalizeSuiAddress(owner) }).toBytes();

	// The type tag is the VaultKey type from the PAS package
	const typeTag = `${packageId}::keys::VaultKey`;

	return deriveObjectID(namespaceId, typeTag, key);
}

/**
 * Derives the rule address for a given asset type T.
 *
 * Rules are derived using the namespace UID and a RuleKey<T>().
 * The key structure in Move is: `RuleKey<phantom T>()`
 *
 * @param assetType - The full type of the asset (e.g., "0x2::sui::SUI")
 * @param packageConfig - PAS package configuration
 * @returns The derived rule object ID
 */
export function deriveRuleAddress(assetType: string, packageConfig: PASPackageConfig): string {
	const { packageId, namespaceId } = packageConfig;

	// RuleKey<T> is a phantom type with no fields, so the serialized key is empty
	// In BCS, an empty struct is serialized as 0 bytes
	const ruleKeyBcs = new Uint8Array([0]);

	// The type tag includes the asset type as a generic parameter
	const typeTag = `${packageId}::keys::RuleKey<${assetType}>`;
	return deriveObjectID(namespaceId, typeTag, ruleKeyBcs);
}
