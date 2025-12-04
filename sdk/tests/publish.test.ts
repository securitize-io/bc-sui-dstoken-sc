import { deploy } from '../src/sdk/utils/deploy'

beforeAll(async () => {
    // Publish all packages through volora contract
    await deploy()
})

describe('Publish', () => {
    it('should publish all packages', async () => {
        expect(true).toBe(true)
    })
})
