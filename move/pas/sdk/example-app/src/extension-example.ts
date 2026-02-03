// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/**
 * Example demonstrating PAS SDK usage with the SDK v2.0 $extend pattern
 */

const assetType = '0xf4874d6d4854f92019a2b3914d3838522a72f3c02658893488417ac90c00189b::demo_usd::DEMO_USD';
const demoAssetFaucet = '0x6e48b7accee3e69f3b2ac3d86b9496dac059bd5b7ee3e8869a70ceb1f78ee20b'

import { SuiGrpcClient } from '@mysten/sui/grpc';
import { decodeSuiPrivateKey, Signer } from '@mysten/sui/cryptography';
import { Ed25519Keypair } from '@mysten/sui/keypairs/ed25519';
import { pas, PASClient } from '../../pas/dist/index.mjs';
import { Transaction } from '@mysten/sui/transactions';
import { ClientWithExtensions } from '@mysten/sui/client';
import { normalizeSuiAddress } from '@mysten/sui/utils';

type PasClientType = ClientWithExtensions<{ pas: PASClient }, SuiGrpcClient>;

async function main(): Promise<void> {
	const sender = getActiveKeypair().toSuiAddress();

	const client = new SuiGrpcClient({
		network: 'devnet',
		baseUrl: 'https://fullnode.devnet.sui.io:443',
	}).$extend(pas());

	// console.log(await getBalancesForAddress(client, sender));

	// await createVaultForAddress(client, sender);
	// await createVaultForAddress(client, '0x2');

	// console.log(client.pas.deriveVaultAddress(sender));
	// await mintFromDemoFaucetAndTransferToVault(client, 10, sender);

	const tx = new Transaction();

	tx.add(client.pas.tx.transferFunds({
		from: sender, // sender here.
		to: '0x2', // receiver here.
		amount: 1_000_000, // 1 demoUSD
		assetType
	}));

	await signAndExecute(client, tx);
}

main();

// Queries the balances for address (both the addr balance, and the vault's balance.)
async function getBalancesForAddress(client: PasClientType, address: string) {
	const addr = normalizeSuiAddress(address);
	const [addressBalance, vaultBalance] = await Promise.all([
		client.core.getBalance({
			owner: addr,
			coinType: assetType
		}), 
		client.core.getBalance({
			owner: client.pas.deriveVaultAddress(address),
			coinType: assetType
		})
	]);

	return { addressBalance, vaultBalance };
}

async function mintFromDemoFaucetAndTransferToVault(client: PasClientType, amount: number, owner: string) { 
	const tx = new Transaction();

	const balance = tx.moveCall({
		target: `${assetType.split('::')[0]}::demo_usd::faucet_mint_balance`,
		arguments: [tx.object(demoAssetFaucet), tx.pure.u64(amount * 1_000_000)],
	});

	tx.moveCall({
		target: `0x2::balance::send_funds`,
		arguments: [balance, tx.pure.address(client.pas.deriveVaultAddress(owner))],
		typeArguments: [assetType]
	})

	await signAndExecute(client, tx);
} 

async function finalizeTestAssetSetup(client: PasClientType) { 
	const tx = new Transaction();

	tx.moveCall({
		target: assetType.split('::')[0] + '::demo_usd::setup',
		arguments: [tx.object(client.pas.getPackageConfig().namespaceId)]
	});

	await signAndExecute(client, tx);
}

async function createVaultForAddress(client: PasClientType, address: string) {
	const tx = new Transaction();
	tx.add(client.pas.call.createAndShareVault(address));
	return signAndExecute(client, tx);
}

async function signAndExecute(client: SuiGrpcClient, tx: Transaction) {
	const result = await client.signAndExecuteTransaction({
		transaction: tx,
		signer: getActiveKeypair(),
		include: {
			effects: true,
		}
	});

	console.dir(result, { depth: null });
	return result
}


function getActiveKeypair() {
	// @ts-ignore
	const env = process.env.PRIVATE_KEY;

	if (!env) throw new Error('Missing PRIVATE_KEY environment variable. This has to be a sui private key `suiprivkey...`');
	

	const keypair = decodeSuiPrivateKey(env);
	return Ed25519Keypair.fromSecretKey(keypair.secretKey);
}


// Helper to load an ENV key so we can run some TXs (resolve actually!)
