// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

import { describe, expect, it } from 'vitest';

import { deriveRuleAddress, deriveVaultAddress } from '../../src/derivation.js';
import type { PASPackageConfig } from '../../src/types.js';

describe('PAS Object Derivation', () => {
	const packageConfig: PASPackageConfig = {
		packageId: '0x123',
		namespaceId: '0xabc',
	};

	describe('deriveVaultAddress', () => {
		it('should derive vault address for owner 0x456', () => {
			const vaultId = deriveVaultAddress('0x456', packageConfig);
			expect(vaultId).toMatchInlineSnapshot(
				`"0x8712c77726f5c0927363764d6fd6ec64fb03becb51228bfcb2017442b6c30b62"`,
			);
		});

		it('should derive vault address for owner 0x789', () => {
			const vaultId = deriveVaultAddress('0x789', packageConfig);
			expect(vaultId).toMatchInlineSnapshot(
				`"0x36379f73c885824bd00cf8e441464aa7a3ccd0624c1c34fd526ed7db1f83a116"`,
			);
		});

		it('should derive vault address for different namespace', () => {
			const config = { ...packageConfig, namespaceId: '0xdef' };
			const vaultId = deriveVaultAddress('0x456', config);
			expect(vaultId).toMatchInlineSnapshot(
				`"0xa378d4ccc977bbb997618a32c4bbe8cc55a67551870f2574626fd624e1b3cfb7"`,
			);
		});

		it('should normalize addresses correctly', () => {
			const vaultId1 = deriveVaultAddress('0x1', packageConfig);
			const vaultId2 = deriveVaultAddress(
				'0x0000000000000000000000000000000000000000000000000000000000000001',
				packageConfig,
			);

			expect(vaultId1).toBe(vaultId2);
			expect(vaultId1).toMatchInlineSnapshot(
				`"0xe5dd472028385358d7727a799555e42f43858c7621a84473e0f5384cda737ed6"`,
			);
		});

		it('should derive vault for object owner', () => {
			const vaultId = deriveVaultAddress(
				'0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
				packageConfig,
			);
			expect(vaultId).toMatchInlineSnapshot(
				`"0xf29869e74858befbd65b5b03338d0b1f4855bb7eeb6b37b5559879f461930114"`,
			);
		});
	});

	describe('deriveRuleAddress', () => {
		it('should derive rule address for SUI', () => {
			const ruleId = deriveRuleAddress('0x2::sui::SUI', packageConfig);
			expect(ruleId).toMatchInlineSnapshot(
				`"0xa9b18997ebd455cc62ff1474acbc9c2eeb0b8a0841c4d54844d57a9db0ab9930"`,
			);
		});

		it('should derive rule address for custom token', () => {
			const ruleId = deriveRuleAddress('0x123::custom::TOKEN', packageConfig);
			expect(ruleId).toMatchInlineSnapshot(
				`"0xb458a02e0ac6615ef4101384387fde5f3cc16132a9ce936e53623faa55f51246"`,
			);
		});

		it('should derive rule address for USDC', () => {
			const ruleId = deriveRuleAddress(
				'0xdba34672e30cb065b1f93e3ab55318768fd6fef66c15942c9f7cb846e2f900e7::usdc::USDC',
				packageConfig,
			);
			expect(ruleId).toMatchInlineSnapshot(
				`"0x148ab4dc1c3e916733cdbd0142f7f9425c8752acea46f35875ff84cf273043a9"`,
			);
		});

		it('should derive rule address for different namespace', () => {
			const config = { ...packageConfig, namespaceId: '0xdef' };
			const ruleId = deriveRuleAddress('0x2::sui::SUI', config);
			expect(ruleId).toMatchInlineSnapshot(
				`"0x3d1cb3fdba6ce2c84bbbd956a6250c10b7aaf18e739e70c147ffa54aa142ac48"`,
			);
		});

		it('should handle complex generic types', () => {
			const ruleId = deriveRuleAddress('0x2::coin::Coin<0x123::my_token::MY_TOKEN>', packageConfig);
			expect(ruleId).toMatchInlineSnapshot(
				`"0x6e757f34b868c2856c203524b69da114ae0029817b8f40c2a0c2c690f34ce30d"`,
			);
		});

		it('should handle nested generics', () => {
			const ruleId = deriveRuleAddress(
				'0x1::option::Option<0x2::coin::Coin<0x2::sui::SUI>>',
				packageConfig,
			);
			expect(ruleId).toMatchInlineSnapshot(
				`"0xbbb713d47e9ef9630ff158288e422afefb954c62041c4f7b437805397c2ee6f2"`,
			);
		});
	});
});
