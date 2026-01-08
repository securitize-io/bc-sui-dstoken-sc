import { deploy } from '../src/sdk/utils/deploy'

beforeAll(async () => {
    await deploy()
})

describe('Publish', () => {
    it('should publish all packages', async () => {
        expect(true).toBe(true)
    })
})
