import { ADMIN_KEYPAIR, FlowbackRestriction } from '../../src'
import { deploy } from '../../src/sdk/utils/deploy'
import { createTestToken, executeTxFunc } from '../test_utils'

const sender = ADMIN_KEYPAIR!.toSuiAddress()

describe('FlowbackRestriction Rule', () => {
    let tokenAddress: string
    let flowbackRestriction: FlowbackRestriction

    beforeAll(async () => {
        await deploy()
        tokenAddress = await createTestToken()
        flowbackRestriction = new FlowbackRestriction(tokenAddress)
    })

    describe('Rule Registration', () => {
        it('should register FlowbackRestriction rule with end time', async () => {
            await expect(flowbackRestriction.exists(sender)).resolves.toBe(false)

            const endTime = Date.now() + 365 * 24 * 60 * 60 * 1000 // 1 year from now
            await executeTxFunc(
                flowbackRestriction.register(sender, endTime)
            )

            await expect(flowbackRestriction.exists(sender)).resolves.toBe(true)
        })

        it('should unregister FlowbackRestriction rule', async () => {
            await expect(flowbackRestriction.exists(sender)).resolves.toBe(true)

            await executeTxFunc(flowbackRestriction.unregister(sender))

            await expect(flowbackRestriction.exists(sender)).resolves.toBe(false)
        })

        it('should register FlowbackRestriction with different end times', async () => {
            const endTimes = [
                Date.now() + 30 * 24 * 60 * 60 * 1000,  // 30 days
                Date.now() + 90 * 24 * 60 * 60 * 1000,  // 90 days
                Date.now() + 180 * 24 * 60 * 60 * 1000, // 180 days
            ]

            for (const endTime of endTimes) {
                await executeTxFunc(
                    flowbackRestriction.register(sender, endTime)
                )
                await expect(flowbackRestriction.exists(sender)).resolves.toBe(true)
                await executeTxFunc(flowbackRestriction.unregister(sender))
                await expect(flowbackRestriction.exists(sender)).resolves.toBe(false)
            }
        })

        it('should register FlowbackRestriction with no end time (defaults to 0)', async () => {
            await executeTxFunc(
                flowbackRestriction.register(sender)
            )
            await expect(flowbackRestriction.exists(sender)).resolves.toBe(true)
            await executeTxFunc(flowbackRestriction.unregister(sender))
        })

        it('should not allow registering FlowbackRestriction rule twice', async () => {
            const endTime = Date.now() + 365 * 24 * 60 * 60 * 1000
            await executeTxFunc(flowbackRestriction.register(sender, endTime))

            await expect(
                executeTxFunc(flowbackRestriction.register(sender, endTime))
            ).rejects.toThrow()

            await executeTxFunc(flowbackRestriction.unregister(sender))
        })
    })

    describe('PTB (Programmable Transaction Block) Methods', () => {
        it('should create PTB for registration', async () => {
            const endTime = Date.now() + 365 * 24 * 60 * 60 * 1000
            const ptb = flowbackRestriction.registerPTB(endTime)
            expect(ptb).toBeDefined()
            expect(ptb.getData()).toBeDefined()
        })
    })

    describe('Rule Updates', () => {
        it('should be able to set the values', async () => {
            const initialEndTime = Date.now() + 30 * 24 * 60 * 60 * 1000
            await executeTxFunc(flowbackRestriction.register(sender, initialEndTime))

            const newEndTime = Date.now() + 90 * 24 * 60 * 60 * 1000
            await executeTxFunc(flowbackRestriction.setFlowbackEndTime(newEndTime, sender))
            await expect(flowbackRestriction.exists(sender)).resolves.toBe(true)

            await executeTxFunc(flowbackRestriction.unregister(sender))
        })
    })

    describe('Edge Cases', () => {
        it('should handle zero end time', async () => {
            await executeTxFunc(
                flowbackRestriction.register(sender, 0)
            )
            await expect(flowbackRestriction.exists(sender)).resolves.toBe(true)
            await executeTxFunc(flowbackRestriction.unregister(sender))
        })

        it('should handle very large end time values', async () => {
            const veryFarFuture = Date.now() + 100 * 365 * 24 * 60 * 60 * 1000 // 100 years
            await executeTxFunc(
                flowbackRestriction.register(sender, veryFarFuture)
            )
            await expect(flowbackRestriction.exists(sender)).resolves.toBe(true)
            await executeTxFunc(flowbackRestriction.unregister(sender))
        })

        it('should handle past end time', async () => {
            const pastTime = Date.now() - 365 * 24 * 60 * 60 * 1000 // 1 year ago
            await executeTxFunc(
                flowbackRestriction.register(sender, pastTime)
            )
            await expect(flowbackRestriction.exists(sender)).resolves.toBe(true)
            await executeTxFunc(flowbackRestriction.unregister(sender))
        })
    })
})
