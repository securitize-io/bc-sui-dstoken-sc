import { SuiJsonRpcClient } from '@mysten/sui/jsonRpc'
import { getFullnodeUrl } from '@mysten/sui/client'
import { Transaction } from '@mysten/sui/transactions'
import { Ed25519Keypair } from '@mysten/sui/keypairs/ed25519'
import { decodeSuiPrivateKey } from '@mysten/sui/cryptography'
import { mkdirSync, readFileSync, writeFileSync, existsSync } from 'node:fs'
import { join } from 'node:path'

export type Network = 'mainnet' | 'testnet'

export interface MvrConfig {
    mvrName: string
    suinsNftId: string
    mvrRegistryId: string
    repoUrl: string
    gitSubdir: string
    displayName: string
    metadata: {
        description: string
        homepage_url: string
        documentation_url: string
        icon_url: string
        contact: string
    }
}

export interface PackageDeployment {
    packageId?: string
    upgradeCapId?: string
    publisherId?: string
    packageInfoId?: string
    appCapId?: string
    gitCommit?: string
}

export interface NetworkDeployments {
    network: Network
    packages: Record<string, PackageDeployment>
}

const SDK_ROOT = process.env.SDK_ROOT ?? process.cwd()

const configPath = (n: Network) => join(SDK_ROOT, 'mvr', `${n}.json`)
const deploymentsPath = (n: Network) => join(SDK_ROOT, 'deployments', `${n}.json`)
const outDir = () => join(SDK_ROOT, 'out')

export function requireEnv(name: string): string {
    const v = process.env[name]
    if (!v) {
        console.error(`Missing required env var: ${name}`)
        process.exit(1)
    }
    return v
}

export function getNetwork(): Network {
    const n = requireEnv('NETWORK')
    if (n !== 'mainnet' && n !== 'testnet') {
        console.error(`NETWORK must be 'mainnet' or 'testnet', got: ${n}`)
        process.exit(1)
    }
    return n
}

export function loadConfig(network: Network): MvrConfig {
    const path = configPath(network)
    if (!existsSync(path)) {
        console.error(`MVR config not found at ${path}`)
        process.exit(1)
    }
    return JSON.parse(readFileSync(path, 'utf8'))
}

export function loadDeployments(network: Network): NetworkDeployments {
    const path = deploymentsPath(network)
    if (!existsSync(path)) {
        return { network, packages: {} }
    }
    return JSON.parse(readFileSync(path, 'utf8'))
}

export function saveDeployments(d: NetworkDeployments) {
    const dir = join(SDK_ROOT, 'deployments')
    mkdirSync(dir, { recursive: true })
    const path = deploymentsPath(d.network)
    writeFileSync(path, JSON.stringify(d, null, 2) + '\n', 'utf8')
    console.log(`[wrote] ${path}`)
}

export function makeClient(network: Network): SuiJsonRpcClient {
    return new SuiJsonRpcClient({ network, url: getFullnodeUrl(network) })
}

export async function fetchUpgradeCapVersion(
    client: SuiJsonRpcClient,
    upgradeCapId: string,
): Promise<bigint> {
    const resp = await client.getObject({ id: upgradeCapId, options: { showContent: true } })
    const content = resp.data?.content
    if (content?.dataType !== 'moveObject') {
        throw new Error(`UpgradeCap ${upgradeCapId} not found or has no Move content`)
    }
    const version = (content.fields as { version?: string }).version
    if (version === undefined) {
        throw new Error(`UpgradeCap ${upgradeCapId} has no version field`)
    }
    return BigInt(version)
}

export type ExecuteResult = Awaited<ReturnType<SuiJsonRpcClient['signAndExecuteTransaction']>>

export async function executeOrBuildBytes(
    tx: Transaction,
    client: SuiJsonRpcClient,
    network: Network,
    label: string,
): Promise<
    | { mode: 'executed'; result: ExecuteResult }
    | { mode: 'built'; outPath: string }
> {
    const opKey = process.env.OPERATOR_PRIVATE_KEY
    if (opKey) {
        const { secretKey } = decodeSuiPrivateKey(opKey)
        const keypair = Ed25519Keypair.fromSecretKey(secretKey)
        console.log('[mode] hot-key sign-and-execute')
        console.log(`[sender] ${keypair.toSuiAddress()}`)
        const result = await client.signAndExecuteTransaction({
            signer: keypair,
            transaction: tx,
            options: { showObjectChanges: true, showEffects: true, showEvents: true },
            requestType: 'WaitForLocalExecution',
        })
        if (result.effects?.status?.status !== 'success') {
            console.error('Transaction failed:', JSON.stringify(result.effects?.status, null, 2))
            process.exit(1)
        }
        console.log(`[ok] tx ${result.digest}`)
        return { mode: 'executed', result }
    }
    console.log('[mode] build-only (OPERATOR_PRIVATE_KEY unset)')
    const bytes = await tx.build({ client })
    const b64 = Buffer.from(bytes).toString('base64')
    mkdirSync(outDir(), { recursive: true })
    const outPath = join(outDir(), `tx-${network}-${label}.b64`)
    writeFileSync(outPath, b64, 'utf8')
    console.log(`[ok] unsigned tx bytes written to ${outPath}`)
    console.log('     Hand this file to your external signer (e.g. Fireblocks).')
    console.log('     Submit the signed tx with src/scripts/mvr/submit-signed.ts')
    return { mode: 'built', outPath }
}

export function findCreated(result: ExecuteResult, typeContains: string) {
    const created = (result.objectChanges ?? []).filter((c) => c.type === 'created')
    return created.find((c) =>
        (c as { objectType?: string }).objectType?.includes(typeContains),
    ) as { objectType: string; objectId: string } | undefined
}
