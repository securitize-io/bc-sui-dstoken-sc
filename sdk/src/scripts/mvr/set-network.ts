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

// Rebind (or create) the AppInfo for an external network on the mainnet AppRecord.
// MVR resolution for a non-mainnet network returns the AppInfo.package_address
// stored under its chain-id in the mainnet AppRecord's `networks` map. The whole
// `networks` map is gated by the mainnet AppCap, so this is always a mainnet tx.
//
// Required env:
//   CUSTODY_ADDRESS         AppCap owner (sender / gas owner)
//   TARGET_CHAIN_ID         chain identifier of the network to (re)bind (e.g. testnet = 4c78adac)
//   TARGET_PACKAGE_ADDRESS  package address consumers should resolve to on that network
// Optional env (recommended — populate when known):
//   TARGET_PACKAGE_INFO_ID  PackageInfo object id on that network (source/git/display)
//   TARGET_UPGRADE_CAP_ID   UpgradeCap object id on that network
async function main() {
    const network = getNetwork()
    if (network !== 'mainnet') {
        console.error(
            `set-network: network bindings live on the mainnet AppRecord — got NETWORK=${network}.`,
        )
        process.exit(1)
    }

    const cfg = loadConfig('mainnet')
    const custody = requireEnv('CUSTODY_ADDRESS')
    const chainId = requireEnv('TARGET_CHAIN_ID')
    const packageAddress = requireEnv('TARGET_PACKAGE_ADDRESS')
    const packageInfoId = process.env.TARGET_PACKAGE_INFO_ID || null
    const upgradeCapId = process.env.TARGET_UPGRADE_CAP_ID || null
    const gasBudget = BigInt(process.env.GAS_BUDGET ?? '100000000')

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

    const client = makeClient('mainnet')

    const newTx = () => {
        const tx = new Transaction()
        tx.setSender(custody)
        tx.setGasOwner(custody)
        tx.setGasBudget(gasBudget)
        return tx
    }

    const addSet = (tx: Transaction) => {
        // app_info::new(Option<ID> package_info_id, Option<address> package_address, Option<ID> upgrade_cap_id)
        const appInfo = tx.moveCall({
            target: '@mvr/core::app_info::new',
            arguments: [
                tx.pure.option('id', packageInfoId),
                tx.pure.option('address', packageAddress),
                tx.pure.option('id', upgradeCapId),
            ],
        })
        tx.moveCall({
            target: '@mvr/core::move_registry::set_network',
            arguments: [
                tx.object(cfg.mvrRegistryId),
                tx.object(appCapId),
                tx.pure.string(chainId),
                appInfo,
            ],
        })
    }

    const addUnset = (tx: Transaction) =>
        tx.moveCall({
            target: '@mvr/core::move_registry::unset_network',
            arguments: [tx.object(cfg.mvrRegistryId), tx.object(appCapId), tx.pure.string(chainId)],
        })

    const dryRun = async (tx: Transaction) => {
        const bytes = await tx.build({ client })
        const res = await client.dryRunTransactionBlock({ transactionBlock: bytes })
        const status = res.effects?.status
        return { ok: status?.status === 'success', error: status?.error }
    }

    const summary = `chain ${chainId} -> ${packageAddress} (packageInfo ${packageInfoId ?? 'none'}, upgradeCap ${upgradeCapId ?? 'none'})`

    // move_registry::set_network uses vec_map::insert (add-only): rebinding an
    // already-present chain-id aborts. Try a plain set first (new network), then
    // fall back to an atomic unset+set in one PTB (re-bind existing network).
    let tx = newTx()
    addSet(tx)
    const set = await dryRun(tx)
    if (set.ok) {
        console.log(`[plan] mainnet/${PKG} AppRecord.networks[${summary}] (new network)`)
    } else {
        tx = newTx()
        addUnset(tx)
        addSet(tx)
        const upd = await dryRun(tx)
        if (!upd.ok) {
            console.error(
                'set-network: dry run failed for both set and unset+set.\n' +
                    `  set-only error:  ${set.error}\n` +
                    `  unset+set error: ${upd.error}`,
            )
            process.exit(1)
        }
        console.log(`[plan] mainnet/${PKG} AppRecord.networks[${summary}] (rebinding existing)`)
    }

    await executeOrBuildBytes(tx, client, 'mainnet', `${PKG}-set-network-${chainId}`)
}

main().catch((e) => {
    console.error(e)
    process.exit(1)
})
