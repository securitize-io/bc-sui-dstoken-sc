import { Transaction } from '@mysten/sui/transactions'
import {
    executeOrBuildBytes,
    fetchUpgradeCapVersion,
    findCreated,
    getNetwork,
    loadConfig,
    makeClient,
    requireEnv,
} from './_shared'

const PKG = 'securitize'

// Full PackageInfo setup, in ONE PTB, for a package whose UpgradeCap is held by
// an arbitrary owner (e.g. the gamma testnet deployment, whose UpgradeCap is NOT
// the one tracked in deployments/<network>.json). The created PackageInfo is
// configured (git + display + reverse-resolution default) and kept by the
// sender — it is NOT handed to a separate custody/Safe. The owner only needs to
// share the resulting PackageInfo *id* with whoever holds the mainnet AppCap, so
// they can point the testnet network binding at it via set-network.ts.
//
// Required env:
//   CUSTODY_ADDRESS   sender / gas owner — MUST currently own UPGRADE_CAP_ID;
//                     the PackageInfo is transferred back to this same address.
//   UPGRADE_CAP_ID    the package's UpgradeCap object id (e.g. gamma 0x1cc383…)
//   GIT_COMMIT        permanent, public commit the published bytecode was built from
// Optional env:
//   DISPLAY_NAME      overrides the display label (defaults to mvr/<network>.json displayName)
//   SET_DEFAULT       "false" to skip the reverse-resolution default (defaults to set it)
//   GAS_BUDGET        defaults to 500000000
//
// Source repo/subdir and the MVR name come from mvr/<network>.json
// (repoUrl, gitSubdir, mvrName).
async function main() {
    const network = getNetwork()
    const cfg = loadConfig(network)
    const custody = requireEnv('CUSTODY_ADDRESS')
    const upgradeCapId = requireEnv('UPGRADE_CAP_ID')
    const gitCommit = requireEnv('GIT_COMMIT')
    const displayName = process.env.DISPLAY_NAME || cfg.displayName
    const setDefault = process.env.SET_DEFAULT !== 'false'
    const gasBudget = BigInt(process.env.GAS_BUDGET ?? '500000000')

    const client = makeClient(network)

    // The PackageInfo's git_versioning is keyed by the on-chain package version,
    // read off the UpgradeCap (1 for a fresh publish, +1 per upgrade).
    const upgradeCapVersion = await fetchUpgradeCapVersion(client, upgradeCapId)

    const tx = new Transaction()
    tx.setSender(custody)
    tx.setGasOwner(custody)
    tx.setGasBudget(gasBudget)

    // 1. Wrap the UpgradeCap in a fresh PackageInfo. The cap is &mut-borrowed,
    //    not consumed — it stays owned by `custody` for future upgrades.
    const packageInfo = tx.moveCall({
        target: '@mvr/metadata::package_info::new',
        arguments: [tx.object(upgradeCapId)],
    })

    // 2. Attach GitInfo — the on-chain pointer to the source that produced the
    //    published bytecode. repoUrl + subdir + commit must be permanent and public.
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
        arguments: [tx.pure.string(displayName)],
    })
    tx.moveCall({
        target: '@mvr/metadata::package_info::set_display',
        arguments: [packageInfo, display],
    })

    // 4. Reverse resolution: set "default" = the MVR name so explorers can turn
    //    this package address back into @securitize/dstoken. Done on the in-PTB
    //    PackageInfo value before it is transferred.
    if (setDefault) {
        tx.moveCall({
            target: '@mvr/metadata::package_info::set_metadata',
            arguments: [packageInfo, tx.pure.string('default'), tx.pure.string(cfg.mvrName)],
        })
    }

    // 5. Settle ownership — PackageInfo is freely transferable ONLY at creation,
    //    so it must be transferred in this PTB. We transfer to the sender itself:
    //    the gamma owner keeps it; there is no handoff to another address.
    tx.moveCall({
        target: '@mvr/metadata::package_info::transfer',
        arguments: [packageInfo, tx.pure.address(custody)],
    })

    console.log(
        `[plan] ${network}/${PKG} create PackageInfo for UpgradeCap ${upgradeCapId} (v${upgradeCapVersion}) -> ${cfg.repoUrl} @ ${gitCommit} (subdir ${cfg.gitSubdir}), display "${displayName}"${setDefault ? `, default ${cfg.mvrName}` : ''}, kept by ${custody}`,
    )

    const outcome = await executeOrBuildBytes(tx, client, network, `${PKG}-create-package-info`)
    if (outcome.mode === 'executed') {
        const pi = findCreated(outcome.result, '::package_info::PackageInfo')
        if (!pi) {
            console.error('No PackageInfo object was created. Inspect the transaction effects manually.')
            process.exit(1)
        }
        console.log(`[packageInfoId] ${pi.objectId}`)
        console.log(
            '     Share this id with the mainnet AppCap owner to finish the rebind — run set-network.ts with\n' +
                `     TARGET_PACKAGE_INFO_ID=${pi.objectId} TARGET_UPGRADE_CAP_ID=${upgradeCapId}`,
        )
    }
}

main().catch((e) => {
    console.error(e)
    process.exit(1)
})
