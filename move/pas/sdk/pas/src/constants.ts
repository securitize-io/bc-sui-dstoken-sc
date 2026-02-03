// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

import type { PASPackageConfig } from './types.js';

export const TESTNET_PAS_PACKAGE_CONFIG: PASPackageConfig = {
	packageId: '0x0', // TODO: Replace with actual testnet package ID
	namespaceId: '0x0', // TODO: Replace with actual testnet namespace ID
};

export const MAINNET_PAS_PACKAGE_CONFIG: PASPackageConfig = {
	packageId: '0x0', // TODO: Replace with actual mainnet package ID
	namespaceId: '0x0', // TODO: Replace with actual mainnet namespace ID
};

// TODO: Remove devnet when going live with the client.
export const DEVNET_PAS_PACKAGE_CONFIG: PASPackageConfig = {
	packageId: '0x8edb029482f90e4160db01841f8b51bf1602df8f83728c5af596522b30836595',
	namespaceId: '0xc79061241d77af9907bd0c7c4163f864c1a5deaaadb3526502df5fb9963e1423',
};
