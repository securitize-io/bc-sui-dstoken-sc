import {ADMIN_KEYPAIR, deploy as baseDeploy, PublishSingleton, SuiClient, MoveType} from '../../easysui'
import fs from "fs";
import path from "path";
import {Config} from "./config";

export async function deploy() {
    const result = await baseDeploy(Config)

    // PAS is published as a dependency — resolve PAS_PACKAGE_ID, PAS_NAMESPACE, and PAS_UPGRADE_CAP
    const network = process.env.NETWORK || 'localnet'
    const isTestChain = network !== 'mainnet' //TODO change it when PAS in MVR
    let pasPackageId: string | undefined
    let pasNamespace: string | undefined
    let pasUpgradeCap: string | undefined
    let ptbPackageId: string | undefined

    if (isTestChain && fs.existsSync(PublishSingleton.pubFile)) {
        // Ephemeral chains: PAS & PTB are published in a separate TX — read Pub file and query RPC
        const content = fs.readFileSync(PublishSingleton.pubFile, 'utf8')
        const pasMatch = content.match(/\[\[published\]\][^[]*?packages\/pas[^[]*?published-at\s*=\s*"(0x[0-9a-fA-F]+)"/)
        const ptbMatch = content.match(/\[\[published\]\][^[]*?packages\/ptb[^[]*?published-at\s*=\s*"(0x[0-9a-fA-F]+)"/)
        if (ptbMatch) {
            ptbPackageId = ptbMatch[1]
        }
        if (pasMatch) {
            pasPackageId = pasMatch[1]
            const { data } = await SuiClient.client.queryTransactionBlocks({
                filter: { ChangedObject: pasPackageId },
                options: { showObjectChanges: true },
                order: 'ascending',
                limit: 1,
            })
            if (data.length > 0) {
                pasNamespace = PublishSingleton.findObjectIdByType(
                    `${pasPackageId}::namespace::Namespace`, true, data[0]
                )
                pasUpgradeCap = PublishSingleton.findObjectIdByType(
                    '0x2::package::UpgradeCap', true, data[0]
                )
            }
        }
    }

    // Call PAS setup functions: namespace::setup and templates::setup
    if (pasPackageId && pasNamespace && pasUpgradeCap) {
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

    if (pasPackageId || ptbPackageId) {
        const envFile = path.join(process.cwd(), `.env.${network}`)
        let envContent = fs.readFileSync(envFile, 'utf8')
        const patches: Record<string, string> = {
            ...(pasPackageId && { PAS_PACKAGE_ID: pasPackageId }),
            ...(pasNamespace && { PAS_NAMESPACE: pasNamespace }),
            ...(ptbPackageId && { PTB_PACKAGE_ID: ptbPackageId }),
        }
        for (const [key, value] of Object.entries(patches)) {
            const regex = new RegExp(`^${key}=.*$`, 'm')
            if (regex.test(envContent)) {
                envContent = envContent.replace(regex, `${key}=${value}`)
            } else {
                envContent += `\n${key}=${value}`
            }
        }
        fs.writeFileSync(envFile, envContent, 'utf8')
    }

    return result
}