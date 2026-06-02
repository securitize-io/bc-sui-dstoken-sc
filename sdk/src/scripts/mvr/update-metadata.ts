import { Transaction } from '@mysten/sui/transactions'
import {
    executeOrBuildBytes,
    getNetwork,
    loadConfig,
    loadDeployments,
    makeClient,
    requireEnv,
} from './_shared'

const PKG = 'securitize'

async function main() {
    const network = getNetwork()
    if (network !== 'mainnet') {
        console.error(
            `update-metadata: MVR AppRecord lives on mainnet only — got NETWORK=${network}.`,
        )
        process.exit(1)
    }

    const cfg = loadConfig('mainnet')
    const custody = requireEnv('CUSTODY_ADDRESS')
    const key = requireEnv('METADATA_KEY')
    const value = process.env.METADATA_VALUE
    const gasBudget = BigInt(process.env.GAS_BUDGET ?? '100000000')

    if (key.trim() === '') {
        console.error('METADATA_KEY must be non-empty.')
        process.exit(1)
    }
    if (!cfg.mvrRegistryId || cfg.mvrRegistryId.startsWith('FILL_IN')) {
        console.error('mvr/mainnet.json: mvrRegistryId is not set.')
        process.exit(1)
    }

    const deployments = loadDeployments('mainnet')
    const appCapId = deployments.packages[PKG]?.appCapId
    if (!appCapId) {
        console.error(
            'deployments/mainnet.json: packages.securitize.appCapId missing — run phase-3 first.',
        )
        process.exit(1)
    }

    const isUnset = value === undefined || value === ''
    const client = makeClient('mainnet')

    const tx = new Transaction()
    tx.setSender(custody)
    tx.setGasOwner(custody)
    tx.setGasBudget(gasBudget)

    if (isUnset) {
        tx.moveCall({
            target: '@mvr/core::move_registry::unset_metadata',
            arguments: [
                tx.object(cfg.mvrRegistryId),
                tx.object(appCapId),
                tx.pure.string(key),
            ],
        })
        console.log(`[plan] mainnet/${PKG} AppRecord.metadata[${key}] = (unset)`)
    } else {
        tx.moveCall({
            target: '@mvr/core::move_registry::set_metadata',
            arguments: [
                tx.object(cfg.mvrRegistryId),
                tx.object(appCapId),
                tx.pure.string(key),
                tx.pure.string(value),
            ],
        })
        console.log(`[plan] mainnet/${PKG} AppRecord.metadata[${key}] = ${value}`)
    }

    await executeOrBuildBytes(tx, client, 'mainnet', `${PKG}-metadata-${key}`)
}

main().catch((e) => {
    console.error(e)
    process.exit(1)
})
