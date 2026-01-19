import {Rule} from "./Rule";
import {SuiClient} from "../../easysui";
import {newPTBDetails, PTBDetails} from "../domains/PTBDetails";

export class FlowbackRestriction extends Rule {
    constructor(tokenAddress: string) {
        super(tokenAddress, 'FlowbackRestriction', 'flowback_restriction')
    }

    registerPTB(
        block_flowback_end_time_ms?: number, // blockFlowbackEndTime
        ptbDetails?: PTBDetails,
    ) {
        ptbDetails ??= newPTBDetails()
        const ptb = ptbDetails.ptb

        const rule = this.newRule(ptb, [
            ptb.pure.u64(block_flowback_end_time_ms || 0),
        ], ptbDetails)

        return this._registerPTB(rule, ptbDetails)
    }

    async register(
        signer: string,
        block_flowback_end_time_ms?: number, // blockFlowbackEndTime
    ) {
        const ptb = this.registerPTB(block_flowback_end_time_ms)
        return SuiClient.getMoveCallBytesFromPTB(ptb, signer)
    }

    setFlowbackEndTimePTB(endTimeMs?: number, ptbDetails?: PTBDetails) {
        if (endTimeMs === undefined) {
            return
        }
        ptbDetails ??= newPTBDetails()
        return this.setRule('set_flowback_end_time', [ptbDetails.ptb.pure.u64(endTimeMs)], ptbDetails)
    }

    setFlowbackEndTime(endTimeMs: number, signer: string) {
        const ptb = this.setFlowbackEndTimePTB(endTimeMs)!
        return SuiClient.getMoveCallBytesFromPTB(ptb, signer)
    }
}