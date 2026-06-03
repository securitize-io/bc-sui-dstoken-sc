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

    const newTx = () => {
        const tx = new Transaction()
        tx.setSender(custody)
        tx.setGasOwner(custody)
        tx.setGasBudget(gasBudget)
        return tx
    }

    const addUnset = (tx: Transaction) =>
        tx.moveCall({
            target: '@mvr/core::move_registry::unset_metadata',
            arguments: [
                tx.object(cfg.mvrRegistryId),
                tx.object(appCapId),
                tx.pure.string(key),
            ],
        })

    const addSet = (tx: Transaction, v: string) =>
        tx.moveCall({
            target: '@mvr/core::move_registry::set_metadata',
            arguments: [
                tx.object(cfg.mvrRegistryId),
                tx.object(appCapId),
                tx.pure.string(key),
                tx.pure.string(v),
            ],
        })

    const dryRun = async (tx: Transaction) => {
        const bytes = await tx.build({ client })
        const res = await client.dryRunTransactionBlock({ transactionBlock: bytes })
        const status = res.effects?.status
        return { ok: status?.status === 'success', error: status?.error }
    }

    let tx: Transaction
    if (isUnset) {
        tx = newTx()
        addUnset(tx)
        console.log(`[plan] mainnet/${PKG} AppRecord.metadata[${key}] = (unset)`)
    } else {
        // MVR's set_metadata uses vec_map::insert (add-only): it aborts with
        // EKeyAlreadyExists if the key is already present. There is no update
        // entry function, so try a plain set first and fall back to an atomic
        // unset+set in a single PTB when the key already exists.
        const setTx = newTx()
        addSet(setTx, value!)
        const set = await dryRun(setTx)
        if (set.ok) {
            tx = setTx
            console.log(`[plan] mainnet/${PKG} AppRecord.metadata[${key}] = ${value} (new key)`)
        } else {
            const updateTx = newTx()
            addUnset(updateTx)
            addSet(updateTx, value!)
            const upd = await dryRun(updateTx)
            if (!upd.ok) {
                console.error(
                    'update-metadata: dry run failed for both set and unset+set.\n' +
                        `  set-only error:  ${set.error}\n` +
                        `  unset+set error: ${upd.error}`,
                )
                process.exit(1)
            }
            tx = updateTx
            console.log(
                `[plan] mainnet/${PKG} AppRecord.metadata[${key}] = ${value} (replacing existing)`,
            )
        }
    }

    await executeOrBuildBytes(tx, client, 'mainnet', `${PKG}-metadata-${key}`)
}

main().catch((e) => {
    console.error(e)
    process.exit(1)
})
