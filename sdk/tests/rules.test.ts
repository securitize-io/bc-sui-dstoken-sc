import {
    ADMIN_KEYPAIR,
    Rules,
    Regions
} from '../src'
import {deploy} from "../src/sdk/utils/deploy";
import {createTestToken, executeTxFunc} from "./test_utils";

const sender = ADMIN_KEYPAIR!.toSuiAddress();

describe('Rules (Compliance)', () => {
    let tokenAddress: string
    let rules: Rules

    beforeAll(async () => {
        await deploy()
        tokenAddress = await createTestToken()
        rules = new Rules(tokenAddress)
    })

    describe('AccreditedOnly Rule', () => {
        it('should register AccreditedOnly rule with both flags true', async () => {
            await expect(rules.hasRule('AccreditedOnly', sender)).resolves.toBe(false)

            await executeTxFunc(
                rules.registerAccreditedOnlyRule(sender, true, true)
            )

            await expect(rules.hasRule('AccreditedOnly', sender)).resolves.toBe(true)
        })

        it('should unregister AccreditedOnly rule', async () => {
            await expect(rules.hasRule('AccreditedOnly', sender)).resolves.toBe(true)

            await executeTxFunc(rules.unregisterRule('AccreditedOnly', sender))

            await expect(rules.hasRule('AccreditedOnly', sender)).resolves.toBe(false)
        })

        it('should register AccreditedOnly with different flag combinations', async () => {
            const configs = [
                { forceAccredited: true, forceUsAccredited: false },
                { forceAccredited: false, forceUsAccredited: true },
                { forceAccredited: false, forceUsAccredited: false },
            ]

            for (const config of configs) {
                await executeTxFunc(
                    rules.registerAccreditedOnlyRule(
                        sender,
                        config.forceAccredited,
                        config.forceUsAccredited
                    )
                )
                await expect(rules.hasRule('AccreditedOnly', sender)).resolves.toBe(true)
                await executeTxFunc(rules.unregisterRule('AccreditedOnly', sender))
                await expect(rules.hasRule('AccreditedOnly', sender)).resolves.toBe(false)
            }
        })

        it('should not allow registering AccreditedOnly rule twice', async () => {
            await executeTxFunc(rules.registerAccreditedOnlyRule(sender, true, true))

            await expect(
                executeTxFunc(rules.registerAccreditedOnlyRule(sender, false, false))
            ).rejects.toThrow()

            await executeTxFunc(rules.unregisterRule('AccreditedOnly', sender))
        })
    })

    describe('HoldingLimits Rule', () => {
        it('should register HoldingLimits rule with US and EU regions', async () => {
            await expect(rules.hasRule('HoldingLimits', sender)).resolves.toBe(false)

            await executeTxFunc(
                rules.registerHoldingLimitsRule(
                    sender,
                    100,        // min holdings per investor
                    1000000,    // max holdings per investor
                    500,        // minUSTokens
                    300         // minEUTokens
                )
            )

            await expect(rules.hasRule('HoldingLimits', sender)).resolves.toBe(true)
        })

        it('should unregister HoldingLimits rule', async () => {
            await expect(rules.hasRule('HoldingLimits', sender)).resolves.toBe(true)

            await executeTxFunc(rules.unregisterRule('HoldingLimits', sender))

            await expect(rules.hasRule('HoldingLimits', sender)).resolves.toBe(false)
        })

        it('should register HoldingLimits with different configurations', async () => {
            const configs = [
                { min: 0, max: 500000, minUS: 100, minEU: 200 },
                { min: 1000, max: 2000000, minUS: 1000, minEU: 1500 },
                { min: 50, max: 100000, minUS: 50, minEU: 75 },
            ]

            for (const config of configs) {
                await executeTxFunc(
                    rules.registerHoldingLimitsRule(
                        sender,
                        config.min,
                        config.max,
                        config.minUS,
                        config.minEU
                    )
                )
                await expect(rules.hasRule('HoldingLimits', sender)).resolves.toBe(true)
                await executeTxFunc(rules.unregisterRule('HoldingLimits', sender))
                await expect(rules.hasRule('HoldingLimits', sender)).resolves.toBe(false)
            }
        })

        it('should register HoldingLimits with only US region', async () => {
            await executeTxFunc(
                rules.registerHoldingLimitsRule(
                    sender,
                    100,
                    500000,
                    1000        // only US min (no EU min)
                )
            )
            await expect(rules.hasRule('HoldingLimits', sender)).resolves.toBe(true)
            await executeTxFunc(rules.unregisterRule('HoldingLimits', sender))
        })

        it('should register HoldingLimits with only EU region', async () => {
            await executeTxFunc(
                rules.registerHoldingLimitsRule(
                    sender,
                    100,
                    500000,
                    undefined,  // no US min
                    2000        // only EU min
                )
            )
            await expect(rules.hasRule('HoldingLimits', sender)).resolves.toBe(true)
            await executeTxFunc(rules.unregisterRule('HoldingLimits', sender))
        })
    })

    describe('InvestorLimits Rule', () => {
        it('should register InvestorLimits rule with all parameters', async () => {
            await expect(rules.hasRule('InvestorLimits', sender)).resolves.toBe(false)

            await executeTxFunc(
                rules.registerInvestorLimitsRule(
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

            await expect(rules.hasRule('InvestorLimits', sender)).resolves.toBe(true)
        })

        it('should unregister InvestorLimits rule', async () => {
            await expect(rules.hasRule('InvestorLimits', sender)).resolves.toBe(true)

            await executeTxFunc(rules.unregisterRule('InvestorLimits', sender))

            await expect(rules.hasRule('InvestorLimits', sender)).resolves.toBe(false)
        })

        it('should register InvestorLimits with optional parameters', async () => {
            // Register with only some parameters (others default to 0)
            await executeTxFunc(
                rules.registerInvestorLimitsRule(
                    sender,
                    5000,  // total_investors_limit
                    undefined, // minimum_total_investors
                    1000,  // us_investors_limit
                )
            )
            await expect(rules.hasRule('InvestorLimits', sender)).resolves.toBe(true)
            await executeTxFunc(rules.unregisterRule('InvestorLimits', sender))
        })

        it('should register InvestorLimits with different limit values', async () => {
            const configs = [
                { total: 10000, min: 500, us: 2000, usAcc: 1500, nonAcc: 500, jp: 300, euRetail: 400, usPercent: 20 },
                { total: 1000, min: 50, us: 200, usAcc: 150, nonAcc: 50, jp: 50, euRetail: 100, usPercent: 20 },
            ]

            for (const config of configs) {
                await executeTxFunc(
                    rules.registerInvestorLimitsRule(
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
                await expect(rules.hasRule('InvestorLimits', sender)).resolves.toBe(true)
                await executeTxFunc(rules.unregisterRule('InvestorLimits', sender))
                await expect(rules.hasRule('InvestorLimits', sender)).resolves.toBe(false)
            }
        })
    })

    describe('ForceFullTransfer Rule', () => {
        it('should register ForceFullTransfer rule with both flags true', async () => {
            await expect(rules.hasRule('ForceFullTransfer', sender)).resolves.toBe(false)

            await executeTxFunc(
                rules.registerForceFullTransferRule(sender, true, true)
            )

            await expect(rules.hasRule('ForceFullTransfer', sender)).resolves.toBe(true)
        })

        it('should unregister ForceFullTransfer rule', async () => {
            await expect(rules.hasRule('ForceFullTransfer', sender)).resolves.toBe(true)

            await executeTxFunc(rules.unregisterRule('ForceFullTransfer', sender))

            await expect(rules.hasRule('ForceFullTransfer', sender)).resolves.toBe(false)
        })

        it('should register ForceFullTransfer with different flag combinations', async () => {
            const configs = [
                { forceUs: true, forceWorldwide: false },
                { forceUs: false, forceWorldwide: true },
                { forceUs: false, forceWorldwide: false },
            ]

            for (const config of configs) {
                await executeTxFunc(
                    rules.registerForceFullTransferRule(
                        sender,
                        config.forceUs,
                        config.forceWorldwide
                    )
                )
                await expect(rules.hasRule('ForceFullTransfer', sender)).resolves.toBe(true)
                await executeTxFunc(rules.unregisterRule('ForceFullTransfer', sender))
                await expect(rules.hasRule('ForceFullTransfer', sender)).resolves.toBe(false)
            }
        })
    })

    describe('FlowbackRestriction Rule', () => {
        it('should register FlowbackRestriction rule with end time', async () => {
            await expect(rules.hasRule('FlowbackRestriction', sender)).resolves.toBe(false)

            const endTime = Date.now() + 365 * 24 * 60 * 60 * 1000 // 1 year from now
            await executeTxFunc(
                rules.registerFlowbackRestrictionRule(sender, endTime)
            )

            await expect(rules.hasRule('FlowbackRestriction', sender)).resolves.toBe(true)
        })

        it('should unregister FlowbackRestriction rule', async () => {
            await expect(rules.hasRule('FlowbackRestriction', sender)).resolves.toBe(true)

            await executeTxFunc(rules.unregisterRule('FlowbackRestriction', sender))

            await expect(rules.hasRule('FlowbackRestriction', sender)).resolves.toBe(false)
        })

        it('should register FlowbackRestriction with different end times', async () => {
            const endTimes = [
                Date.now() + 30 * 24 * 60 * 60 * 1000,  // 30 days
                Date.now() + 90 * 24 * 60 * 60 * 1000,  // 90 days
                Date.now() + 180 * 24 * 60 * 60 * 1000, // 180 days
            ]

            for (const endTime of endTimes) {
                await executeTxFunc(
                    rules.registerFlowbackRestrictionRule(sender, endTime)
                )
                await expect(rules.hasRule('FlowbackRestriction', sender)).resolves.toBe(true)
                await executeTxFunc(rules.unregisterRule('FlowbackRestriction', sender))
                await expect(rules.hasRule('FlowbackRestriction', sender)).resolves.toBe(false)
            }
        })

        it('should register FlowbackRestriction with no end time (defaults to 0)', async () => {
            await executeTxFunc(
                rules.registerFlowbackRestrictionRule(sender)
            )
            await expect(rules.hasRule('FlowbackRestriction', sender)).resolves.toBe(true)
            await executeTxFunc(rules.unregisterRule('FlowbackRestriction', sender))
        })
    })

    describe('Multiple Rules Management', () => {
        it('should register all rule types simultaneously', async () => {
            // Register all 5 rule types
            await executeTxFunc(rules.registerAccreditedOnlyRule(sender, true, true))
            await executeTxFunc(
                rules.registerHoldingLimitsRule(sender, 100, 1000000, 500, 300)
            )
            await executeTxFunc(
                rules.registerInvestorLimitsRule(sender, 2000, 100, 500, 300, 150, 100, 200, 25)
            )
            await executeTxFunc(rules.registerForceFullTransferRule(sender, true, false))
            await executeTxFunc(rules.registerFlowbackRestrictionRule(sender, Date.now() + 365 * 24 * 60 * 60 * 1000))

            // Verify all rules are registered
            await expect(rules.hasRule('AccreditedOnly', sender)).resolves.toBe(true)
            await expect(rules.hasRule('HoldingLimits', sender)).resolves.toBe(true)
            await expect(rules.hasRule('InvestorLimits', sender)).resolves.toBe(true)
            await expect(rules.hasRule('ForceFullTransfer', sender)).resolves.toBe(true)
            await expect(rules.hasRule('FlowbackRestriction', sender)).resolves.toBe(true)

            // Clean up all rules
            await executeTxFunc(rules.unregisterRule('AccreditedOnly', sender))
            await executeTxFunc(rules.unregisterRule('HoldingLimits', sender))
            await executeTxFunc(rules.unregisterRule('InvestorLimits', sender))
            await executeTxFunc(rules.unregisterRule('ForceFullTransfer', sender))
            await executeTxFunc(rules.unregisterRule('FlowbackRestriction', sender))

            // Verify all rules are unregistered
            await expect(rules.hasRule('AccreditedOnly', sender)).resolves.toBe(false)
            await expect(rules.hasRule('HoldingLimits', sender)).resolves.toBe(false)
            await expect(rules.hasRule('InvestorLimits', sender)).resolves.toBe(false)
            await expect(rules.hasRule('ForceFullTransfer', sender)).resolves.toBe(false)
            await expect(rules.hasRule('FlowbackRestriction', sender)).resolves.toBe(false)
        })

        it('should handle rule re-registration after unregistering', async () => {
            // Register first time
            await executeTxFunc(rules.registerAccreditedOnlyRule(sender, true, true))
            await expect(rules.hasRule('AccreditedOnly', sender)).resolves.toBe(true)

            // Unregister
            await executeTxFunc(rules.unregisterRule('AccreditedOnly', sender))
            await expect(rules.hasRule('AccreditedOnly', sender)).resolves.toBe(false)

            // Re-register with different config
            await executeTxFunc(rules.registerAccreditedOnlyRule(sender, false, true))
            await expect(rules.hasRule('AccreditedOnly', sender)).resolves.toBe(true)

            // Clean up
            await executeTxFunc(rules.unregisterRule('AccreditedOnly', sender))
        })

        it('should not allow unregistering non-existent rule', async () => {
            await expect(rules.hasRule('HoldingLimits', sender)).resolves.toBe(false)

            await expect(
                executeTxFunc(rules.unregisterRule('HoldingLimits', sender))
            ).rejects.toThrow()
        })
    })

    describe('Edge Cases and Validation', () => {
        it('should handle HoldingLimits with zero minimums', async () => {
            await executeTxFunc(
                rules.registerHoldingLimitsRule(
                    sender,
                    0,          // zero min holdings
                    1000000,    // max holdings
                    0,          // zero US min
                    0           // zero EU min
                )
            )
            await expect(rules.hasRule('HoldingLimits', sender)).resolves.toBe(true)
            await executeTxFunc(rules.unregisterRule('HoldingLimits', sender))
        })

        it('should handle InvestorLimits with all zeros (no limits)', async () => {
            await executeTxFunc(
                rules.registerInvestorLimitsRule(sender, 0, 0, 0, 0, 0, 0, 0, 0)
            )
            await expect(rules.hasRule('InvestorLimits', sender)).resolves.toBe(true)
            await executeTxFunc(rules.unregisterRule('InvestorLimits', sender))
        })

        it('should handle very large investor limits', async () => {
            await executeTxFunc(
                rules.registerInvestorLimitsRule(
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
            await expect(rules.hasRule('InvestorLimits', sender)).resolves.toBe(true)
            await executeTxFunc(rules.unregisterRule('InvestorLimits', sender))
        })

        it('should handle HoldingLimits with no region minimums', async () => {
            await executeTxFunc(
                rules.registerHoldingLimitsRule(
                    sender,
                    100,
                    500000
                    // no US or EU minimums specified
                )
            )
            await expect(rules.hasRule('HoldingLimits', sender)).resolves.toBe(true)
            await executeTxFunc(rules.unregisterRule('HoldingLimits', sender))
        })
    })
})
