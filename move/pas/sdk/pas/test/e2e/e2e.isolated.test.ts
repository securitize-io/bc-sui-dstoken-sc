import { Transaction } from '@mysten/sui/transactions';
import { normalizeStructTag, normalizeSuiAddress } from '@mysten/sui/utils';
import { beforeEach, describe, expect, it } from 'vitest';

import { DemoUsdTestHelpers } from './demoUsd.ts';
import { setupToolbox, TestToolbox } from './setup.ts';

describe('e2e tests with isolated PAS Package (each test runs in its own PAS package)', () => {
	let toolbox: TestToolbox;

	// Each execution should use its own runner to avoid shared state of PAS package.
	beforeEach(async () => {
		toolbox = await setupToolbox();
	});

	it('unlocks non-managed funds (e.g. SUI), but only through the unrestricted unlock flow', async () => {
		const vaultId = toolbox.client.pas.deriveVaultAddress(toolbox.address());

		const suiTypeName = normalizeStructTag('0x2::sui::SUI').toString();

		const { balance } = await toolbox.getBalance(vaultId, suiTypeName);
		expect(Number(balance.balance)).toBe(0);

		// Transfer 1 SUI to the vault.
		const fundTransferTx = new Transaction();
		const sui = fundTransferTx.splitCoins(fundTransferTx.gas, [
			fundTransferTx.pure.u64(1_000_000_000),
		]);

		const into_balance = fundTransferTx.moveCall({
			target: '0x2::coin::into_balance',
			arguments: [sui],
			typeArguments: [suiTypeName],
		});
		fundTransferTx.moveCall({
			target: '0x2::balance::send_funds',
			arguments: [into_balance, fundTransferTx.pure.address(vaultId)],
			typeArguments: [suiTypeName],
		});
		await toolbox.executeTransaction(fundTransferTx);

		// Create the vault for the address.
		await toolbox.createVaultForAddress(toolbox.address());

		const { balance: vaultBalanceAfterTransfer } = await toolbox.getBalance(vaultId, suiTypeName);
		expect(Number(vaultBalanceAfterTransfer.balance)).toBe(1_000_000_000);

		// try to do an unlock but it should fail because `rule` for Sui does not exist.
		const tx = new Transaction();
		tx.add(
			toolbox.client.pas.tx.unlockFunds({
				from: toolbox.address(),
				amount: 1_000_000_000,
				assetType: suiTypeName,
			}),
		);
		// Should fail because SUI is not a managed asset
		await expect(toolbox.executeTransaction(tx)).rejects.toThrowError(
			'Rule does not exist for asset type ',
		);

		// Now let's unlock funds properly.
		const unlockTx = new Transaction();
		const withdrawal = unlockTx.add(
			toolbox.client.pas.tx.unlockUnrestrictedFunds({
				from: toolbox.address(),
				amount: 1_000_000_000,
				assetType: suiTypeName,
			}),
		);
		unlockTx.moveCall({
			target: '0x2::balance::send_funds',
			arguments: [withdrawal, unlockTx.pure.address(toolbox.address())],
			typeArguments: [suiTypeName],
		});

		await toolbox.executeTransaction(unlockTx);

		const { balance: vaultBalanceAfterUnlock } = await toolbox.getBalance(vaultId, suiTypeName);
		expect(Number(vaultBalanceAfterUnlock.balance)).toBe(0);
	});

	it('Should be able to transfer between vaults, going through the rule of the issuer;', async () => {
		const demoUsd = new DemoUsdTestHelpers(toolbox);
		await demoUsd.createRule();

		const from = toolbox.address();
		const to = normalizeSuiAddress('0x2');

		const fromVaultId = toolbox.client.pas.deriveVaultAddress(from);
		const toVaultId = toolbox.client.pas.deriveVaultAddress(to);

		await toolbox.createVaultForAddress(from);
		await toolbox.createVaultForAddress(to);

		await demoUsd.mintFromFaucetInto(100, fromVaultId);

		const [{ balance: fromBalanceBefore }, { balance: toBalanceBefore }] = await Promise.all([
			toolbox.getBalance(fromVaultId, demoUsd.demoUsdAssetType),
			toolbox.getBalance(toVaultId, demoUsd.demoUsdAssetType),
		]);

		expect(Number(fromBalanceBefore.balance)).toBe(100 * 1_000_000);
		expect(Number(toBalanceBefore.balance)).toBe(0);

		const tx = new Transaction();
		tx.add(
			toolbox.client.pas.tx.transferFunds({
				from,
				to,
				amount: 100 * 1_000_000,
				assetType: demoUsd.demoUsdAssetType,
			}),
		);

		await toolbox.executeTransaction(tx);

		const [{ balance: fromBalanceAfter }, { balance: toBalanceAfter }] = await Promise.all([
			toolbox.getBalance(fromVaultId, demoUsd.demoUsdAssetType),
			toolbox.getBalance(toVaultId, demoUsd.demoUsdAssetType),
		]);

		expect(Number(fromBalanceAfter.balance)).toBe(0);
		expect(Number(toBalanceAfter.balance)).toBe(100 * 1_000_000);
	});

	it('Should be able to create the recipient vault if it does not exist ahead of time', async () => {
		const demoUsd = new DemoUsdTestHelpers(toolbox);
		await demoUsd.createRule();

		const from = toolbox.address();
		const to = normalizeSuiAddress('0x2');

		const fromVaultId = toolbox.client.pas.deriveVaultAddress(from);
		const toVaultId = toolbox.client.pas.deriveVaultAddress(to);

		await demoUsd.mintFromFaucetInto(100, fromVaultId);
		await toolbox.createVaultForAddress(from);

		await expect(
			toolbox.client.core.getObject({
				objectId: toVaultId,
			}),
		).rejects.toThrowError('not found');

		const transaction = new Transaction();
		transaction.add(
			toolbox.client.pas.tx.transferFunds({
				from,
				to,
				amount: 1_000_000,
				assetType: demoUsd.demoUsdAssetType,
			}),
		);

		await toolbox.executeTransaction(transaction);

		// Object should now exist after the first transfer.
		const responseAfter = await toolbox.client.core.getObject({
			objectId: toVaultId,
		});

		expect(responseAfter.object).toBeDefined();
	});

	it('Should fail to transfer between vaults, if there are not enough funds in the source vault', async () => {
		const demoUsd = new DemoUsdTestHelpers(toolbox);
		await demoUsd.createRule();

		const from = toolbox.address();
		const to = normalizeSuiAddress('0x2');

		await toolbox.createVaultForAddress(from);
		await toolbox.createVaultForAddress(to);

		const transaction = new Transaction();
		transaction.add(
			toolbox.client.pas.tx.transferFunds({
				from,
				to,
				amount: 100 * 1_000_000,
				assetType: demoUsd.demoUsdAssetType,
			}),
		);

		const resp = await toolbox.client.signAndExecuteTransaction({
			signer: toolbox.keypair,
			transaction,
			include: {
				effects: true,
			},
		});

		expect(resp.FailedTransaction).toBeDefined();
		expect(resp.FailedTransaction!.effects.status.error!.message).toEqual(
			'InsufficientFundsForWithdraw',
		);
	});
});
