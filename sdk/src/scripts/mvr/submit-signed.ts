import { readFileSync } from 'node:fs'
import { getNetwork, makeClient, requireEnv } from './_shared'

async function main() {
    const network = getNetwork()
    const bytesFile = requireEnv('BYTES_FILE')
    const sigFile = requireEnv('SIG_FILE')

    const transactionBlock = Buffer.from(readFileSync(bytesFile, 'utf8').trim(), 'base64')
    const signature = readFileSync(sigFile, 'utf8').trim()

    const client = makeClient(network)
    const result = await client.executeTransactionBlock({
        transactionBlock,
        signature,
        options: { showObjectChanges: true, showEffects: true, showEvents: true },
        requestType: 'WaitForLocalExecution',
    })

    if (result.effects?.status?.status !== 'success') {
        console.error('Transaction failed:', JSON.stringify(result.effects?.status, null, 2))
        process.exit(1)
    }

    console.log(`[ok] tx ${result.digest}`)
    const created = (result.objectChanges ?? []).filter((c) => c.type === 'created')
    if (created.length > 0) {
        console.log('Created objects:')
        for (const c of created) {
            const x = c as { objectType?: string; objectId?: string }
            console.log(`  ${x.objectType} -> ${x.objectId}`)
        }
    }
}

main().catch((e) => {
    console.error(e)
    process.exit(1)
})
