import { ADMIN_KEYPAIR, Regions, HoldingLimits } from '../../src'
import { deploy } from '../../src/sdk/utils/deploy'
import { createTestToken, executeTxFunc } from '../test_utils'

const sender = ADMIN_KEYPAIR!.toSuiAddress()

describe('HoldingLimits Rule', () => {
    let tokenAddress: string
    let holdingLimits: HoldingLimits

    beforeAll(async () => {
        await deploy(ADMIN_KEYPAIR!)
        tokenAddress = await createTestToken()
        holdingLimits = new HoldingLimits(tokenAddress)
    })

    describe('Rule Registration', () => {
        it('should register HoldingLimits rule with US and EU regions', async () => {
            await expect(holdingLimits.exists(sender)).resolves.toBe(false)

            await executeTxFunc(
                holdingLimits.register(
                    sender,
                    100n,        // min holdings per investor
                    1000000n,    // max holdings per investor
                    500n,        // minUSTokens
                    300n         // minEUTokens
                )
            )

            await expect(holdingLimits.exists(sender)).resolves.toBe(true)
        })

        it('should unregister HoldingLimits rule', async () => {
            await expect(holdingLimits.exists(sender)).resolves.toBe(true)

            await executeTxFunc(holdingLimits.unregister(sender))

            await expect(holdingLimits.exists(sender)).resolves.toBe(false)
        })

        it('should register HoldingLimits with different configurations', async () => {
            const configs = [
                { min: 0n, max: 500000n, minUS: 100n, minEU: 200n },
                { min: 1000n, max: 2000000n, minUS: 1000n, minEU: 1500n },
                { min: 50n, max: 100000n, minUS: 50n, minEU: 75n },
            ]

            for (const config of configs) {
                await executeTxFunc(
                    holdingLimits.register(
                        sender,
                        config.min,
                        config.max,
                        config.minUS,
                        config.minEU
                    )
                )
                await expect(holdingLimits.exists(sender)).resolves.toBe(true)
                await executeTxFunc(holdingLimits.unregister(sender))
                await expect(holdingLimits.exists(sender)).resolves.toBe(false)
            }
        })

        it('should register HoldingLimits with only US region', async () => {
            await executeTxFunc(
                holdingLimits.register(
                    sender,
                    100n,
                    500000n,
                    1000n        // only US min (no EU min)
                )
            )
            await expect(holdingLimits.exists(sender)).resolves.toBe(true)
            await executeTxFunc(holdingLimits.unregister(sender))
        })

        it('should register HoldingLimits with only EU region', async () => {
            await executeTxFunc(
                holdingLimits.register(
                    sender,
                    100n,
                    500000n,
                    undefined,  // no US min
                    2000n        // only EU min
                )
            )
            await expect(holdingLimits.exists(sender)).resolves.toBe(true)
            await executeTxFunc(holdingLimits.unregister(sender))
        })

        it('should not allow registering HoldingLimits rule twice', async () => {
            await executeTxFunc(holdingLimits.register(sender, 100n, 1000000n, 500n, 300n))

            await expect(
                executeTxFunc(holdingLimits.register(sender, 200n, 2000000n, 600n, 400n))
            ).rejects.toThrow()

            await executeTxFunc(holdingLimits.unregister(sender))
        })
    })

    describe('PTB (Programmable Transaction Block) Methods', () => {
        it('should create PTB for registration', async () => {
            const ptb = holdingLimits.registerPTB(100n, 1000000n, 500n, 300n)
            expect(ptb).toBeDefined()
            expect(ptb.getData()).toBeDefined()
        })
    })

    describe('Rule Updates', () => {
        it('should be able to set the values', async () => {
            await executeTxFunc(holdingLimits.register(sender, 100n, 1000000n, 500n, 300n))

            await executeTxFunc(holdingLimits.setMinHoldings(200n, sender))
            await executeTxFunc(holdingLimits.setMaxHoldings(2000000n, sender))
            await executeTxFunc(holdingLimits.setRegionMinHoldings(Regions.US, 1000n, sender))
            await executeTxFunc(holdingLimits.setRegionMinHoldings(Regions.EU, 800n, sender))
            await expect(holdingLimits.exists(sender)).resolves.toBe(true)

            await executeTxFunc(holdingLimits.unregister(sender))
        })
    })

    describe('Edge Cases', () => {
        it('should handle HoldingLimits with zero minimums', async () => {
            await executeTxFunc(
                holdingLimits.register(
                    sender,
                    0n,          // zero min holdings
                    1000000n,    // max holdings
                    0n,          // zero US min
                    0n           // zero EU min
                )
            )
            await expect(holdingLimits.exists(sender)).resolves.toBe(true)
            await executeTxFunc(holdingLimits.unregister(sender))
        })

        it('should handle HoldingLimits with no region minimums', async () => {
            await executeTxFunc(
                holdingLimits.register(
                    sender,
                    100n,
                    500000n
                    // no US or EU minimums specified
                )
            )
            await expect(holdingLimits.exists(sender)).resolves.toBe(true)
            await executeTxFunc(holdingLimits.unregister(sender))
        })

        it('should handle very large holding limits', async () => {
            await executeTxFunc(
                holdingLimits.register(
                    sender,
                    1000n,
                    1000000000n, // very large max
                    100000n,     // large US min
                    100000n      // large EU min
                )
            )
            await expect(holdingLimits.exists(sender)).resolves.toBe(true)
            await executeTxFunc(holdingLimits.unregister(sender))
        })

        it('should handle equal min and max values', async () => {
            await executeTxFunc(
                holdingLimits.register(
                    sender,
                    1000n,
                    1000n,       // min equals max
                    500n,
                    500n
                )
            )
            await expect(holdingLimits.exists(sender)).resolves.toBe(true)
            await executeTxFunc(holdingLimits.unregister(sender))
        })

        it('should handle undefined optional parameters', async () => {
            await executeTxFunc(
                holdingLimits.register(
                    sender,
                    100n,
                    500000n,
                    undefined,
                    undefined
                )
            )
            await expect(holdingLimits.exists(sender)).resolves.toBe(true)
            await executeTxFunc(holdingLimits.unregister(sender))
        })
    })
})
