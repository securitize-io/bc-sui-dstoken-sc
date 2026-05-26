import { Transaction } from '@mysten/sui/transactions'
import {
    executeOrBuildBytes,
    fetchUpgradeCapVersion,
    findCreated,
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
    const deployments = loadDeployments(network)
    const custody = requireEnv('CUSTODY_ADDRESS')
    const gitCommit = requireEnv('GIT_COMMIT')
    const gasBudget = BigInt(process.env.GAS_BUDGET ?? '500000000')

    const pkgEntry = deployments.packages[PKG]
    if (!pkgEntry?.upgradeCapId) {
        console.error(
            `deployments/${network}.json is missing packages.${PKG}.upgradeCapId — publish the package first and copy the IDs in.`,
        )
        process.exit(1)
    }

    const client = makeClient(network)
    const upgradeCapVersion = await fetchUpgradeCapVersion(client, pkgEntry.upgradeCapId)

    const tx = new Transaction()
    tx.setSender(custody)
    tx.setGasOwner(custody)
    tx.setGasBudget(gasBudget)

    // 1. Wrap the UpgradeCap in a fresh PackageInfo. After this call, the UpgradeCap
    //    lives inside the PackageInfo and is no longer directly accessible.
    const packageInfo = tx.moveCall({
        target: '@mvr/metadata::package_info::new',
        arguments: [tx.object(pkgEntry.upgradeCapId)],
    })

    // 2. Attach GitInfo — the on-chain pointer to the source code that produced
    //    the published bytecode. repoUrl + subdir + commit must be permanent and public.
    const gitInfo = tx.moveCall({
        target: '@mvr/metadata::git::new',
        arguments: [
            tx.pure.string(cfg.repoUrl),
            tx.pure.string(cfg.gitSubdir),
            tx.pure.string(gitCommit),
        ],
    })
    tx.moveCall({
        target: '@mvr/metadata::package_info::set_git_versioning',
        arguments: [packageInfo, tx.pure.u64(upgradeCapVersion), gitInfo],
    })

    // 3. Attach a Display for nicer presentation in explorers / MVR UIs.
    const display = tx.moveCall({
        target: '@mvr/metadata::display::default',
        arguments: [tx.pure.string(cfg.displayName)],
    })
    tx.moveCall({
        target: '@mvr/metadata::package_info::set_display',
        arguments: [packageInfo, display],
    })

    // 4. Transfer to custody — this is the ONLY time PackageInfo is freely transferable.
    //    Subsequent moves require calling @mvr/metadata::package_info::transfer from the holder.
    tx.moveCall({
        target: '@mvr/metadata::package_info::transfer',
        arguments: [packageInfo, tx.pure.address(custody)],
    })

    const outcome = await executeOrBuildBytes(tx, client, network, `${PKG}-create-package-info`)
    if (outcome.mode === 'executed') {
        const pi = findCreated(outcome.result, '::package_info::PackageInfo')
        if (!pi) {
            console.error('No PackageInfo object was created. Inspect the transaction effects manually.')
            process.exit(1)
        }
        console.log(`[packageInfoId] ${pi.objectId}`)
        pkgEntry.packageInfoId = pi.objectId
        pkgEntry.gitCommit = gitCommit
        saveDeployments(deployments)
    }
}

main().catch((e) => {
    console.error(e)
    process.exit(1)
})
