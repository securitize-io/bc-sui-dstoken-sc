// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

import path from 'path';
import type { ClientWithExtensions } from '@mysten/sui/client';
import { FaucetRateLimitError, getFaucetHost, requestSuiFromFaucetV2 } from '@mysten/sui/faucet';
import { SuiGrpcClient } from '@mysten/sui/grpc';
import { Ed25519Keypair } from '@mysten/sui/keypairs/ed25519';
import { Transaction } from '@mysten/sui/transactions';
import { normalizeSuiAddress } from '@mysten/sui/utils';
import type { ContainerRuntimeClient } from 'testcontainers';
import { getContainerRuntimeClient } from 'testcontainers';
import { retry } from 'ts-retry-promise';
import { expect, inject } from 'vitest';

import { pas, type PASClient } from '../../src/index.js';

const DEFAULT_FAUCET_URL = process.env.FAUCET_URL ?? getFaucetHost('localnet');
const DEFAULT_FULLNODE_URL = process.env.FULLNODE_URL ?? 'http://127.0.0.1:9000';

export type PASClientType = ClientWithExtensions<{ pas: PASClient }, SuiGrpcClient>;

export type PublishedPackage = {
	digest: string;
	createdObjects: {
		id: string;
		type: string;
	}[];
	originalId: string;
	publishedAt: string;
};
export class TestToolbox {
	keypair: Ed25519Keypair;
	client: PASClientType;
	configPath: string;
	pubFilePath: string;
	publishedPackages: Record<string, PublishedPackage>;
	private publishLock: Promise<void> = Promise.resolve();

	constructor(
		keypair: Ed25519Keypair,
		client: PASClientType,
		configPath: string,
		pubFilePath: string,
		publishedPackages: Record<string, PublishedPackage>,
	) {
		this.keypair = keypair;
		this.client = client;
		this.configPath = configPath;
		this.pubFilePath = pubFilePath;
		this.publishedPackages = publishedPackages;
	}

	address() {
		return this.keypair.getPublicKey().toSuiAddress();
	}

	/// Publishes a package at a given path.
	/// IF the package is already published, we return its data.
	/// It only does sequential writes to avoid equivocation (we use a mutex)
	async publishPackage(packagePath: string) {
		// Ensure only one publish happens at a time using the mutex
		const currentLock = this.publishLock;
		let releaseLock: () => void;
		this.publishLock = new Promise<void>((resolve) => {
			releaseLock = resolve;
		});

		await currentLock;

		// If the package has already been published, return the published data.
		if (this.publishedPackages[packagePath]) {
			releaseLock!();
			return this.publishedPackages[packagePath];
		}

		try {
			const publicationData = await publishPackage(packagePath, {
				configPath: this.configPath,
				pubFilePath: this.pubFilePath,
				baseClient: this.client,
			});

			this.publishedPackages[packagePath] = {
				digest: publicationData.digest,
				createdObjects: publicationData.createdObjects,
				originalId: publicationData.packageId,
				publishedAt: publicationData.packageId,
			};

			return this.publishedPackages[packagePath];
		} finally {
			// Release the lock so the next publish can proceed
			releaseLock!();
		}
	}

	async simulateTransaction(tx: Transaction) {
		return simulateTransaction(this, tx);
	}

	async executeTransaction(tx: Transaction) {
		return executeTransaction(this, tx);
	}

	// Creates a vault for a given address.
	async createVaultForAddress(address: string) {
		const tx = new Transaction();
		tx.add(this.client.pas.call.createAndShareVault(address));
		return this.executeTransaction(tx);
	}

	async getBalance(address: string, assetType: string) {
		return this.client.core.getBalance({
			owner: normalizeSuiAddress(address),
			coinType: assetType,
		});
	}
}

export function getClient(): SuiGrpcClient {
	return new SuiGrpcClient({
		network: 'localnet',
		baseUrl: DEFAULT_FULLNODE_URL,
	});
}

