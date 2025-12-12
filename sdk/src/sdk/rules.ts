import {SuiClient} from "../easysui";
import {Config} from "./utils/config";
import {getTokenDetails} from "./token";
import {Transaction, TransactionResult} from "@mysten/sui/transactions";
import {Regions} from "./domains/Region";

export type RuleType =
    | 'AccreditedOnly'
    | 'HoldingLimits'
    | 'InvestorLimits'
    | 'ForceFullTransfer'
    | 'FlowbackRestriction';

export class Rules {
    private readonly tokenAddress: string;
    private readonly tokenDetails: any;

    constructor(tokenAddress: string) {
        this.tokenAddress = tokenAddress;
        this.tokenDetails = getTokenDetails(tokenAddress);
    }

    private getComplianceTarget(func: string) {
        return `${Config.vars.PACKAGE_ID}::compliance_service::${func}`
    }

    private getRuleTarget(ruleName: string, func: string) {
        return `${Config.vars.PACKAGE_ID}::${ruleName}::${func}`
    }

    private buildGetPTB(func: string, ruleType: RuleType, args: any[] = []) {
        const ruleTypeArg = `${Config.vars.PACKAGE_ID}::${this.getRuleModuleName(ruleType)}::${ruleType}`
        return SuiClient.getPTB(
            this.getComplianceTarget(func),
            [this.tokenAddress, ruleTypeArg],
            [this.tokenDetails.complianceConfig, ...args],
        )
    }

    private buildSetPTB(signer: string, ruleType: RuleType, func: string, args: any[] = []) {
        const ruleModule = this.getRuleModuleName(ruleType)
        const ruleTypeArg = `${Config.vars.PACKAGE_ID}::${ruleModule}::${ruleType}`

        return SuiClient.getMoveCallBytes({
            signer,
            target: this.getComplianceTarget(func),
            typeArgs: [this.tokenAddress, ruleTypeArg],
            args: [
                this.tokenDetails.complianceConfig,
                this.tokenDetails.auth,
                ...args,
                Config.vars.VERSION
            ],
        })
    }

    // ==== View Functions ====

    async hasRule(ruleType: RuleType, sender: string): Promise<boolean> {
        const ptb = this.buildGetPTB('has_rule', ruleType)
        const result = await SuiClient.devInspectBool(ptb, sender)
        return result ?? false
    }

    // ==== Rule Management Functions ====

    private _registerRulePTB(ptb: Transaction, ruleModule: string, ruleType: string, rule: TransactionResult) {
        ptb.moveCall({
            target: this.getComplianceTarget('register_rule'),
            typeArguments: [
                this.tokenAddress,
                `${Config.vars.PACKAGE_ID}::${ruleModule}::${ruleType}`
            ],
            arguments: [
                ptb.object(this.tokenDetails.complianceConfig),
                ptb.object(this.tokenDetails.auth),
                rule,
                ptb.object(Config.vars.VERSION),
            ],
        })

        return ptb
    }

    registerAccreditedOnlyRulePTB(
        force_accredited?: boolean, // forceAccredited
        force_us_accredited?: boolean, // forceAccreditedUS
        ptb?: Transaction
    ) {
        const ruleType = 'AccreditedOnly';
        const ruleModule = this.getRuleModuleName(ruleType)

        ptb ??= new Transaction()

        const rule = ptb.moveCall({
            target: this.getRuleTarget(ruleModule, 'new'),
            arguments: [
                ptb.pure.bool(!!force_accredited),
                ptb.pure.bool(!!force_us_accredited),
                ptb.object(Config.vars.VERSION)
            ],
        })

        return this._registerRulePTB(ptb, ruleModule, ruleType, rule)
    }

    async registerAccreditedOnlyRule(
        signer: string,
        force_accredited?: boolean, // forceAccredited
        force_us_accredited?: boolean, // forceAccreditedUS
    ) {
        const ptb = this.registerAccreditedOnlyRulePTB(force_accredited, force_us_accredited)
        return SuiClient.getMoveCallBytesFromPTB(ptb, signer)
    }

    registerFlowbackRestrictionRulePTB(
        block_flowback_end_time_ms?: number, // blockFlowbackEndTime
    ) {
        const ruleType = 'FlowbackRestriction';
        const ruleModule = this.getRuleModuleName(ruleType)

        const ptb = new Transaction()

        const rule = ptb.moveCall({
            target: this.getRuleTarget(ruleModule, 'new'),
            arguments: [
                ptb.pure.u64(block_flowback_end_time_ms || 0),
                ptb.object(Config.vars.VERSION)
            ],
        })

        return this._registerRulePTB(ptb, ruleModule, ruleType, rule)
    }
    async registerFlowbackRestrictionRule(
        signer: string,
        block_flowback_end_time_ms?: number, // blockFlowbackEndTime
    ) {
        const ptb = this.registerFlowbackRestrictionRulePTB(block_flowback_end_time_ms)
        return SuiClient.getMoveCallBytesFromPTB(ptb, signer)
    }

    registerForceFullTransferRulePTB(
        force_full_transfer_us?: boolean, // forceFullTransfer
        force_full_transfer_worldwide?: boolean, // worldWideForceFullTransfer
    ) {
        const ruleType = 'ForceFullTransfer';
        const ruleModule = this.getRuleModuleName(ruleType)

        const ptb = new Transaction()

        const rule = ptb.moveCall({
            target: this.getRuleTarget(ruleModule, 'new'),
            arguments: [
                ptb.pure.bool(!!force_full_transfer_us),
                ptb.pure.bool(!!force_full_transfer_worldwide),
                ptb.object(Config.vars.VERSION)
            ],
        })

        return this._registerRulePTB(ptb, ruleModule, ruleType, rule)
    }

