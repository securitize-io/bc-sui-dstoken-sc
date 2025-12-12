import {createTestToken} from "./test_utils";
import {deploy} from "../src/sdk/utils/deploy";

describe('Ds token', () => {
    let tokenAddress: string

    beforeAll(async () => {
        await deploy()
        tokenAddress = await createTestToken()
        expect(tokenAddress).not.toBe('')
    })

    it('Simple flow', async () => {
        console.log('Token address:', tokenAddress)
    })
})
