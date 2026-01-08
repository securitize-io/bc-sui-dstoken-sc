import {Rule} from "./Rule";
import {SuiClient} from "../../easysui";
import {newPTBDetails, PTBDetails} from "../domains/PTBDetails";

export class InvestorLimits extends Rule {
    constructor(tokenAddress: string) {
        super(tokenAddress, 'InvestorLimits', 'investor_limits')
    }

    registerPTB(
        total_investors_limit?: number, // totalInvestorsLimit
        minimum_total_investors?: number, // minimumTotalInvestors
        us_investors_limit?: number, // usInvestorsLimit
        us_accredited_limit?: number, // usAccreditedInvestorsLimit
        non_accredited_limit?: number, // nonAccreditedInvestorsLimit
        jp_investors_limit?: number, // jpInvestorsLimit
        eu_retail_limit?: number, // euRetailInvestorsLimit
        max_us_percentage?: number, //maxUSInvestorsPercentage
        ptbDetails?: PTBDetails,
    ) {
        ptbDetails ??= newPTBDetails()
        const ptb = ptbDetails.ptb

        const rule = this.newRule(ptb, [
            ptb.pure.u64(total_investors_limit || 0),
            ptb.pure.u64(minimum_total_investors || 0),
            ptb.pure.u64(us_investors_limit || 0),
            ptb.pure.u64(us_accredited_limit || 0),
            ptb.pure.u64(non_accredited_limit || 0),
            ptb.pure.u64(jp_investors_limit || 0),
            ptb.pure.u64(eu_retail_limit || 0),
            ptb.pure.u64(max_us_percentage || 0),
        ], ptbDetails)

        return this._registerPTB(rule, ptbDetails)
    }

    async register(
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
        const ptb = this.registerPTB(
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
}