export async function setupToolbox() {
	const keypair = Ed25519Keypair.generate();
	const address = keypair.getPublicKey().toSuiAddress();
	const baseClient = getClient();

	await retry(() => requestSuiFromFaucetV2({ host: DEFAULT_FAUCET_URL, recipient: address }), {
		backoff: 'EXPONENTIAL',
		// overall timeout in 60 seconds
		timeout: 1000 * 60,
		// skip retry if we hit the rate-limit error
		retryIf: (error: any) => !(error instanceof FaucetRateLimitError),
		logger: (msg) => console.warn('Retrying requesting from faucet: ' + msg),
	});

	const configDir = path.join('/test-data', `${Math.random().toString(36).substring(2, 15)}`);
	await execSuiTools(['mkdir', '-p', configDir]);
	const configPath = path.join(configDir, 'client.yaml');
	await execSuiTools(['sui', 'client', '--yes', '--client.config', configPath]);

	// Create a pub file that's persistent per test run.
	const pubFilePath = path.join(configDir, 'publications.toml');

	// Switch CLI to local env.
	await execSuiTools(['sui', 'client', '--client.config', configPath, 'switch', '--env', 'local']);

	// Get some gas for any publishes.
	await execSuiTools(['sui', 'client', '--client.config', configPath, 'faucet']);

	// wait for the faucet to be ready (give it 2s, should probably be like 100ms)
	await new Promise((resolve) => setTimeout(resolve, 2000));

	// Track the published packages.
	const publishedPackages: Record<string, PublishedPackage> = {};

	// publish PTB package
	const ptbPublishData = await publishPackage('ptb', {
		configPath,
		pubFilePath,
		baseClient,
	});

	publishedPackages.ptb = {
		digest: ptbPublishData.digest,
		createdObjects: ptbPublishData.createdObjects,
		originalId: ptbPublishData.packageId,
		publishedAt: ptbPublishData.packageId,
	};

	// publish PAS package
	const pasPublishData = await publishPackage('pas', {
		configPath,
		pubFilePath,
		baseClient,
	});

	publishedPackages.pas = {
		digest: pasPublishData.digest,
		createdObjects: pasPublishData.createdObjects,
		originalId: pasPublishData.packageId,
		publishedAt: pasPublishData.packageId,
	};

	// Extend the client with pas so we can use it across our testing.
	const client = baseClient.$extend(
		pas({
			packageConfig: {
				packageId: pasPublishData.packageId,
				namespaceId: pasPublishData.createdObjects.find((obj) =>
					obj.type.endsWith('namespace::Namespace'),
				)?.id!,
			},
		}),
	);

	return new TestToolbox(keypair, client, configPath, pubFilePath, publishedPackages);
}

// Extend client with PAS once we have the package/namespace IDs.
export function extendWithPAS(toolbox: TestToolbox, packageId: string, namespaceId: string): void {
	const extendedClient = (toolbox.client as unknown as SuiGrpcClient).$extend(
		pas({
			packageConfig: {
				packageId,
				namespaceId,
			},
		}),
	);
	toolbox.client = extendedClient as PASClientType;
}

// This should be kept private as there's a risk of equivocating the
// CLI address if trying to publish from different executions in parallel.
// It's recommended that we only do the test publishes once in the beginning.
// Locking is now handled at the TestToolbox.publishPackage level.

async function publishPackage(
	packageName: string,
	{
		configPath,
		pubFilePath,
		baseClient,
	}: {
		configPath: string;
		pubFilePath: string;
		baseClient: SuiGrpcClient;
	},
) {
	// Let's publish using `test-publish` command.
	// Should be reusing pubFilePaths for each package (so they depend on the same thing!).
	const result = await execSuiTools([
		'sui',
		'client',
		'--client.config',
		configPath,
		'test-publish',
		'--build-env',
		'testnet',
		'--pubfile-path',
		pubFilePath,
		`/test-data/${packageName}`,
		'--json',
	]);

	// trim everything before `{`
	const resultJson = result.stdout.substring(result.stdout.indexOf('{'));
	const publicationDigest = JSON.parse(resultJson).digest;
	// const transaction = await getCli

	// Get the TX to extract the package ID.
	const transaction = await baseClient.getTransaction({
		digest: publicationDigest,
		include: {
			content: true,
			effects: true,
			events: true,
			objectChanges: true,
			objectTypes: true,
		},
	});

	const createdObjects = transaction
		.Transaction!.effects.changedObjects.filter(
			(obj) => obj.idOperation === 'Created' && obj.outputState === 'ObjectWrite',
		)
		.map((x) => {
			return {
				id: x.objectId,
				type: transaction.Transaction!.objectTypes![x.objectId],
			};
		});

	const packageId = transaction.Transaction!.effects.changedObjects.find(
		(obj) => obj.idOperation === 'Created' && obj.outputState === 'PackageWrite',
	)?.objectId;
	if (!packageId) throw new Error('Package ID not found');

	return {
		digest: publicationDigest,
		createdObjects,
		packageId,
	};
}

export async function executeTransaction(toolbox: TestToolbox, tx: Transaction) {
	const resp = await toolbox.client.signAndExecuteTransaction({
		signer: toolbox.keypair,
		transaction: tx,
		include: {
			effects: true,
			events: true,
			objectChanges: true,
		},
	});

	if (!resp.Transaction?.digest) {
		console.dir(resp, { depth: null });
		throw new Error('Transaction digest is missing');
	}

	await toolbox.client.core.waitForTransaction({
		digest: resp.Transaction.digest,
	});

	expect(resp.Transaction?.status.success).toEqual(true);

	return resp;
}

export async function simulateTransaction(toolbox: TestToolbox, tx: Transaction) {
	tx.setSender(toolbox.address());
	await tx.prepareForSerialization({ client: toolbox.client });
	return await toolbox.client.core.simulateTransaction({
		transaction: tx,
	});
}

const SUI_TOOLS_CONTAINER_ID = inject('suiToolsContainerId');

export async function execSuiTools(
	command: string[],
	options?: Parameters<ContainerRuntimeClient['container']['exec']>[2],
) {
	const client = await getContainerRuntimeClient();
	const container = client.container.getById(SUI_TOOLS_CONTAINER_ID);

	const result = await client.container.exec(container, command, options);

	if (result.stderr) console.error(result.stderr);
	// if (result.stdout) console.log(result.stdout);

	return result;
}
