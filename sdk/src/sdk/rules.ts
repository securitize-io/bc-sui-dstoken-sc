import {ADMIN_ADDRESS, SuiClient} from "../easysui";
import {ComplianceRules, Regions, newPTBDetails, PTBDetails} from "./domains";
import {
    AccreditedOnly,
    FlowbackRestriction,
    ForceFullTransfer,
    HoldingLimits,
    InvestorLimits,
    AuthorizedSecurities,
    BackdatingIssuance,
    LockupRestriction,
} from "./all_rules"
import {getTokenDetails} from "./token";

export class Rules {
    private readonly tokenAddress: string;

    constructor(tokenAddress: string) {
        this.tokenAddress = tokenAddress;
    }

    // ==== View Functions ====

    /** Returns the current compliance rules configuration from the chain. */
    async getRules(): Promise<ComplianceRules> {
        const complianceConfig = getTokenDetails(this.tokenAddress).complianceConfig
        const complianceInfo = await SuiClient.getObject(complianceConfig)
        const rulesBagId = (complianceInfo.data?.content as any)?.fields.rules_bag.id

        const rulesBag = await SuiClient.client.listDynamicFields({
            parentId: rulesBagId
        })

        let allFields: any = {}
        for (const rule of rulesBag.dynamicFields as any[]) {
            const ruleData = await SuiClient.getObject(rule.fieldId)
            const fields = (ruleData.data?.content as any).fields.value
            allFields = {...allFields, ...fields}
        }

        const rules: ComplianceRules = {
            forceAccredited: allFields.force_accredited,
            forceAccreditedUS: allFields.force_us_accredited,
            blockFlowbackEndTime: parseInt(allFields.block_flowback_end_time_ms),
            worldWideForceFullTransfer: allFields.force_full_transfer_worldwide,
            forceFullTransfer: allFields.force_full_transfer_us,
            minimumHoldingsPerInvestor: allFields.min_holdings_per_investor,
            maximumHoldingsPerInvestor: allFields.max_holdings_per_investor,
            totalInvestorsLimit: allFields.total_investors_limit && parseInt(allFields.total_investors_limit),
            usInvestorsLimit: allFields.us_investors_limit && parseInt(allFields.us_investors_limit),
            euRetailInvestorsLimit: allFields.eu_retail_limit && parseInt(allFields.eu_retail_limit),
            jpInvestorsLimit: allFields.jp_investors_limit && parseInt(allFields.jp_investors_limit),
            usAccreditedInvestorsLimit: allFields.us_accredited_limit && parseInt(allFields.us_accredited_limit),
            nonAccreditedInvestorsLimit: allFields.non_accredited_limit && parseInt(allFields.non_accredited_limit),
            maxUSInvestorsPercentage: allFields.max_us_percentage && parseInt(allFields.max_us_percentage),
            authorizedSecurities: allFields.max_supply && BigInt(allFields.max_supply).toString(),
            disallowBackDating: allFields.disallow_backdating,
            usLockPeriod: allFields.us_lock_period_ms && parseInt(allFields.us_lock_period_ms),
            nonUSLockPeriod: allFields.non_us_lock_period_ms && parseInt(allFields.non_us_lock_period_ms)
        }

        const regionMinTokens = allFields?.region_min_tokens?.contents?.map((c: any) => c)
        if (regionMinTokens) {
            const us = regionMinTokens.find((c: any) => c.key === Regions.US.toString())
            if (us) {
                rules.minUSTokens = us.value
            }
            const eu = regionMinTokens.find((c: any) => c.key === Regions.EU.toString())
            if (eu) {
                rules.minEUTokens = eu.value
            }
        }

        return rules
    }

    // ==== Rule Management ====

