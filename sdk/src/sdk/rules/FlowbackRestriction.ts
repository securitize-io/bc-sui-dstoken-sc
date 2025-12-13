import {Rule} from "./Rule";
import {Transaction} from "@mysten/sui/transactions";
import {SuiClient} from "../../easysui";

export class FlowbackRestriction extends Rule {
    constructor(tokenAddress: string) {
        super(tokenAddress, 'FlowbackRestriction', 'flowback_restriction')
    }

    registerPTB(
        block_flowback_end_time_ms?: number, // blockFlowbackEndTime
        ptb?: Transaction
    ) {
        ptb ??= new Transaction()

        const rule = this.newRule(ptb, [
            ptb.pure.u64(block_flowback_end_time_ms || 0),
        ])

        return this._registerPTB(ptb, rule)
    }

    async register(
        signer: string,
        block_flowback_end_time_ms?: number, // blockFlowbackEndTime
    ) {
        const ptb = this.registerPTB(block_flowback_end_time_ms)
        return SuiClient.getMoveCallBytesFromPTB(ptb, signer)
    }
}