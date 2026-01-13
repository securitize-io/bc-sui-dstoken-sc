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

    setTotalLimitPTB(limit?: number, ptbDetails?: PTBDetails) {
        if (limit === undefined) {
            return
        }
        ptbDetails ??= newPTBDetails()
        return this.setRule('set_total_limit', [ptbDetails.ptb.pure.u64(limit)], ptbDetails)
    }

    setTotalLimit(limit: number, signer: string) {
        const ptb = this.setTotalLimitPTB(limit)!
        return SuiClient.getMoveCallBytesFromPTB(ptb, signer)
    }

    setMinimumTotalInvestorsPTB(minimum?: number, ptbDetails?: PTBDetails) {
        if (minimum === undefined) {
            return
        }
        ptbDetails ??= newPTBDetails()
        return this.setRule('set_minimum_total_investors', [ptbDetails.ptb.pure.u64(minimum)], ptbDetails)
    }

    setMinimumTotalInvestors(minimum: number, signer: string) {
        const ptb = this.setMinimumTotalInvestorsPTB(minimum)!
        return SuiClient.getMoveCallBytesFromPTB(ptb, signer)
    }

    setUsLimitPTB(limit?: number, ptbDetails?: PTBDetails) {
        if (limit === undefined) {
            return
        }
        ptbDetails ??= newPTBDetails()
        return this.setRule('set_us_limit', [ptbDetails.ptb.pure.u64(limit)], ptbDetails)
    }

    setUsLimit(limit: number, signer: string) {
        const ptb = this.setUsLimitPTB(limit)!
        return SuiClient.getMoveCallBytesFromPTB(ptb, signer)
    }

    setUsAccreditedLimitPTB(limit?: number, ptbDetails?: PTBDetails) {
        if (limit === undefined) {
            return
        }
        ptbDetails ??= newPTBDetails()
        return this.setRule('set_us_accredited_limit', [ptbDetails.ptb.pure.u64(limit)], ptbDetails)
    }

    setUsAccreditedLimit(limit: number, signer: string) {
        const ptb = this.setUsAccreditedLimitPTB(limit)!
        return SuiClient.getMoveCallBytesFromPTB(ptb, signer)
    }

    setNonAccreditedLimitPTB(limit?: number, ptbDetails?: PTBDetails) {
        if (limit === undefined) {
            return
        }
        ptbDetails ??= newPTBDetails()
        return this.setRule('set_non_accredited_limit', [ptbDetails.ptb.pure.u64(limit)], ptbDetails)
    }

    setNonAccreditedLimit(limit: number, signer: string) {
        const ptb = this.setNonAccreditedLimitPTB(limit)!
        return SuiClient.getMoveCallBytesFromPTB(ptb, signer)
    }

    setJpLimitPTB(limit?: number, ptbDetails?: PTBDetails) {
        if (limit === undefined) {
            return
        }
        ptbDetails ??= newPTBDetails()
        return this.setRule('set_jp_limit', [ptbDetails.ptb.pure.u64(limit)], ptbDetails)
    }

    setJpLimit(limit: number, signer: string) {
        const ptb = this.setJpLimitPTB(limit)!
        return SuiClient.getMoveCallBytesFromPTB(ptb, signer)
    }

    setEuRetailLimitPTB(limit?: number, ptbDetails?: PTBDetails) {
        if (limit === undefined) {
            return
        }
        ptbDetails ??= newPTBDetails()
        return this.setRule('set_eu_retail_limit', [ptbDetails.ptb.pure.u64(limit)], ptbDetails)
    }

    setEuRetailLimit(limit: number, signer: string) {
        const ptb = this.setEuRetailLimitPTB(limit)!
        return SuiClient.getMoveCallBytesFromPTB(ptb, signer)
    }

    setMaxUsPercentagePTB(percentage?: number, ptbDetails?: PTBDetails) {
        if (percentage === undefined) {
            return
        }
        ptbDetails ??= newPTBDetails()
        return this.setRule('set_max_us_percentage', [ptbDetails.ptb.pure.u64(percentage)], ptbDetails)
    }

    setMaxUsPercentage(percentage: number, signer: string) {
        const ptb = this.setMaxUsPercentagePTB(percentage)!
        return SuiClient.getMoveCallBytesFromPTB(ptb, signer)
    }
}