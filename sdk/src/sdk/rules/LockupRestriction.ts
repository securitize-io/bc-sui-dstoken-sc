import {Rule} from "./Rule";
import {SuiClient} from "../../easysui";
import {newPTBDetails, PTBDetails} from "../domains";

export class LockupRestriction extends Rule {
    constructor(tokenAddress: string) {
        super(tokenAddress, 'LockupRestriction', 'lockup_restriction')
    }

    registerPTB(
        us_lock_period_ms?: number,
        non_us_lock_period_ms?: number,
        ptbDetails?: PTBDetails,
    ) {
        ptbDetails ??= newPTBDetails()
        const ptb = ptbDetails.ptb

        const rule = this.newRule(ptb, [
            ptb.pure.u64(us_lock_period_ms || 0),
            ptb.pure.u64(non_us_lock_period_ms || 0)
        ], ptbDetails)

        return this._registerPTB(rule, ptbDetails)
    }

    async register(
        signer: string,
        us_lock_period_ms?: number,
        non_us_lock_period_ms?: number,
    ) {
        const ptb = this.registerPTB(us_lock_period_ms, non_us_lock_period_ms)
        return SuiClient.getMoveCallBytesFromPTB(ptb, signer)
    }
}
