import { ADMIN_KEYPAIR } from '../../src'
import { deploy } from '../../src/sdk/utils/deploy'
import { createTestToken, executeTxFunc } from '../test_utils'
import { ForceFullTransfer } from '../../src/sdk/rules/ForceFullTransfer'

const sender = ADMIN_KEYPAIR!.toSuiAddress()

describe('ForceFullTransfer Rule', () => {
    let tokenAddress: string
    let forceFullTransfer: ForceFullTransfer

    beforeAll(async () => {
        await deploy()
        tokenAddress = await createTestToken()
        forceFullTransfer = new ForceFullTransfer(tokenAddress)
    })

    describe('Rule Registration', () => {
        it('should register ForceFullTransfer rule with both flags true', async () => {
            await expect(forceFullTransfer.exists(sender)).resolves.toBe(false)

            await executeTxFunc(
                forceFullTransfer.register(sender, true, true)
            )

            await expect(forceFullTransfer.exists(sender)).resolves.toBe(true)
        })

        it('should unregister ForceFullTransfer rule', async () => {
            await expect(forceFullTransfer.exists(sender)).resolves.toBe(true)

            await executeTxFunc(forceFullTransfer.unregister(sender))

            await expect(forceFullTransfer.exists(sender)).resolves.toBe(false)
        })

        it('should register ForceFullTransfer with different flag combinations', async () => {
            const configs = [
                { forceUs: true, forceWorldwide: false },
                { forceUs: false, forceWorldwide: true },
                { forceUs: false, forceWorldwide: false },
            ]

            for (const config of configs) {
                await executeTxFunc(
                    forceFullTransfer.register(
                        sender,
                        config.forceUs,
                        config.forceWorldwide
                    )
                )
                await expect(forceFullTransfer.exists(sender)).resolves.toBe(true)
                await executeTxFunc(forceFullTransfer.unregister(sender))
                await expect(forceFullTransfer.exists(sender)).resolves.toBe(false)
            }
        })

        it('should not allow registering ForceFullTransfer rule twice', async () => {
            await executeTxFunc(forceFullTransfer.register(sender, true, true))

            await expect(
                executeTxFunc(forceFullTransfer.register(sender, false, false))
            ).rejects.toThrow()

            await executeTxFunc(forceFullTransfer.unregister(sender))
        })
    })

    describe('PTB (Programmable Transaction Block) Methods', () => {
        it('should create PTB for registration', async () => {
            const ptb = forceFullTransfer.registerPTB(true, true)
            expect(ptb).toBeDefined()
            expect(ptb.blockData).toBeDefined()
        })
    })

    describe('Rule Updates', () => {
        it('should be able to set the values', async () => {
            await executeTxFunc(forceFullTransfer.register(sender, false, false))

            await executeTxFunc(forceFullTransfer.setForceUs(true, sender))
            await executeTxFunc(forceFullTransfer.setForceWorldwide(true, sender))
            await expect(forceFullTransfer.exists(sender)).resolves.toBe(true)

            await executeTxFunc(forceFullTransfer.unregister(sender))
        })
    })

    describe('Edge Cases', () => {
        it('should handle undefined flags (defaults to false)', async () => {
            await executeTxFunc(
                forceFullTransfer.register(sender, undefined, undefined)
            )
            await expect(forceFullTransfer.exists(sender)).resolves.toBe(true)
            await executeTxFunc(forceFullTransfer.unregister(sender))
        })

        it('should handle registering with only forceUs flag', async () => {
            await executeTxFunc(
                forceFullTransfer.register(sender, true, undefined)
            )
            await expect(forceFullTransfer.exists(sender)).resolves.toBe(true)
            await executeTxFunc(forceFullTransfer.unregister(sender))
        })

        it('should handle registering with only forceWorldwide flag', async () => {
            await executeTxFunc(
                forceFullTransfer.register(sender, undefined, true)
            )
            await expect(forceFullTransfer.exists(sender)).resolves.toBe(true)
            await executeTxFunc(forceFullTransfer.unregister(sender))
        })

        it('should allow both US and worldwide flags to be true simultaneously', async () => {
            await executeTxFunc(
                forceFullTransfer.register(sender, true, true)
            )
            await expect(forceFullTransfer.exists(sender)).resolves.toBe(true)
            await executeTxFunc(forceFullTransfer.unregister(sender))
        })
    })
})
