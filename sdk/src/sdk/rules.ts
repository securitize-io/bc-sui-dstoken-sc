import {SuiClient} from "../easysui";
import {ComplianceRules, Regions, newPTBDetails, PTBDetails} from "./domains";
import {AccreditedOnly} from "./rules/AccreditedOnly";
import {FlowbackRestriction} from "./rules/FlowbackRestriction";
import {ForceFullTransfer} from "./rules/ForceFullTransfer";
import {HoldingLimits} from "./rules/HoldingLimits";
import {InvestorLimits} from "./rules/InvestorLimits";
import {AuthorizedSecurities} from "./rules/AuthorizedSecurities";
import {BackdatingIssuance} from "./rules/BackdatingIssuance";
import {LockupRestriction} from "./rules/LockupRestriction";
import {getTokenDetails} from "./token";

export class Rules {
    private readonly tokenAddress: string;

    constructor(tokenAddress: string) {
        this.tokenAddress = tokenAddress;
    }

    // ==== View Functions ====

    async getRules(): Promise<ComplianceRules> {
        const complianceConfig = getTokenDetails(this.tokenAddress).complianceConfig
        const complianceInfo = await SuiClient.getObject(complianceConfig)
        const rulesBagId = (complianceInfo.data?.content as any)?.fields.rules_bag.fields.id.id

        const rulesBag = await SuiClient.client.getDynamicFields({
            parentId: rulesBagId
        })

        let allFields: any = {}
        for (const rule of rulesBag.data as any[]) {
            const ruleData = await SuiClient.getObject(rule.objectId)
            const fields = (ruleData.data?.content as any).fields.value.fields
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

        const regionMinTokens = allFields?.region_min_tokens?.fields?.contents?.map((c: any) => c.fields)
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

    // ==== Rule Management Functions ====

    async updatePTB(
        rules: ComplianceRules,
        ptbDetails?: PTBDetails,
    ) {
        ptbDetails ??= newPTBDetails()

        if ('forceAccredited' in rules || 'forceAccreditedUS' in rules) {
            new AccreditedOnly(this.tokenAddress).registerPTB(rules.forceAccredited, rules.forceAccreditedUS, ptbDetails)
        }

        if ('blockFlowbackEndTime' in rules) {
            new FlowbackRestriction(this.tokenAddress).registerPTB(rules.blockFlowbackEndTime, ptbDetails)
        }

        if ('forceFullTransfer' in rules || 'worldWideForceFullTransfer' in rules) {
            new ForceFullTransfer(this.tokenAddress).registerPTB(rules.forceFullTransfer, rules.worldWideForceFullTransfer, ptbDetails)
        }

        if (
            'minimumHoldingsPerInvestor' in rules ||
            'maximumHoldingsPerInvestor' in rules ||
            'minUSTokens' in rules ||
            'minEUTokens' in rules
        ) {
            new HoldingLimits(this.tokenAddress).registerPTB(
                BigInt(rules.minimumHoldingsPerInvestor || 0),
                BigInt(rules.maximumHoldingsPerInvestor || 0),
                BigInt(rules.minUSTokens || 0),
                BigInt(rules.minEUTokens || 0),
                ptbDetails,
            )
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
            new InvestorLimits(this.tokenAddress).registerPTB(
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

        if ('authorizedSecurities' in rules) {
            new AuthorizedSecurities(this.tokenAddress).registerPTB(BigInt(rules.authorizedSecurities || 0), ptbDetails)
        }

        if ('disallowBackDating' in rules) {
            new BackdatingIssuance(this.tokenAddress).registerPTB(rules.disallowBackDating, ptbDetails)
        }

        if ('usLockPeriod' in rules || 'nonUSLockPeriod' in rules) {
            new LockupRestriction(this.tokenAddress).registerPTB(rules.usLockPeriod, rules.nonUSLockPeriod, ptbDetails)
        }

        return ptbDetails.ptb
    }

    async update(
        signer: string,
        rules: ComplianceRules,
    ) {
        const ptb = await this.updatePTB(rules)
        return SuiClient.getMoveCallBytesFromPTB(ptb, signer)
    }
}
