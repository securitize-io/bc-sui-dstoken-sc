import { ADMIN_KEYPAIR } from '../../src'
import { deploy } from '../../src/sdk/utils/deploy'
import { createTestToken, executeTxFunc } from '../test_utils'
import { LockupRestriction } from '../../src/sdk/rules/LockupRestriction'

const sender = ADMIN_KEYPAIR!.toSuiAddress()

describe('LockupRestriction Rule', () => {
    let tokenAddress: string
    let lockupRestriction: LockupRestriction

    beforeAll(async () => {
        await deploy()
        tokenAddress = await createTestToken()
        lockupRestriction = new LockupRestriction(tokenAddress)
    })

    describe('Rule Registration', () => {
        it('should register LockupRestriction rule with both lock periods', async () => {
            await expect(lockupRestriction.exists(sender)).resolves.toBe(false)

            const usLockPeriod = 31536000000 // 1 year in ms
            const nonUsLockPeriod = 15768000000 // 6 months in ms

            await executeTxFunc(
                lockupRestriction.register(sender, usLockPeriod, nonUsLockPeriod)
            )

            await expect(lockupRestriction.exists(sender)).resolves.toBe(true)
        })

        it('should unregister LockupRestriction rule', async () => {
            await expect(lockupRestriction.exists(sender)).resolves.toBe(true)

            await executeTxFunc(lockupRestriction.unregister(sender))

            await expect(lockupRestriction.exists(sender)).resolves.toBe(false)
        })

        it('should register LockupRestriction with different lock period combinations', async () => {
            const configs = [
                { us: 86400000, nonUs: 86400000 }, // 1 day each
                { us: 2592000000, nonUs: 5184000000 }, // 30 days, 60 days
                { us: 31536000000, nonUs: 63072000000 }, // 1 year, 2 years
            ]

            for (const config of configs) {
                await executeTxFunc(
                    lockupRestriction.register(sender, config.us, config.nonUs)
                )
                await expect(lockupRestriction.exists(sender)).resolves.toBe(true)
                await executeTxFunc(lockupRestriction.unregister(sender))
                await expect(lockupRestriction.exists(sender)).resolves.toBe(false)
            }
        })

        it('should not allow registering LockupRestriction rule twice', async () => {
            await executeTxFunc(lockupRestriction.register(sender, 1000, 2000))

            await expect(
                executeTxFunc(lockupRestriction.register(sender, 3000, 4000))
            ).rejects.toThrow()

            await executeTxFunc(lockupRestriction.unregister(sender))
        })
    })

    describe('PTB (Programmable Transaction Block) Methods', () => {
        it('should create PTB for registration', async () => {
            const ptb = lockupRestriction.registerPTB(1000000, 2000000)
            expect(ptb).toBeDefined()
            expect(ptb.blockData).toBeDefined()
        })
    })

    describe('Rule Updates', () => {
        it('should be able to set the values', async () => {
            await executeTxFunc(lockupRestriction.register(sender, 1000, 2000))

            await executeTxFunc(lockupRestriction.setUsLockPeriod(5000, sender))
            await executeTxFunc(lockupRestriction.setNonUsLockPeriod(5000, sender))
            await expect(lockupRestriction.exists(sender)).resolves.toBe(true)

            await executeTxFunc(lockupRestriction.unregister(sender))
        })
    })

    describe('Edge Cases', () => {
        it('should handle undefined lock periods (defaults to 0)', async () => {
            await executeTxFunc(
                lockupRestriction.register(sender, undefined, undefined)
            )
            await expect(lockupRestriction.exists(sender)).resolves.toBe(true)
            await executeTxFunc(lockupRestriction.unregister(sender))
        })

        it('should handle zero lock periods (no lockup)', async () => {
            await executeTxFunc(
                lockupRestriction.register(sender, 0, 0)
            )
            await expect(lockupRestriction.exists(sender)).resolves.toBe(true)
            await executeTxFunc(lockupRestriction.unregister(sender))
        })

        it('should handle only US lock period set', async () => {
            await executeTxFunc(
                lockupRestriction.register(sender, 31536000000, undefined)
            )
            await expect(lockupRestriction.exists(sender)).resolves.toBe(true)
            await executeTxFunc(lockupRestriction.unregister(sender))
        })

        it('should handle only non-US lock period set', async () => {
            await executeTxFunc(
                lockupRestriction.register(sender, undefined, 31536000000)
            )
            await expect(lockupRestriction.exists(sender)).resolves.toBe(true)
            await executeTxFunc(lockupRestriction.unregister(sender))
        })

        it('should handle different lock periods for US and non-US', async () => {
            await executeTxFunc(
                lockupRestriction.register(sender, 86400000, 172800000) // 1 day vs 2 days
            )
            await expect(lockupRestriction.exists(sender)).resolves.toBe(true)
            await executeTxFunc(lockupRestriction.unregister(sender))
        })
    })
})
