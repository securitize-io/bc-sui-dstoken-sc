import {
    ADMIN_KEYPAIR,
    deploy as baseDeploy,
    PublishSingleton,
    SuiClient,
    MoveType,
} from '../../easysui'

import fs from 'fs'
import path from 'path'
import { Config } from './config'

type DependencyArtifacts = {
    pasPackageId?: string
    pasNamespace?: string
    pasUpgradeCap?: string
    ptbPackageId?: string
}

export async function deploy() {
    const result = await baseDeploy(Config)

    const network = process.env.NETWORK ?? 'localnet'
    const isTestChain = network !== 'mainnet'

    if (!isTestChain) {
        return result
    }

    const artifacts = await resolveDependencyArtifacts()
    await setupPas(artifacts)
    patchEnvFile(network, artifacts)

    return result
}

async function resolveDependencyArtifacts(): Promise<DependencyArtifacts> {
    if (!fs.existsSync(PublishSingleton.pubFile)) {
        return {}
    }

    const content = fs.readFileSync(PublishSingleton.pubFile, 'utf8')

    const pasPackageId = extractPackageId(content, 'packages/pas')
    const ptbPackageId = extractPackageId(content, 'packages/ptb')

    const { pasNamespace, pasUpgradeCap } =
        await resolvePasObjectsFromRpc(pasPackageId!)

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
    const { data: objData } = await SuiClient.client.getObject({
        id: pasPackageId,
        options: { showPreviousTransaction: true },
    })

    const publishDigest = objData?.previousTransaction
    if (!publishDigest) {
        throw new Error(`Failed to resolve publish tx for package ${pasPackageId}`)
    }

    const tx = await SuiClient.client.getTransactionBlock({
        digest: publishDigest,
        options: { showObjectChanges: true },
    })

    return {
        pasNamespace: PublishSingleton.findObjectIdByType(
            `${pasPackageId}::namespace::Namespace`,
            true,
            tx,
        ),
        pasUpgradeCap: PublishSingleton.findObjectIdByType(
            '0x2::package::UpgradeCap',
            true,
            tx,
        ),
    }
}

async function setupPas(artifacts: DependencyArtifacts) {
    const { pasPackageId, pasNamespace, pasUpgradeCap } = artifacts

    if (!pasPackageId || !pasNamespace || !pasUpgradeCap) {
        return
    }

    await SuiClient.moveCall({
        signer: ADMIN_KEYPAIR!,
        target: `${pasPackageId}::namespace::setup`,
        args: [pasNamespace, pasUpgradeCap],
        argTypes: [MoveType.object, MoveType.object],
    })

    await SuiClient.moveCall({
        signer: ADMIN_KEYPAIR!,
        target: `${pasPackageId}::templates::setup`,
        args: [pasNamespace],
        argTypes: [MoveType.object],
    })
}

function patchEnvFile(network: string, artifacts: DependencyArtifacts) {
    const { pasPackageId, pasNamespace, ptbPackageId } = artifacts

    if (!pasPackageId && !ptbPackageId) {
        return
    }

    const envFile = path.join(process.cwd(), `.env.${network}`)
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
