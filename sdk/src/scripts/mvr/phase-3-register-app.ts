import { Transaction } from '@mysten/sui/transactions'
import {
    executeOrBuildBytes,
    findCreated,
    getNetwork,
    loadConfig,
    loadDeployments,
    makeClient,
    requireEnv,
    saveDeployments,
} from './_shared'

const PKG = 'securitize'
const TESTNET_CHAIN_ID = '4c78adac'

async function main() {
    const network = getNetwork()
    if (network !== 'mainnet') {
        console.error(
            `Phase 3 (MVR app registration) can only run on mainnet — the MVR registry is mainnet-only. Got NETWORK=${network}.`,
        )
        process.exit(1)
    }
    const cfg = loadConfig('mainnet')
    const custody = requireEnv('CUSTODY_ADDRESS')
    const gasBudget = BigInt(process.env.GAS_BUDGET ?? '500000000')

    if (!cfg.suinsNftId || cfg.suinsNftId.startsWith('FILL_IN')) {
        console.error('mvr/mainnet.json: suinsNftId is not set.')
        process.exit(1)
    }
    if (!cfg.mvrRegistryId || cfg.mvrRegistryId.startsWith('FILL_IN')) {
        console.error('mvr/mainnet.json: mvrRegistryId is not set.')
        process.exit(1)
    }

    const mainnetDeployments = loadDeployments('mainnet')
    const testnetDeployments = loadDeployments('testnet')
    const mainnetPkgInfo = mainnetDeployments.packages[PKG]?.packageInfoId
    const testnetPkgInfo = testnetDeployments.packages[PKG]?.packageInfoId
    if (!mainnetPkgInfo) {
        console.error('deployments/mainnet.json: packages.securitize.packageInfoId missing — run phase-2 on mainnet first.')
        process.exit(1)
    }
    if (!testnetPkgInfo) {
        console.error(
            'deployments/testnet.json: packages.securitize.packageInfoId missing — run phase-2 on testnet so we can bind it here.',
        )
        process.exit(1)
    }

    // The mvrName looks like "@<suins>/<pkg>" — register() takes the bare app name.
    const appName = cfg.mvrName.replace(/^@[^/]+\//, '')

    const client = makeClient('mainnet')

    const tx = new Transaction()
    tx.setSender(custody)
    tx.setGasOwner(custody)
    tx.setGasBudget(gasBudget)

    // 1. Register the MVR app and capture the AppCap.
    const appCap = tx.moveCall({
        target: '@mvr/core::move_registry::register',
        arguments: [
            tx.object(cfg.mvrRegistryId),
            tx.object(cfg.suinsNftId),
            tx.pure.string(appName),
            tx.object('0x6'), // Clock
        ],
    })

    // 2. Populate metadata.
    const entries: [string, string][] = [
        ['description', cfg.metadata.description],
        ['homepage_url', cfg.metadata.homepage_url],
        ['documentation_url', cfg.metadata.documentation_url],
        ['icon_url', cfg.metadata.icon_url],
        ['contact', cfg.metadata.contact],
    ]
    for (const [k, v] of entries) {
        tx.moveCall({
            target: '@mvr/core::move_registry::set_metadata',
            arguments: [
                tx.object(cfg.mvrRegistryId),
                appCap,
                tx.pure.string(k),
                tx.pure.string(v),
            ],
        })
    }

    // 3. Bind mainnet PackageInfo — PERMANENT.
    tx.moveCall({
        target: '@mvr/core::move_registry::assign_package',
        arguments: [
            tx.object(cfg.mvrRegistryId),
            appCap,
            tx.object(mainnetPkgInfo),
        ],
    })

    // 4. Bind testnet PackageInfo by chain ID. Reversible later via unset_network/set_network.
    //
    // NOTE: set_network takes an AppInfo struct, not a PackageInfo. We construct
    // it on-chain via @mvr/core::app_info::new(Option<ID>, Option<address>, Option<ID>).
    // The 3 fields are (package_info_id, package_address, upgrade_cap_id).
    // package_address and upgrade_cap_id are optional but we populate them when
    // available from the testnet deployment for a richer record.
    const testnetPkgEntry = testnetDeployments.packages[PKG] ?? {}
    const testnetAppInfo = tx.moveCall({
        target: '@mvr/core::app_info::new',
        arguments: [
            tx.pure.option('id', testnetPkgInfo),                                // package_info_id: Option<ID>
            tx.pure.option('address', testnetPkgEntry.packageId ?? null),        // package_address: Option<address>
            tx.pure.option('id', testnetPkgEntry.upgradeCapId ?? null),          // upgrade_cap_id: Option<ID>
        ],
    })
    tx.moveCall({
        target: '@mvr/core::move_registry::set_network',
        arguments: [
            tx.object(cfg.mvrRegistryId),
            appCap,
            tx.pure.string(TESTNET_CHAIN_ID),
            testnetAppInfo,
        ],
    })

    // 5. Transfer AppCap to custody.
    tx.transferObjects([appCap], tx.pure.address(custody))

    const outcome = await executeOrBuildBytes(tx, client, 'mainnet', `${PKG}-register`)
    if (outcome.mode === 'executed') {
        const cap = findCreated(outcome.result, '::app_record::AppCap')
        if (!cap) {
            console.error('No AppCap object was created. Inspect the transaction effects manually.')
            process.exit(1)
        }
        console.log(`[appCapId] ${cap.objectId}`)
        const entry = (mainnetDeployments.packages[PKG] ??= {})
        entry.appCapId = cap.objectId
        saveDeployments(mainnetDeployments)
    }
}

main().catch((e) => {
    console.error(e)
    process.exit(1)
})
