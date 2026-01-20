import { ADMIN_KEYPAIR, AccreditedOnly } from '../../src'
import { deploy } from '../../src/sdk/utils/deploy'
import { createTestToken, executeTxFunc } from '../test_utils'

const sender = ADMIN_KEYPAIR!.toSuiAddress()

describe('AccreditedOnly Rule', () => {
    let tokenAddress: string
    let accreditedOnly: AccreditedOnly

    beforeAll(async () => {
        await deploy()
        tokenAddress = await createTestToken()
        accreditedOnly = new AccreditedOnly(tokenAddress)
    })

    describe('Rule Registration', () => {
        it('should register AccreditedOnly rule with both flags true', async () => {
            await expect(accreditedOnly.exists(sender)).resolves.toBe(false)

            await executeTxFunc(
                accreditedOnly.register(sender, true, true)
            )

            await expect(accreditedOnly.exists(sender)).resolves.toBe(true)
        })

        it('should unregister AccreditedOnly rule', async () => {
            await expect(accreditedOnly.exists(sender)).resolves.toBe(true)

            await executeTxFunc(accreditedOnly.unregister(sender))

            await expect(accreditedOnly.exists(sender)).resolves.toBe(false)
        })

        it('should register AccreditedOnly with different flag combinations', async () => {
            const configs = [
                { forceAccredited: true, forceUsAccredited: false },
                { forceAccredited: false, forceUsAccredited: true },
                { forceAccredited: false, forceUsAccredited: false },
            ]

            for (const config of configs) {
                await executeTxFunc(
                    accreditedOnly.register(
                        sender,
                        config.forceAccredited,
                        config.forceUsAccredited
                    )
                )
                await expect(accreditedOnly.exists(sender)).resolves.toBe(true)
                await executeTxFunc(accreditedOnly.unregister(sender))
                await expect(accreditedOnly.exists(sender)).resolves.toBe(false)
            }
        })

        it('should not allow registering AccreditedOnly rule twice', async () => {
            await executeTxFunc(accreditedOnly.register(sender, true, true))

            await expect(
                executeTxFunc(accreditedOnly.register(sender, false, false))
            ).rejects.toThrow()

            await executeTxFunc(accreditedOnly.unregister(sender))
        })
    })

    describe('PTB (Programmable Transaction Block) Methods', () => {
        it('should create PTB for registration', async () => {
            const ptb = accreditedOnly.registerPTB(true, true)
            expect(ptb).toBeDefined()
            expect(ptb.blockData).toBeDefined()
        })
    })

    describe('Rule Updates', () => {
        it('should be able to set the values', async () => {
            await executeTxFunc(accreditedOnly.register(sender, false, false))

            await executeTxFunc(accreditedOnly.setForceAccredited(true, sender))
            await executeTxFunc(accreditedOnly.setForceUsAccredited(true, sender))
            await expect(accreditedOnly.exists(sender)).resolves.toBe(true)

            await executeTxFunc(accreditedOnly.unregister(sender))
        })
    })

    describe('Edge Cases', () => {
        it('should handle undefined flags (defaults to false)', async () => {
            await executeTxFunc(
                accreditedOnly.register(sender, undefined, undefined)
            )
            await expect(accreditedOnly.exists(sender)).resolves.toBe(true)
            await executeTxFunc(accreditedOnly.unregister(sender))
        })

        it('should handle registering with only forceAccredited flag', async () => {
            await executeTxFunc(
                accreditedOnly.register(sender, true, undefined)
            )
            await expect(accreditedOnly.exists(sender)).resolves.toBe(true)
            await executeTxFunc(accreditedOnly.unregister(sender))
        })

        it('should handle registering with only forceUsAccredited flag', async () => {
            await executeTxFunc(
                accreditedOnly.register(sender, undefined, true)
            )
            await expect(accreditedOnly.exists(sender)).resolves.toBe(true)
            await executeTxFunc(accreditedOnly.unregister(sender))
        })
    })
})
