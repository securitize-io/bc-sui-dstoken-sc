import { ADMIN_KEYPAIR } from '../../src'
import { deploy } from '../../src/sdk/utils/deploy'
import { createTestToken, executeTxFunc } from '../test_utils'
import { InvestorLimits } from '../../src/sdk/rules/InvestorLimits'

const sender = ADMIN_KEYPAIR!.toSuiAddress()

describe('InvestorLimits Rule', () => {
    let tokenAddress: string
    let investorLimits: InvestorLimits

    beforeAll(async () => {
        await deploy()
        tokenAddress = await createTestToken()
        investorLimits = new InvestorLimits(tokenAddress)
    })

    describe('Rule Registration', () => {
        it('should register InvestorLimits rule with all parameters', async () => {
            await expect(investorLimits.exists(sender)).resolves.toBe(false)

            await executeTxFunc(
                investorLimits.register(
                    sender,
                    2000,  // total_investors_limit
                    100,   // minimum_total_investors
                    500,   // us_investors_limit
                    300,   // us_accredited_limit
                    150,   // non_accredited_limit
                    100,   // jp_investors_limit
                    200,   // eu_retail_limit
                    25     // max_us_percentage
                )
            )

            await expect(investorLimits.exists(sender)).resolves.toBe(true)
        })

        it('should unregister InvestorLimits rule', async () => {
            await expect(investorLimits.exists(sender)).resolves.toBe(true)

            await executeTxFunc(investorLimits.unregister(sender))

            await expect(investorLimits.exists(sender)).resolves.toBe(false)
        })

        it('should register InvestorLimits with optional parameters', async () => {
            // Register with only some parameters (others default to 0)
            await executeTxFunc(
                investorLimits.register(
                    sender,
                    5000,  // total_investors_limit
                    undefined, // minimum_total_investors
                    1000,  // us_investors_limit
                )
            )
            await expect(investorLimits.exists(sender)).resolves.toBe(true)
            await executeTxFunc(investorLimits.unregister(sender))
        })

        it('should register InvestorLimits with different limit values', async () => {
            const configs = [
                { total: 10000, min: 500, us: 2000, usAcc: 1500, nonAcc: 500, jp: 300, euRetail: 400, usPercent: 20 },
                { total: 1000, min: 50, us: 200, usAcc: 150, nonAcc: 50, jp: 50, euRetail: 100, usPercent: 20 },
            ]

            for (const config of configs) {
                await executeTxFunc(
                    investorLimits.register(
                        sender,
                        config.total,
                        config.min,
                        config.us,
                        config.usAcc,
                        config.nonAcc,
                        config.jp,
                        config.euRetail,
                        config.usPercent
                    )
                )
                await expect(investorLimits.exists(sender)).resolves.toBe(true)
                await executeTxFunc(investorLimits.unregister(sender))
                await expect(investorLimits.exists(sender)).resolves.toBe(false)
            }
        })

        it('should not allow registering InvestorLimits rule twice', async () => {
            await executeTxFunc(
                investorLimits.register(sender, 2000, 100, 500, 300, 150, 100, 200, 25)
            )

            await expect(
                executeTxFunc(
                    investorLimits.register(sender, 3000, 200, 600, 400, 200, 150, 250, 30)
                )
            ).rejects.toThrow()

            await executeTxFunc(investorLimits.unregister(sender))
        })
    })

    describe('PTB (Programmable Transaction Block) Methods', () => {
        it('should create PTB for registration', async () => {
            const ptb = investorLimits.registerPTB(2000, 100, 500, 300, 150, 100, 200, 25)
            expect(ptb).toBeDefined()
            expect(ptb.blockData).toBeDefined()
        })
    })

    describe('Rule Updates', () => {
        it('should be able to set the values', async () => {
            await executeTxFunc(investorLimits.register(sender, 1000, 100, 500, 300, 150, 100, 200, 25))

            await executeTxFunc(investorLimits.setTotalLimit(2000, sender))
            await executeTxFunc(investorLimits.setMinimumTotalInvestors(200, sender))
            await executeTxFunc(investorLimits.setUsLimit(600, sender))
            await executeTxFunc(investorLimits.setUsAccreditedLimit(400, sender))
            await executeTxFunc(investorLimits.setNonAccreditedLimit(250, sender))
            await executeTxFunc(investorLimits.setJpLimit(150, sender))
            await executeTxFunc(investorLimits.setEuRetailLimit(300, sender))
            await executeTxFunc(investorLimits.setMaxUsPercentage(50, sender))
            await expect(investorLimits.exists(sender)).resolves.toBe(true)

            await executeTxFunc(investorLimits.unregister(sender))
        })
    })

    describe('Edge Cases', () => {
        it('should handle InvestorLimits with all zeros (no limits)', async () => {
            await executeTxFunc(
                investorLimits.register(sender, 0, 0, 0, 0, 0, 0, 0, 0)
            )
            await expect(investorLimits.exists(sender)).resolves.toBe(true)
            await executeTxFunc(investorLimits.unregister(sender))
        })

        it('should handle very large investor limits', async () => {
            await executeTxFunc(
                investorLimits.register(
                    sender,
                    1000000,  // very large total
                    0,
                    500000,   // very large US limit
                    400000,
                    100000,
                    50000,
                    200000,
                    100       // 100% max US percentage
                )
            )
            await expect(investorLimits.exists(sender)).resolves.toBe(true)
            await executeTxFunc(investorLimits.unregister(sender))
        })

        it('should handle only total investor limit set', async () => {
            await executeTxFunc(
                investorLimits.register(
                    sender,
                    5000,  // only total limit
                    undefined,
                    undefined,
                    undefined,
                    undefined,
                    undefined,
                    undefined,
                    undefined
                )
            )
            await expect(investorLimits.exists(sender)).resolves.toBe(true)
            await executeTxFunc(investorLimits.unregister(sender))
        })

        it('should handle only US-related limits', async () => {
            await executeTxFunc(
                investorLimits.register(
                    sender,
                    undefined,
                    undefined,
                    1000,  // us_investors_limit
                    800,   // us_accredited_limit
                    200,   // non_accredited_limit
                    undefined,
                    undefined,
                    50     // max_us_percentage
                )
            )
            await expect(investorLimits.exists(sender)).resolves.toBe(true)
            await executeTxFunc(investorLimits.unregister(sender))
        })

        it('should handle only JP and EU limits', async () => {
            await executeTxFunc(
                investorLimits.register(
                    sender,
                    undefined,
                    undefined,
                    undefined,
                    undefined,
                    undefined,
                    500,   // jp_investors_limit
                    300,   // eu_retail_limit
                    undefined
                )
            )
            await expect(investorLimits.exists(sender)).resolves.toBe(true)
            await executeTxFunc(investorLimits.unregister(sender))
        })

        it('should handle minimum total investors without total limit', async () => {
            await executeTxFunc(
                investorLimits.register(
                    sender,
                    undefined,
                    100,   // minimum_total_investors only
                    undefined,
                    undefined,
                    undefined,
                    undefined,
                    undefined,
                    undefined
                )
            )
            await expect(investorLimits.exists(sender)).resolves.toBe(true)
            await executeTxFunc(investorLimits.unregister(sender))
        })

        it('should handle max US percentage of 0', async () => {
            await executeTxFunc(
                investorLimits.register(
                    sender,
                    1000,
                    undefined,
                    undefined,
                    undefined,
                    undefined,
                    undefined,
                    undefined,
                    0      // 0% max US percentage
                )
            )
            await expect(investorLimits.exists(sender)).resolves.toBe(true)
            await executeTxFunc(investorLimits.unregister(sender))
        })
    })
})
