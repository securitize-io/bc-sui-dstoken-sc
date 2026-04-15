import { PublishSingleton } from '../src'

const network = process.env.NETWORK ?? 'localnet'
if (network === 'testnet' || network === 'mainnet') {
    throw new Error(`Tests are disabled on ${network}. Only run tests on localnet or devnet.`)
}

beforeAll(async () => {
    PublishSingleton.cleanPubFile()
})
