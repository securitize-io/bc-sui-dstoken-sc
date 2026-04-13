import {
    deploy as baseDeploy,
    PublishSingleton,
    SuiClient,
    MoveType,
} from '../../easysui'
import { Keypair } from '@mysten/sui/cryptography'

import fs from 'fs'
import path from 'path'
import { Config } from './config'

type DependencyArtifacts = {
    pasPackageId?: string
    pasNamespace?: string
    pasUpgradeCap?: string
    ptbPackageId?: string
}

export async function deploy(signer: Keypair) {
    const network = process.env.NETWORK ?? 'localnet'

    // On testnet/mainnet, skip publishing — use already deployed packages from .env
    if (network === 'testnet' || network === 'mainnet') {
        Config.invalidateCache()
        return `Using existing deployment on ${network}`
    }

    const result = await baseDeploy(Config, undefined, signer)

    const artifacts = await resolveDependencyArtifacts()
    await setupPas(artifacts, signer)
    patchEnvFile(network, artifacts)
    Config.invalidateCache()

    return result
}

async function resolveDependencyArtifacts(): Promise<DependencyArtifacts> {
    if (!fs.existsSync(PublishSingleton.pubFile)) {
        return {}
    }

    const content = fs.readFileSync(PublishSingleton.pubFile, 'utf8')

    const pasPackageId = extractPackageId(content, 'packages/pas')
    const ptbPackageId = extractPackageId(content, 'packages/ptb')

    if (!pasPackageId) {
        return { ptbPackageId }
    }

    const { pasNamespace, pasUpgradeCap } =
        await resolvePasObjectsFromRpc(pasPackageId)

    return {
        pasPackageId,
        pasNamespace,
        pasUpgradeCap,
        ptbPackageId,
    }
}

function extractPackageId(content: string, packagePath: string): string | undefined {
    const match = content.match(
        new RegExp(
            `\\[\\[published\\]\\][^[]*?${packagePath}[^[]*?published-at\\s*=\\s*"(0x[0-9a-fA-F]+)"`,
        ),
    )
    return match?.[1]
}

async function resolvePasObjectsFromRpc(pasPackageId: string) {
    const { object } = await SuiClient.client.getObject({
        objectId: pasPackageId,
        include: { previousTransaction: true },
    })

    const publishDigest = object.previousTransaction
    if (!publishDigest) {
        throw new Error(`Failed to resolve publish tx for package ${pasPackageId}`)
    }

    const txResult = await SuiClient.client.getTransaction({
        digest: publishDigest,
        include: { effects: true, objectTypes: true },
    })

    const tx = txResult.Transaction ?? txResult.FailedTransaction
    const changedObjects = tx?.effects?.changedObjects ?? []
    const objectTypes: Record<string, string> = tx?.objectTypes ?? {}

    const findCreatedByType = (type: string): string => {
        const found = changedObjects.find(
            (c: any) => c.idOperation === 'Created' && PublishSingleton.typeMatches(objectTypes[c.objectId] || '', type)
        )
        if (!found) throw new Error(`Expected to find ${type} created object`)
        return found.objectId
    }

    return {
        pasNamespace: findCreatedByType(`${pasPackageId}::namespace::Namespace`),
        pasUpgradeCap: findCreatedByType('0x2::package::UpgradeCap'),
    }
}

async function setupPas(artifacts: DependencyArtifacts, signer: Keypair) {
    const { pasPackageId, pasNamespace, pasUpgradeCap } = artifacts

    if (!pasPackageId || !pasNamespace || !pasUpgradeCap) {
        return
    }

    await SuiClient.moveCall({
        signer,
        target: `${pasPackageId}::namespace::setup`,
        args: [pasNamespace, pasUpgradeCap],
        argTypes: [MoveType.object, MoveType.object],
    })

    await SuiClient.moveCall({
        signer,
        target: `${pasPackageId}::templates::setup`,
        args: [pasNamespace],
        argTypes: [MoveType.object],
    })
}

function getEnvFileSuffix(network: string): string {
    if (network === 'testnet') {
        const env = process.env.SECURITIZE_TESTNET_ENV
        if (env && ['testnet_alpha', 'testnet_beta', 'testnet_gamma'].includes(env)) {
            return env
        }
    }
    return network
}

function patchEnvFile(network: string, artifacts: DependencyArtifacts) {
    const { pasPackageId, pasNamespace, ptbPackageId } = artifacts

    if (!pasPackageId && !ptbPackageId) {
        return
    }

    const envSuffix = getEnvFileSuffix(network)
    const envFile = path.join(process.cwd(), `.env.${envSuffix}`)
    if (!fs.existsSync(envFile)) {
        throw new Error(`Missing env file: ${envFile}`)
    }

    let content = fs.readFileSync(envFile, 'utf8')

    const patches: Record<string, string | undefined> = {
        PAS_PACKAGE_ID: pasPackageId,
        PAS_NAMESPACE: pasNamespace,
        PTB_PACKAGE_ID: ptbPackageId,
    }

    for (const [key, value] of Object.entries(patches)) {
        if (!value) continue

        const regex = new RegExp(`^${key}=.*$`, 'm')

        content = regex.test(content)
            ? content.replace(regex, `${key}=${value}`)
            : `${content.trim()}\n${key}=${value}\n`
    }

    fs.writeFileSync(envFile, content, 'utf8')
}
