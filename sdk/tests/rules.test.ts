import {
    ADMIN_KEYPAIR,
    Rules,
    ComplianceRules
} from '../src'
import {deploy} from "../src/sdk/utils/deploy";
import {createTestToken, executeTxFunc} from "./test_utils";
import {AccreditedOnly} from "../src/sdk/rules/AccreditedOnly";
import {FlowbackRestriction} from "../src/sdk/rules/FlowbackRestriction";
import {ForceFullTransfer} from "../src/sdk/rules/ForceFullTransfer";
import {HoldingLimits} from "../src/sdk/rules/HoldingLimits";
import {InvestorLimits} from "../src/sdk/rules/InvestorLimits";

const sender = ADMIN_KEYPAIR!.toSuiAddress();

describe('Rules (Compliance)', () => {
    let tokenAddress: string
    let rules: Rules

    beforeAll(async () => {
        await deploy()
        tokenAddress = await createTestToken()
        rules = new Rules(tokenAddress)
    })

    describe('Rules Update with ComplianceRules', () => {
        it('should update all rules using ComplianceRules object', async () => {
            const complianceRules: ComplianceRules = {
                forceAccredited: true,
                forceAccreditedUS: true,
                blockFlowbackEndTime: Date.now() + 365 * 24 * 60 * 60 * 1000,
                worldWideForceFullTransfer: true,
                forceFullTransfer: true,
                minUSTokens: '500',
                minEUTokens: '300',
                minimumHoldingsPerInvestor: '100',
                maximumHoldingsPerInvestor: '1000000',
                totalInvestorsLimit: 2000,
                usInvestorsLimit: 500,
                euRetailInvestorsLimit: 200,
                jpInvestorsLimit: 100,
                usAccreditedInvestorsLimit: 300,
                nonAccreditedInvestorsLimit: 150,
                maxUSInvestorsPercentage: 25
            }

            await executeTxFunc(rules.update(sender, complianceRules))

            // Verify all rules are registered
            const accreditedOnly = new AccreditedOnly(tokenAddress)
            const flowbackRestriction = new FlowbackRestriction(tokenAddress)
            const forceFullTransfer = new ForceFullTransfer(tokenAddress)
            const holdingLimits = new HoldingLimits(tokenAddress)
            const investorLimits = new InvestorLimits(tokenAddress)

            await expect(accreditedOnly.exists(sender)).resolves.toBe(true)
            await expect(flowbackRestriction.exists(sender)).resolves.toBe(true)
            await expect(forceFullTransfer.exists(sender)).resolves.toBe(true)
            await expect(holdingLimits.exists(sender)).resolves.toBe(true)
            await expect(investorLimits.exists(sender)).resolves.toBe(true)

            // Clean up
            await executeTxFunc(accreditedOnly.unregister(sender))
            await executeTxFunc(flowbackRestriction.unregister(sender))
            await executeTxFunc(forceFullTransfer.unregister(sender))
            await executeTxFunc(holdingLimits.unregister(sender))
            await executeTxFunc(investorLimits.unregister(sender))
        })

        it('should update rules with partial ComplianceRules object', async () => {
            const complianceRules: ComplianceRules = {
                forceAccredited: true,
                forceAccreditedUS: false,
                totalInvestorsLimit: 1000
            }

            await executeTxFunc(rules.update(sender, complianceRules))

            // Verify specific rules are registered
            const accreditedOnly = new AccreditedOnly(tokenAddress)
            const investorLimits = new InvestorLimits(tokenAddress)

            await expect(accreditedOnly.exists(sender)).resolves.toBe(true)
            await expect(investorLimits.exists(sender)).resolves.toBe(true)

            // Clean up
            await executeTxFunc(accreditedOnly.unregister(sender))
            await executeTxFunc(investorLimits.unregister(sender))
        })

        it('should create PTB for updating rules', async () => {
            const complianceRules: ComplianceRules = {
                forceAccredited: true,
                minimumHoldingsPerInvestor: '100',
                maximumHoldingsPerInvestor: '500000'
            }

            const ptb = rules.updatePTB(complianceRules)
            expect(ptb).toBeDefined()
            expect(ptb.blockData).toBeDefined()
        })

        it('should accept custom PTB instance', async () => {
            const { Transaction } = await import('@mysten/sui/transactions')
            const customPTB = new Transaction()

            const complianceRules: ComplianceRules = {
                forceAccredited: false,
                forceAccreditedUS: true
            }

            const result = rules.updatePTB(complianceRules, customPTB)
            expect(result).toBe(customPTB)
        })
    })

    describe('Rules Update with Different Configurations', () => {
        afterEach(async () => {
            // Clean up all possible rules after each test
            try {
                const accreditedOnly = new AccreditedOnly(tokenAddress)
                const flowbackRestriction = new FlowbackRestriction(tokenAddress)
                const forceFullTransfer = new ForceFullTransfer(tokenAddress)
                const holdingLimits = new HoldingLimits(tokenAddress)
                const investorLimits = new InvestorLimits(tokenAddress)

                if (await accreditedOnly.exists(sender)) {
                    await executeTxFunc(accreditedOnly.unregister(sender))
                }
                if (await flowbackRestriction.exists(sender)) {
                    await executeTxFunc(flowbackRestriction.unregister(sender))
                }
                if (await forceFullTransfer.exists(sender)) {
                    await executeTxFunc(forceFullTransfer.unregister(sender))
                }
                if (await holdingLimits.exists(sender)) {
                    await executeTxFunc(holdingLimits.unregister(sender))
                }
                if (await investorLimits.exists(sender)) {
                    await executeTxFunc(investorLimits.unregister(sender))
                }
            } catch (error) {
                // Ignore cleanup errors
            }
        })

        it('should update with AccreditedOnly rules only', async () => {
            const complianceRules: ComplianceRules = {
                forceAccredited: true,
                forceAccreditedUS: true
            }

            await executeTxFunc(rules.update(sender, complianceRules))

            const accreditedOnly = new AccreditedOnly(tokenAddress)
            await expect(accreditedOnly.exists(sender)).resolves.toBe(true)
        })

        it('should update with FlowbackRestriction rules only', async () => {
            const complianceRules: ComplianceRules = {
                blockFlowbackEndTime: Date.now() + 90 * 24 * 60 * 60 * 1000
            }

            await executeTxFunc(rules.update(sender, complianceRules))

            const flowbackRestriction = new FlowbackRestriction(tokenAddress)
            await expect(flowbackRestriction.exists(sender)).resolves.toBe(true)
        })

        it('should update with ForceFullTransfer rules only', async () => {
            const complianceRules: ComplianceRules = {
                forceFullTransfer: true,
                worldWideForceFullTransfer: false
            }

            await executeTxFunc(rules.update(sender, complianceRules))

            const forceFullTransfer = new ForceFullTransfer(tokenAddress)
            await expect(forceFullTransfer.exists(sender)).resolves.toBe(true)
        })

        it('should update with HoldingLimits rules only', async () => {
            const complianceRules: ComplianceRules = {
                minimumHoldingsPerInvestor: '100',
                maximumHoldingsPerInvestor: '1000000',
                minUSTokens: '500',
                minEUTokens: '300'
            }

            await executeTxFunc(rules.update(sender, complianceRules))

            const holdingLimits = new HoldingLimits(tokenAddress)
            await expect(holdingLimits.exists(sender)).resolves.toBe(true)
        })

        it('should update with InvestorLimits rules only', async () => {
            const complianceRules: ComplianceRules = {
                totalInvestorsLimit: 2000,
                usInvestorsLimit: 500,
                usAccreditedInvestorsLimit: 300,
                nonAccreditedInvestorsLimit: 150,
                jpInvestorsLimit: 100,
                euRetailInvestorsLimit: 200,
                maxUSInvestorsPercentage: 25
            }

            await executeTxFunc(rules.update(sender, complianceRules))

            const investorLimits = new InvestorLimits(tokenAddress)
            await expect(investorLimits.exists(sender)).resolves.toBe(true)
        })
    })

    describe('Edge Cases and Validation', () => {
        afterEach(async () => {
            // Clean up all possible rules after each test
            try {
                const accreditedOnly = new AccreditedOnly(tokenAddress)
                const flowbackRestriction = new FlowbackRestriction(tokenAddress)
                const forceFullTransfer = new ForceFullTransfer(tokenAddress)
                const holdingLimits = new HoldingLimits(tokenAddress)
                const investorLimits = new InvestorLimits(tokenAddress)

                if (await accreditedOnly.exists(sender)) {
                    await executeTxFunc(accreditedOnly.unregister(sender))
                }
                if (await flowbackRestriction.exists(sender)) {
                    await executeTxFunc(flowbackRestriction.unregister(sender))
                }
                if (await forceFullTransfer.exists(sender)) {
                    await executeTxFunc(forceFullTransfer.unregister(sender))
                }
                if (await holdingLimits.exists(sender)) {
                    await executeTxFunc(holdingLimits.unregister(sender))
                }
                if (await investorLimits.exists(sender)) {
                    await executeTxFunc(investorLimits.unregister(sender))
                }
            } catch (error) {
                // Ignore cleanup errors
            }
        })

        it('should handle HoldingLimits with zero minimums', async () => {
            const complianceRules: ComplianceRules = {
                minimumHoldingsPerInvestor: '0',
                maximumHoldingsPerInvestor: '1000000',
                minUSTokens: '0',
                minEUTokens: '0'
            }

            await executeTxFunc(rules.update(sender, complianceRules))

            const holdingLimits = new HoldingLimits(tokenAddress)
            await expect(holdingLimits.exists(sender)).resolves.toBe(true)
        })

        it('should handle InvestorLimits with all zeros (no limits)', async () => {
            const complianceRules: ComplianceRules = {
                totalInvestorsLimit: 0,
                usInvestorsLimit: 0,
                usAccreditedInvestorsLimit: 0,
                nonAccreditedInvestorsLimit: 0,
                jpInvestorsLimit: 0,
                euRetailInvestorsLimit: 0,
                maxUSInvestorsPercentage: 0
            }

            await executeTxFunc(rules.update(sender, complianceRules))

            const investorLimits = new InvestorLimits(tokenAddress)
            await expect(investorLimits.exists(sender)).resolves.toBe(true)
        })

        it('should handle very large investor limits', async () => {
            const complianceRules: ComplianceRules = {
                totalInvestorsLimit: 1000000,
                usInvestorsLimit: 500000,
                usAccreditedInvestorsLimit: 400000,
                nonAccreditedInvestorsLimit: 100000,
                jpInvestorsLimit: 50000,
                euRetailInvestorsLimit: 200000,
                maxUSInvestorsPercentage: 100
            }

            await executeTxFunc(rules.update(sender, complianceRules))

            const investorLimits = new InvestorLimits(tokenAddress)
            await expect(investorLimits.exists(sender)).resolves.toBe(true)
        })

        it('should handle empty ComplianceRules object', async () => {
            const complianceRules: ComplianceRules = {}

            await executeTxFunc(rules.update(sender, complianceRules))

            // All rules should be registered with default/zero values
            const accreditedOnly = new AccreditedOnly(tokenAddress)
            const flowbackRestriction = new FlowbackRestriction(tokenAddress)
            const forceFullTransfer = new ForceFullTransfer(tokenAddress)
            const holdingLimits = new HoldingLimits(tokenAddress)
            const investorLimits = new InvestorLimits(tokenAddress)

            await expect(accreditedOnly.exists(sender)).resolves.toBe(true)
            await expect(flowbackRestriction.exists(sender)).resolves.toBe(true)
            await expect(forceFullTransfer.exists(sender)).resolves.toBe(true)
            await expect(holdingLimits.exists(sender)).resolves.toBe(true)
            await expect(investorLimits.exists(sender)).resolves.toBe(true)
        })
    })
})
