import {create_ds_token} from "../src/sdk/ds_token";

/**
 * Integration tests for Ds token module.
 */
describe('Ds token', () => {
    let treasury: string

    // ----------- Global setup -----------
    beforeAll(async () => {
        treasury = await create_ds_token()
        expect(treasury).not.toBe('')
    })

    // -------------- Test --------------
    it('Simple flow', async () => {
        console.log('Treasury:', treasury)
    })
})
