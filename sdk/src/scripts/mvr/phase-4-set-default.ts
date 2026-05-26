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
    const cfg = loadConfig(network)
    const custody = requireEnv('CUSTODY_ADDRESS')
    const gasBudget = BigInt(process.env.GAS_BUDGET ?? '100000000')

    const deployments = loadDeployments(network)
    const packageInfoId = deployments.packages[PKG]?.packageInfoId
    if (!packageInfoId) {
        console.error(`deployments/${network}.json: packages.securitize.packageInfoId missing — run phase-2 first.`)
        process.exit(1)
    }

    const client = makeClient(network)

    const tx = new Transaction()
    tx.setSender(custody)
    tx.setGasOwner(custody)
    tx.setGasBudget(gasBudget)

    // The "default" key on a PackageInfo enables reverse resolution: tools that
    // see this package address can look up the MVR name without external context.
    tx.moveCall({
        target: '@mvr/metadata::package_info::set_metadata',
        arguments: [
            tx.object(packageInfoId),
            tx.pure.string('default'),
            tx.pure.string(cfg.mvrName),
        ],
    })

    console.log(`[plan] ${network}/${PKG} PackageInfo.default = ${cfg.mvrName}`)
    await executeOrBuildBytes(tx, client, network, `${PKG}-set-default`)
}

main().catch((e) => {
    console.error(e)
    process.exit(1)
})
