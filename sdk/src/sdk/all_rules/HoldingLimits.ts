import {Rule} from "./Rule";
import {SuiClient} from "../../easysui";
import {Regions} from "../domains";
import {newPTBDetails, PTBDetails} from "../domains/PTBDetails";

export class HoldingLimits extends Rule {
    constructor(tokenAddress: string) {
        super(tokenAddress, 'HoldingLimits', 'holding_limits')
    }

    // ==== Registration ====

    registerPTB(
        minHoldingsPerInvestor?: bigint,
        maxHoldingsPerInvestor?: bigint,
        minUSTokens?: bigint,
        minEUTokens?: bigint,
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
            ptb.pure.u64(minHoldingsPerInvestor || 0),
            ptb.pure.u64(maxHoldingsPerInvestor || 0),
            ptb.pure.vector('u64', regions),
            ptb.pure.vector('u64', regionMins),
        ], ptbDetails)

        return this._registerPTB(rule, ptbDetails)
    }

    async register(
        signer: string,
        minHoldingsPerInvestor: bigint,
        maxHoldingsPerInvestor: bigint,
        minUSTokens?: bigint,
        minEUTokens?: bigint,
    ) {
        const ptb = this.registerPTB(minHoldingsPerInvestor, maxHoldingsPerInvestor, minUSTokens, minEUTokens)
        return SuiClient.getMoveCallBytesFromPTB(ptb, signer)
    }

    // ==== Setters ====

    setMinHoldingsPTB(minHoldings?: bigint, ptbDetails?: PTBDetails) {
        if (minHoldings === undefined) {
            return
        }
        ptbDetails ??= newPTBDetails()
        return this.setRule('set_min_holdings', [ptbDetails.ptb.pure.u64(minHoldings)], ptbDetails)
    }

    setMinHoldings(minHoldings: bigint, signer: string) {
        const ptb = this.setMinHoldingsPTB(minHoldings)!
        return SuiClient.getMoveCallBytesFromPTB(ptb, signer)
    }

    setMaxHoldingsPTB(maxHoldings?: bigint, ptbDetails?: PTBDetails) {
        if (maxHoldings === undefined) {
            return
        }
        ptbDetails ??= newPTBDetails()
        return this.setRule('set_max_holdings', [ptbDetails.ptb.pure.u64(maxHoldings)], ptbDetails)
    }

    setMaxHoldings(maxHoldings: bigint, signer: string) {
        const ptb = this.setMaxHoldingsPTB(maxHoldings)!
        return SuiClient.getMoveCallBytesFromPTB(ptb, signer)
    }

    setRegionMinHoldingsPTB(region?: Regions, minHoldings?: bigint, ptbDetails?: PTBDetails) {
        if (region === undefined || minHoldings === undefined) {
            return
        }
        ptbDetails ??= newPTBDetails()
        return this.setRule('set_region_min_holdings', [
            ptbDetails.ptb.pure.u64(region),
            ptbDetails.ptb.pure.u64(minHoldings)
        ], ptbDetails)
    }

    setRegionMinHoldings(region: Regions, minHoldings: bigint, signer: string) {
        const ptb = this.setRegionMinHoldingsPTB(region, minHoldings)!
        return SuiClient.getMoveCallBytesFromPTB(ptb, signer)
    }
}
