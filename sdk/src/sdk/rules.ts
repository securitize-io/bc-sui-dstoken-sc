import {SuiClient} from "../easysui";
import {Transaction} from "@mysten/sui/transactions";
import {ComplianceRules} from "./domains";
import {AccreditedOnly} from "./rules/AccreditedOnly";
import {FlowbackRestriction} from "./rules/FlowbackRestriction";
import {ForceFullTransfer} from "./rules/ForceFullTransfer";
import {HoldingLimits} from "./rules/HoldingLimits";
import {InvestorLimits} from "./rules/InvestorLimits";

export class Rules {
    private readonly tokenAddress: string;

    constructor(tokenAddress: string) {
        this.tokenAddress = tokenAddress;
    }

    updatePTB(rules: ComplianceRules, ptb?: Transaction) {
        ptb ??= new Transaction()

        ptb = new AccreditedOnly(this.tokenAddress).registerPTB(rules.forceAccredited, rules.forceAccreditedUS, ptb)
        ptb = new FlowbackRestriction(this.tokenAddress).registerPTB(rules.blockFlowbackEndTime, ptb)
        ptb = new ForceFullTransfer(this.tokenAddress).registerPTB(rules.forceFullTransfer, rules.worldWideForceFullTransfer, ptb)
        ptb = new HoldingLimits(this.tokenAddress).registerPTB(
            BigInt(rules.minimumHoldingsPerInvestor || 0),
            BigInt(rules.maximumHoldingsPerInvestor || 0),
            BigInt(rules.minUSTokens || 0),
            BigInt(rules.minEUTokens || 0),
            ptb
        )
        ptb = new InvestorLimits(this.tokenAddress).registerPTB(
            rules.totalInvestorsLimit,
            rules.minimumTotalInvestors,
            rules.usInvestorsLimit,
            rules.usAccreditedInvestorsLimit,
            rules.nonAccreditedInvestorsLimit,
            rules.jpInvestorsLimit,
            rules.euRetailInvestorsLimit,
            rules.maxUSInvestorsPercentage,
            ptb
        )
        return ptb
    }

    async update(
        signer: string,
        rules: ComplianceRules,
    ) {
        const ptb = this.updatePTB(rules)
        return SuiClient.getMoveCallBytesFromPTB(ptb, signer)
    }
}
