import {Rule} from "./Rule";
import {SuiClient} from "../../easysui";
import {Regions} from "../domains";
import {newPTBDetails, PTBDetails} from "../domains/PTBDetails";

export class HoldingLimits extends Rule {
    constructor(tokenAddress: string) {
        super(tokenAddress, 'HoldingLimits', 'holding_limits')
    }

    registerPTB(
        min_holdings_per_investor?: bigint, // minimumHoldingsPerInvestor
        max_holdings_per_investor?: bigint, // maximumHoldingsPerInvestor
        minUSTokens?: bigint, // minUSTokens
        minEUTokens?: bigint, // minEUTokens
        ptbDetails?: PTBDetails,
    ) {
        ptbDetails ??= newPTBDetails()
        const ptb = ptbDetails.ptb

        const regions: Regions[] = []
        const regionMins: bigint[] = []

        if (minUSTokens) {
            regions.push(Regions.US)
            regionMins.push(minUSTokens)
        }

        if (minEUTokens) {
            regions.push(Regions.EU)
            regionMins.push(minEUTokens)
        }

        const rule = this.newRule(ptb, [
            ptb.pure.u64(min_holdings_per_investor || 0),
            ptb.pure.u64(max_holdings_per_investor || 0),
            ptb.pure.vector('u64', regions),
            ptb.pure.vector('u64', regionMins),
        ], ptbDetails)

        return this._registerPTB(rule, ptbDetails)
    }

    async register(
        signer: string,
        min_holdings_per_investor: bigint, // minimumHoldingsPerInvestor
        max_holdings_per_investor: bigint, // maximumHoldingsPerInvestor
        minUSTokens?: bigint,
        minEUTokens?: bigint,
    ) {
        const ptb = this.registerPTB(min_holdings_per_investor, max_holdings_per_investor, minUSTokens, minEUTokens)
        return SuiClient.getMoveCallBytesFromPTB(ptb, signer)
    }
}