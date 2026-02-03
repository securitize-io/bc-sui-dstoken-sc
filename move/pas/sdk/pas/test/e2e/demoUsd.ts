import { Transaction } from '@mysten/sui/transactions';

import { type PublishedPackage, type TestToolbox } from './setup.ts';

export class DemoUsdTestHelpers {
	toolbox: TestToolbox;
	#publicationData: PublishedPackage;

	constructor(toolbox: TestToolbox) {
		this.toolbox = toolbox;
	}

	get pub() {
		if (!this.#publicationData) {
			throw new Error('Publication data not found. Call `createRule` first.');
		}
		return this.#publicationData;
	}

	// setup the rule
	async createRule() {
		if (this.#publicationData) {
			return this.#publicationData;
		}

		const result = await this.toolbox.publishPackage('demo_usd');
		this.#publicationData = result;

		const faucetId = result.createdObjects.find((o) => o.type.endsWith('demo_usd::Faucet'))!.id;

		const transaction = new Transaction();
		transaction.moveCall({
			target: `${result.originalId}::demo_usd::setup`,
			arguments: [
				transaction.object(this.toolbox.client.pas.getPackageConfig().namespaceId),
				transaction.object(faucetId),
			],
		});

		await this.toolbox.executeTransaction(transaction);

		return this.#publicationData;
	}

	async mintFromFaucetInto(amount: number, to: string) {
		const transaction = new Transaction();
		const balance = transaction.moveCall({
			target: `${this.pub.originalId}::demo_usd::faucet_mint_balance`,
			arguments: [
				transaction.object(
					this.pub.createdObjects.find((o) => o.type.endsWith('demo_usd::Faucet'))!.id,
				),
				transaction.pure.u64(amount * 1_000_000),
			],
		});

		transaction.moveCall({
			target: `0x2::balance::send_funds`,
			arguments: [balance, transaction.pure.address(to)],
			typeArguments: [this.demoUsdAssetType],
		});

		await this.toolbox.executeTransaction(transaction);
	}

	get demoUsdAssetType() {
		return `${this.pub.originalId}::demo_usd::DEMO_USD`;
	}
}
