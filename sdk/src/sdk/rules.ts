import {SuiClient} from "../easysui";
import {ComplianceRules} from "./domains";
import {AccreditedOnly} from "./rules/AccreditedOnly";
import {FlowbackRestriction} from "./rules/FlowbackRestriction";
import {ForceFullTransfer} from "./rules/ForceFullTransfer";
import {HoldingLimits} from "./rules/HoldingLimits";
import {InvestorLimits} from "./rules/InvestorLimits";
import {newPTBDetails, PTBDetails} from "./domains/PTBDetails";

export class Rules {
    private readonly tokenAddress: string;

    constructor(tokenAddress: string) {
        this.tokenAddress = tokenAddress;
    }

    updatePTB(
        rules: ComplianceRules,
        ptbDetails?: PTBDetails,
    ) {
        ptbDetails ??= newPTBDetails()
        const ptb = ptbDetails.ptb

       new AccreditedOnly(this.tokenAddress).registerPTB(rules.forceAccredited, rules.forceAccreditedUS, ptbDetails)
       new FlowbackRestriction(this.tokenAddress).registerPTB(rules.blockFlowbackEndTime, ptbDetails)
       new ForceFullTransfer(this.tokenAddress).registerPTB(rules.forceFullTransfer, rules.worldWideForceFullTransfer, ptbDetails)
       new HoldingLimits(this.tokenAddress).registerPTB(
            BigInt(rules.minimumHoldingsPerInvestor || 0),
            BigInt(rules.maximumHoldingsPerInvestor || 0),
            BigInt(rules.minUSTokens || 0),
            BigInt(rules.minEUTokens || 0),
            ptbDetails,
        )
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
