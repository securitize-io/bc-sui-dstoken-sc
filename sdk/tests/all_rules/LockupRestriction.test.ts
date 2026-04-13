import { ADMIN_KEYPAIR, LockupRestriction, DSToken, Investors, CountryCompliance, BackdatingIssuance, createFundedWallet } from '../../src'
import { deploy } from '../../src/sdk/utils/deploy'
import { createTestToken, executeTxFunc, complianceRules, registerInvestor } from '../test_utils'
import { Keypair } from '@mysten/sui/cryptography'

const sender = ADMIN_KEYPAIR!.toSuiAddress()

describe('LockupRestriction Rule', () => {
    let tokenAddress: string
    let lockupRestriction: LockupRestriction
    let dsToken: DSToken
    let euInvestorKP: Keypair

    beforeAll(async () => {
        await deploy(ADMIN_KEYPAIR!)
        tokenAddress = await createTestToken()
        lockupRestriction = new LockupRestriction(tokenAddress)
        dsToken = new DSToken(tokenAddress)

        // Set up country compliance
        const countryCompliance = new CountryCompliance(tokenAddress)
        await executeTxFunc(countryCompliance.set(sender, 'US', 'us'))
        await executeTxFunc(countryCompliance.set(sender, 'GR', 'eu'))

        // Allow backdating issuances (needed for compute transferable tokens tests)
        const backdatingIssuance = new BackdatingIssuance(tokenAddress)
        await executeTxFunc(backdatingIssuance.register(sender, false))

        // Register US investor with admin wallet
        const investors = new Investors(tokenAddress)
        await registerInvestor(tokenAddress, 'usInvestor')
        await executeTxFunc(investors.setCountry('usInvestor', 'US', sender))

        // Register EU investor with funded wallet
        euInvestorKP = await createFundedWallet()
        await registerInvestor(tokenAddress, 'euInvestor', [euInvestorKP.toSuiAddress()])
        await executeTxFunc(investors.setCountry('euInvestor', 'GR', sender))
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
            expect(ptb.getData()).toBeDefined()
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

    describe('Compute Transferable Tokens', () => {
        it('should return 0n for investor with no tokens', async () => {
            // Register lockup restriction (usLockPeriod=1000ms, nonUSLockPeriod=1000000000ms)
            await executeTxFunc(
                lockupRestriction.register(sender, complianceRules.usLockPeriod, complianceRules.nonUSLockPeriod)
            )

            const result = await lockupRestriction.computeTransferableTokens('usInvestor', Date.now(), sender)
            expect(result).toBe(0n)
        })

        it('should return full balance when US lockup has expired', async () => {
            // US lock period is 1000ms; issue tokens 5s in the past so lock is expired
            const issuanceTime = Date.now() - 5000
            await executeTxFunc(
                dsToken.issue(sender, sender, 1_000_000n, 0, '', [], [], issuanceTime)
            )

            const result = await lockupRestriction.computeTransferableTokens('usInvestor', Date.now(), sender)
            expect(result).toBe(1_000_000n)
        })

        it('should return 0n when non-US lockup is active', async () => {
            // Non-US lock period is 1000000000ms (~31 years); issue tokens now
            const issuanceTime = Date.now()
            await executeTxFunc(
                dsToken.issue(sender, euInvestorKP.toSuiAddress(), 500_000n, 0, '', [], [], issuanceTime)
            )

            const result = await lockupRestriction.computeTransferableTokens('euInvestor', Date.now(), sender)
            expect(result).toBe(0n)
        })
    })
})
