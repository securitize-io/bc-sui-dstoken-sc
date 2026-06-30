import {Rule} from "./Rule";
import {SuiClient} from "../../easysui";
import {newPTBDetails, PTBDetails} from "../domains/PTBDetails";

export class InvestorLimits extends Rule {
    constructor(tokenAddress: string) {
        super(tokenAddress, 'InvestorLimits', 'investor_limits')
    }

    // ==== Registration ====

    // u64 fields accept `number` for ergonomics; values above 2^53-1 lose precision in
    // JS Number. Investor counts stay well below that, but pass `bigint` if a caller
    // ever needs the full u64 range.
    registerPTB(
        totalInvestorsLimit?: number,
        minimumTotalInvestors?: number,
        usInvestorsLimit?: number,
        usAccreditedLimit?: number,
        nonAccreditedLimit?: number,
        jpInvestorsLimit?: number,
        euRetailLimit?: number,
        maxUsPercentage?: number,
        ptbDetails?: PTBDetails,
    ) {
        ptbDetails ??= newPTBDetails()
        const ptb = ptbDetails.ptb

        const rule = this.newRule(ptb, [
            ptb.pure.u64(totalInvestorsLimit || 0),
            ptb.pure.u64(minimumTotalInvestors || 0),
            ptb.pure.u64(usInvestorsLimit || 0),
            ptb.pure.u64(usAccreditedLimit || 0),
            ptb.pure.u64(nonAccreditedLimit || 0),
            ptb.pure.u64(jpInvestorsLimit || 0),
            ptb.pure.u64(euRetailLimit || 0),
            ptb.pure.u64(maxUsPercentage || 0),
        ], ptbDetails)

        return this._registerPTB(rule, ptbDetails)
    }

    async register(
        signer: string,
        totalInvestorsLimit?: number,
        minimumTotalInvestors?: number,
        usInvestorsLimit?: number,
        usAccreditedLimit?: number,
        nonAccreditedLimit?: number,
        jpInvestorsLimit?: number,
        euRetailLimit?: number,
        maxUsPercentage?: number,
    ) {
        const ptb = this.registerPTB(
            totalInvestorsLimit,
            minimumTotalInvestors,
            usInvestorsLimit,
            usAccreditedLimit,
            nonAccreditedLimit,
            jpInvestorsLimit,
            euRetailLimit,
            maxUsPercentage,
        )
        return SuiClient.getMoveCallBytesFromPTB(ptb, signer)
    }

    // ==== Setters ====

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
