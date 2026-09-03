import {Rule} from "./Rule";
import {SuiClient} from "../../easysui";
import {newPTBDetails, PTBDetails} from "../domains/PTBDetails";

export class FlowbackRestriction extends Rule {
    constructor(tokenAddress: string) {
        super(tokenAddress, 'FlowbackRestriction', 'flowback_restriction')
    }

    // ==== Registration ====

    registerPTB(
        blockFlowbackEndTimeMs?: number,
        ptbDetails?: PTBDetails,
    ) {
        ptbDetails ??= newPTBDetails()
        const ptb = ptbDetails.ptb

        const rule = this.newRule(ptb, [
            ptb.pure.u64(blockFlowbackEndTimeMs ?? 1),
        ], ptbDetails)

        return this._registerPTB(rule, ptbDetails)
    }

    async register(
        signer: string,
        blockFlowbackEndTimeMs?: number,
    ) {
        const ptb = this.registerPTB(blockFlowbackEndTimeMs)
        return SuiClient.getMoveCallBytesFromPTB(ptb, signer)
    }

    // ==== Setters ====

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