    async updatePTB(
        rules: ComplianceRules,
        ptbDetails?: PTBDetails,
    ) {
        ptbDetails ??= newPTBDetails()
        const sender = ADMIN_ADDRESS

        if ('forceAccredited' in rules || 'forceAccreditedUS' in rules) {
            const accreditedOnly = new AccreditedOnly(this.tokenAddress)
            if (await accreditedOnly.exists(sender, ptbDetails)) {
                accreditedOnly.setForceAccreditedPTB(rules.forceAccredited, ptbDetails)
                accreditedOnly.setForceUsAccreditedPTB(rules.forceAccreditedUS, ptbDetails)
            } else {
                accreditedOnly.registerPTB(rules.forceAccredited, rules.forceAccreditedUS, ptbDetails)
            }
        }

        if ('blockFlowbackEndTime' in rules) {
            const flowbackRestriction = new FlowbackRestriction(this.tokenAddress)
            if (await flowbackRestriction.exists(sender, ptbDetails)) {
                flowbackRestriction.setFlowbackEndTimePTB(rules.blockFlowbackEndTime, ptbDetails)
            } else {
                flowbackRestriction.registerPTB(rules.blockFlowbackEndTime, ptbDetails)
            }
        }

        if ('forceFullTransfer' in rules || 'worldWideForceFullTransfer' in rules) {
            const forceFullTransfer = new ForceFullTransfer(this.tokenAddress)
            if (await forceFullTransfer.exists(sender, ptbDetails)) {
                forceFullTransfer.setForceUsPTB(rules.forceFullTransfer, ptbDetails)
                forceFullTransfer.setForceWorldwidePTB(rules.worldWideForceFullTransfer, ptbDetails)
            } else {
                forceFullTransfer.registerPTB(rules.forceFullTransfer, rules.worldWideForceFullTransfer, ptbDetails)
            }
        }

        if (
            'minimumHoldingsPerInvestor' in rules ||
            'maximumHoldingsPerInvestor' in rules ||
            'minUSTokens' in rules ||
            'minEUTokens' in rules
        ) {
            const holdingLimits = new HoldingLimits(this.tokenAddress)
            if (await holdingLimits.exists(sender, ptbDetails)) {
                holdingLimits.setMinHoldingsPTB(rules.minimumHoldingsPerInvestor ? BigInt(rules.minimumHoldingsPerInvestor) : undefined, ptbDetails)
                holdingLimits.setMaxHoldingsPTB(rules.maximumHoldingsPerInvestor ? BigInt(rules.maximumHoldingsPerInvestor) : undefined, ptbDetails)
                if (rules.minUSTokens !== undefined) {
                    holdingLimits.setRegionMinHoldingsPTB(Regions.US, BigInt(rules.minUSTokens), ptbDetails)
                }
                if (rules.minEUTokens !== undefined) {
                    holdingLimits.setRegionMinHoldingsPTB(Regions.EU, BigInt(rules.minEUTokens), ptbDetails)
                }
            } else {
                holdingLimits.registerPTB(
                    BigInt(rules.minimumHoldingsPerInvestor || 0),
                    BigInt(rules.maximumHoldingsPerInvestor || 0),
                    BigInt(rules.minUSTokens || 0),
                    BigInt(rules.minEUTokens || 0),
                    ptbDetails,
                )
            }
        }

        if (
            'totalInvestorsLimit' in rules ||
            'minimumTotalInvestors' in rules ||
            'usInvestorsLimit' in rules ||
            'usAccreditedInvestorsLimit' in rules ||
            'nonAccreditedInvestorsLimit' in rules ||
            'jpInvestorsLimit' in rules ||
            'euRetailInvestorsLimit' in rules ||
            'maxUSInvestorsPercentage' in rules
        ) {
            const investorLimits = new InvestorLimits(this.tokenAddress)
            if (await investorLimits.exists(sender, ptbDetails)) {
                investorLimits.setTotalLimitPTB(rules.totalInvestorsLimit, ptbDetails)
                investorLimits.setMinimumTotalInvestorsPTB(rules.minimumTotalInvestors, ptbDetails)
                investorLimits.setUsLimitPTB(rules.usInvestorsLimit, ptbDetails)
                investorLimits.setUsAccreditedLimitPTB(rules.usAccreditedInvestorsLimit, ptbDetails)
                investorLimits.setNonAccreditedLimitPTB(rules.nonAccreditedInvestorsLimit, ptbDetails)
                investorLimits.setJpLimitPTB(rules.jpInvestorsLimit, ptbDetails)
                investorLimits.setEuRetailLimitPTB(rules.euRetailInvestorsLimit, ptbDetails)
                investorLimits.setMaxUsPercentagePTB(rules.maxUSInvestorsPercentage, ptbDetails)
            } else {
                investorLimits.registerPTB(
                    rules.totalInvestorsLimit,
                    rules.minimumTotalInvestors,
                    rules.usInvestorsLimit,
                    rules.usAccreditedInvestorsLimit,
                    rules.nonAccreditedInvestorsLimit,
                    rules.jpInvestorsLimit,
                    rules.euRetailInvestorsLimit,
                    rules.maxUSInvestorsPercentage,
                    ptbDetails,
                )
            }
        }

        if ('authorizedSecurities' in rules) {
            const authorizedSecurities = new AuthorizedSecurities(this.tokenAddress)
            if (await authorizedSecurities.exists(sender, ptbDetails)) {
                authorizedSecurities.setMaxSupplyPTB(rules.authorizedSecurities ? BigInt(rules.authorizedSecurities) : undefined, ptbDetails)
            } else {
                authorizedSecurities.registerPTB(BigInt(rules.authorizedSecurities || 0), ptbDetails)
            }
        }

        if ('disallowBackDating' in rules) {
            const backdatingIssuance = new BackdatingIssuance(this.tokenAddress)
            if (await backdatingIssuance.exists(sender, ptbDetails)) {
                backdatingIssuance.setDisallowBackdatingPTB(rules.disallowBackDating, ptbDetails)
            } else {
                backdatingIssuance.registerPTB(rules.disallowBackDating, ptbDetails)
            }
        }

        if ('usLockPeriod' in rules || 'nonUSLockPeriod' in rules) {
            const lockupRestriction = new LockupRestriction(this.tokenAddress)
            if (await lockupRestriction.exists(sender, ptbDetails)) {
                lockupRestriction.setUsLockPeriodPTB(rules.usLockPeriod, ptbDetails)
                lockupRestriction.setNonUsLockPeriodPTB(rules.nonUSLockPeriod, ptbDetails)
            } else {
                lockupRestriction.registerPTB(rules.usLockPeriod, rules.nonUSLockPeriod, ptbDetails)
            }
        }

        return ptbDetails.ptb
    }

    /** Updates compliance rules. Registers new rules or updates existing ones as needed. */
    async update(
        signer: string,
        rules: ComplianceRules,
    ) {
        const ptb = await this.updatePTB(rules)
        return SuiClient.getMoveCallBytesFromPTB(ptb, signer)
    }
}
