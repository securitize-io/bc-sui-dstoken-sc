import { Transaction } from '@mysten/sui/transactions'
import {
    executeOrBuildBytes,
    fetchUpgradeCapVersion,
    getNetwork,
    loadConfig,
    loadDeployments,
    makeClient,
    requireEnv,
    saveDeployments,
} from './_shared'

const PKG = 'securitize'

async function main() {
    const network = getNetwork()
    const cfg = loadConfig(network)
    const custody = requireEnv('CUSTODY_ADDRESS')
    const newCommit = requireEnv('GIT_COMMIT')
    const gasBudget = BigInt(process.env.GAS_BUDGET ?? '100000000')

    const deployments = loadDeployments(network)
    const pkgEntry = deployments.packages[PKG]
    if (!pkgEntry?.packageInfoId) {
        console.error(`deployments/${network}.json: packages.securitize.packageInfoId missing.`)
        process.exit(1)
    }
    if (!pkgEntry.upgradeCapId) {
        console.error(`deployments/${network}.json: packages.securitize.upgradeCapId missing — needed to read the current package version.`)
        process.exit(1)
    }

    const client = makeClient(network)
    const upgradeCapVersion = await fetchUpgradeCapVersion(client, pkgEntry.upgradeCapId)

    const tx = new Transaction()
    tx.setSender(custody)
    tx.setGasOwner(custody)
    tx.setGasBudget(gasBudget)

    const gitInfo = tx.moveCall({
        target: '@mvr/metadata::git::new',
        arguments: [
            tx.pure.string(cfg.repoUrl),
            tx.pure.string(cfg.gitSubdir),
            tx.pure.string(newCommit),
        ],
    })
    tx.moveCall({
        target: '@mvr/metadata::package_info::set_git_versioning',
        arguments: [tx.object(pkgEntry.packageInfoId), tx.pure.u64(upgradeCapVersion), gitInfo],
    })

    console.log(`[plan] ${network}/${PKG} PackageInfo.git -> ${cfg.repoUrl} @ ${newCommit} (subdir ${cfg.gitSubdir})`)
    const outcome = await executeOrBuildBytes(tx, client, network, `${PKG}-update-git`)
    if (outcome.mode === 'executed') {
        pkgEntry.gitCommit = newCommit
        saveDeployments(deployments)
    }
}

main().catch((e) => {
    console.error(e)
    process.exit(1)
})
