import { ADMIN_KEYPAIR, BackdatingIssuance } from '../../src'
import { deploy } from '../../src/sdk/utils/deploy'
import { createTestToken, executeTxFunc } from '../test_utils'

const sender = ADMIN_KEYPAIR!.toSuiAddress()

describe('BackdatingIssuance Rule', () => {
    let tokenAddress: string
    let backdatingIssuance: BackdatingIssuance

    beforeAll(async () => {
        await deploy()
        tokenAddress = await createTestToken()
        backdatingIssuance = new BackdatingIssuance(tokenAddress)
    })

    describe('Rule Registration', () => {
        it('should register BackdatingIssuance rule with backdating allowed', async () => {
            await expect(backdatingIssuance.exists(sender)).resolves.toBe(false)

            await executeTxFunc(
                backdatingIssuance.register(sender, true)
            )

            await expect(backdatingIssuance.exists(sender)).resolves.toBe(true)
        })

        it('should unregister BackdatingIssuance rule', async () => {
            await expect(backdatingIssuance.exists(sender)).resolves.toBe(true)

            await executeTxFunc(backdatingIssuance.unregister(sender))

            await expect(backdatingIssuance.exists(sender)).resolves.toBe(false)
        })

        it('should register BackdatingIssuance with different flag values', async () => {
            const configs = [true, false]

            for (const disallowBackDating of configs) {
                await executeTxFunc(
                    backdatingIssuance.register(sender, disallowBackDating)
                )
                await expect(backdatingIssuance.exists(sender)).resolves.toBe(true)
                await executeTxFunc(backdatingIssuance.unregister(sender))
                await expect(backdatingIssuance.exists(sender)).resolves.toBe(false)
            }
        })

        it('should not allow registering BackdatingIssuance rule twice', async () => {
            await executeTxFunc(backdatingIssuance.register(sender, true))

            await expect(
                executeTxFunc(backdatingIssuance.register(sender, false))
            ).rejects.toThrow()

            await executeTxFunc(backdatingIssuance.unregister(sender))
        })
    })

    describe('PTB (Programmable Transaction Block) Methods', () => {
        it('should create PTB for registration with backdating allowed', async () => {
            const ptb = backdatingIssuance.registerPTB(true)
            expect(ptb).toBeDefined()
            expect(ptb.getData()).toBeDefined()
        })

        it('should create PTB for registration with backdating disallowed', async () => {
            const ptb = backdatingIssuance.registerPTB(false)
            expect(ptb).toBeDefined()
            expect(ptb.getData()).toBeDefined()
        })
    })

    describe('Rule Updates', () => {
        it('should be able to set the values', async () => {
            await executeTxFunc(backdatingIssuance.register(sender, false))

            await executeTxFunc(backdatingIssuance.setDisallowBackdating(true, sender))
            await expect(backdatingIssuance.exists(sender)).resolves.toBe(true)

            await executeTxFunc(backdatingIssuance.unregister(sender))
        })
    })

    describe('Edge Cases', () => {
        it('should handle undefined allow_backdating flag (defaults to false)', async () => {
            await executeTxFunc(
                backdatingIssuance.register(sender, undefined)
            )
            await expect(backdatingIssuance.exists(sender)).resolves.toBe(true)
            await executeTxFunc(backdatingIssuance.unregister(sender))
        })

        it('should register with backdating explicitly disabled', async () => {
            await executeTxFunc(
                backdatingIssuance.register(sender, false)
            )
            await expect(backdatingIssuance.exists(sender)).resolves.toBe(true)
            await executeTxFunc(backdatingIssuance.unregister(sender))
        })

        it('should register with backdating explicitly enabled', async () => {
            await executeTxFunc(
                backdatingIssuance.register(sender, true)
            )
            await expect(backdatingIssuance.exists(sender)).resolves.toBe(true)
            await executeTxFunc(backdatingIssuance.unregister(sender))
        })
    })
})
