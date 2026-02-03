import { Ed25519Keypair } from '@mysten/sui/keypairs/ed25519';
import { Transaction } from '@mysten/sui/transactions';
import { normalizeSuiAddress } from '@mysten/sui/utils';
import { beforeAll, describe, expect, it } from 'vitest';

import { Vault } from '../../src/contracts/pas/vault.js';
import { DemoUsdTestHelpers } from './demoUsd.ts';
import { setupToolbox, TestToolbox } from './setup.ts';

describe('e2e tests with shared PAS package (all tests run in the same PAS package)', () => {
	let toolbox: TestToolbox;
	let demoUsd: DemoUsdTestHelpers;

	// Each execution should use its own runner to avoid shared state of PAS package.
	beforeAll(async () => {
		toolbox = await setupToolbox();
		demoUsd = new DemoUsdTestHelpers(toolbox);
		await demoUsd.createRule();
	});

	it('Should not be able to unlock restricted funds (e.g. DEMO_USD).', async () => {
		const keypair = Ed25519Keypair.generate();
		const address = keypair.getPublicKey().toSuiAddress();

		await toolbox.createVaultForAddress(address);
		const vaultId = toolbox.client.pas.deriveVaultAddress(address);
		await demoUsd.mintFromFaucetInto(100, vaultId);

		const tx = new Transaction();
		tx.add(
			toolbox.client.pas.tx.unlockFunds({
				from: address,
				amount: 100 * 1_000_000,
				assetType: demoUsd.demoUsdAssetType,
			}),
		);

		await expect(
			toolbox.client.core.signAndExecuteTransaction({
				signer: keypair,
				transaction: tx,
				include: {
					effects: true,
				},
			}),
		).rejects.toThrowError('No command found for UnlockFunds action in Rule for ');
	});

	it('derivations work as expected for vaults', async () => {
		const vaultObjectId = toolbox.client.pas.deriveVaultAddress(toolbox.address());
		await toolbox.createVaultForAddress(toolbox.address());

		const { object: vaultObject } = await toolbox.client.core.getObject({
			objectId: vaultObjectId,
			include: { content: true },
		});

		expect(vaultObject).toBeDefined();

		const parsed = Vault.parse(vaultObject.content!);
		expect(normalizeSuiAddress(parsed.owner)).toBe(normalizeSuiAddress(toolbox.address()));
		expect(vaultObject.type).toBe(
			`${toolbox.client.pas.getPackageConfig().packageId}::vault::Vault`,
		);
	});

	it('derivations work as expected for rules', async () => {
		const ruleObjectId = toolbox.client.pas.deriveRuleAddress(demoUsd.demoUsdAssetType);

		const { object: ruleObject } = await toolbox.client.core.getObject({
			objectId: ruleObjectId,
			include: { content: true },
		});

		expect(ruleObject).toBeDefined();
		expect(ruleObject.type).toBe(
			`${toolbox.client.pas.getPackageConfig().packageId}::rule::Rule<${demoUsd.pub.originalId}::demo_usd::DEMO_USD>`,
		);
	});
});
