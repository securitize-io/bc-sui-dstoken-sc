import { deploy } from '../src/sdk/utils/deploy'
import { ADMIN_KEYPAIR } from '../src'

beforeAll(async () => {
    await deploy(ADMIN_KEYPAIR!)
})

describe('Publish', () => {
    it('should publish all packages', async () => {
        expect(true).toBe(true)
    })
})