    async registerForceFullTransferRule(
        signer: string,
        force_full_transfer_us?: boolean, // forceFullTransfer
        force_full_transfer_worldwide?: boolean, // worldWideForceFullTransfer
    ) {
        const ptb = this.registerForceFullTransferRulePTB(force_full_transfer_us, force_full_transfer_worldwide)
        return SuiClient.getMoveCallBytesFromPTB(ptb, signer)
    }

    registerHoldingLimitsRulePTB(
        min_holdings_per_investor?: number, // minimumHoldingsPerInvestor
        max_holdings_per_investor?: number, // maximumHoldingsPerInvestor
        minUSTokens?: number,
        minEUTokens?: number,
    ) {
        const ruleType = 'HoldingLimits';
        const ruleModule = this.getRuleModuleName(ruleType)
        const regions: Regions[] = []
        const regionMins: number[] = []

        if (minUSTokens) {
            regions.push(Regions.US)
            regionMins.push(minUSTokens)
        }

        if (minEUTokens) {
            regions.push(Regions.EU)
            regionMins.push(minEUTokens)
        }

        const ptb = new Transaction()

        const rule = ptb.moveCall({
            target: this.getRuleTarget(ruleModule, 'new'),
            arguments: [
                ptb.pure.u64(min_holdings_per_investor || 0),
                ptb.pure.u64(max_holdings_per_investor || 0),
                ptb.pure.vector('u64', regions),
                ptb.pure.vector('u64', regionMins),
                ptb.object(Config.vars.VERSION)
            ],
        })

        return this._registerRulePTB(ptb, ruleModule, ruleType, rule)
    }

    registerHoldingLimitsRule(
        signer: string,
        min_holdings_per_investor: number, // minimumHoldingsPerInvestor
        max_holdings_per_investor: number, // maximumHoldingsPerInvestor
        minUSTokens?: number,
        minEUTokens?: number,
    ) {
        const ptb = this.registerHoldingLimitsRulePTB(min_holdings_per_investor, max_holdings_per_investor, minUSTokens, minEUTokens)
        return SuiClient.getMoveCallBytesFromPTB(ptb, signer)
    }

    registerInvestorLimitsRulePTB(
        total_investors_limit?: number, // totalInvestorsLimit
        minimum_total_investors?: number, // minimumTotalInvestors
        us_investors_limit?: number, // usInvestorsLimit
        us_accredited_limit?: number, // usAccreditedInvestorsLimit
        non_accredited_limit?: number, // nonAccreditedInvestorsLimit
        jp_investors_limit?: number, // jpInvestorsLimit
        eu_retail_limit?: number, // euRetailInvestorsLimit
        max_us_percentage?: number, //maxUSInvestorsPercentage
    ) {
        const ruleType = 'InvestorLimits';
        const ruleModule = this.getRuleModuleName(ruleType)

        const ptb = new Transaction()

        const rule = ptb.moveCall({
            target: this.getRuleTarget(ruleModule, 'new'),
            arguments: [
                ptb.pure.u64(total_investors_limit || 0),
                ptb.pure.u64(minimum_total_investors || 0),
                ptb.pure.u64(us_investors_limit || 0),
                ptb.pure.u64(us_accredited_limit || 0),
                ptb.pure.u64(non_accredited_limit || 0),
                ptb.pure.u64(jp_investors_limit || 0),
                ptb.pure.u64(eu_retail_limit || 0),
                ptb.pure.u64(max_us_percentage || 0),
                ptb.object(Config.vars.VERSION)
            ],
        })

        return this._registerRulePTB(ptb, ruleModule, ruleType, rule)
    }

    async registerInvestorLimitsRule(
        signer: string,
        total_investors_limit?: number, // totalInvestorsLimit
        minimum_total_investors?: number, // minimumTotalInvestors
        us_investors_limit?: number, // usInvestorsLimit
        us_accredited_limit?: number, // usAccreditedInvestorsLimit
        non_accredited_limit?: number, // nonAccreditedInvestorsLimit
        jp_investors_limit?: number, // jpInvestorsLimit
        eu_retail_limit?: number, // euRetailInvestorsLimit
        max_us_percentage?: number, //maxUSInvestorsPercentage
    ) {
        const ptb = this.registerInvestorLimitsRulePTB(
            total_investors_limit,
            minimum_total_investors,
            us_investors_limit,
            us_accredited_limit,
            non_accredited_limit,
            jp_investors_limit,
            eu_retail_limit,
            max_us_percentage,
        )
        return SuiClient.getMoveCallBytesFromPTB(ptb, signer)
    }

    async unregisterRule(ruleType: RuleType, signer: string) {
        return this.buildSetPTB(signer, ruleType, 'unregister_rule')
    }

    // ==== Helper Functions ====

    private getRuleModuleName(ruleType: RuleType): string {
        const mapping: Record<RuleType, string> = {
            'AccreditedOnly': 'accredited_only',
            'HoldingLimits': 'holding_limits',
            'InvestorLimits': 'investor_limits',
            'ForceFullTransfer': 'force_full_transfer',
            'FlowbackRestriction': 'flowback_restriction',
        }
        return mapping[ruleType]
    }
}
