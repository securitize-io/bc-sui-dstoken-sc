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

    setUsLockPeriodPTB(periodMs?: number, ptbDetails?: PTBDetails) {
        if (periodMs === undefined) {
            return
        }
        ptbDetails ??= newPTBDetails()
        return this.setRule('set_us_lock_period', [ptbDetails.ptb.pure.u64(periodMs)], ptbDetails)
    }

    setUsLockPeriod(periodMs: number, signer: string) {
        const ptb = this.setUsLockPeriodPTB(periodMs)!
        return SuiClient.getMoveCallBytesFromPTB(ptb, signer)
    }

    setNonUsLockPeriodPTB(periodMs?: number, ptbDetails?: PTBDetails) {
        if (periodMs === undefined) {
            return
        }
        ptbDetails ??= newPTBDetails()
        return this.setRule('set_non_us_lock_period', [ptbDetails.ptb.pure.u64(periodMs)], ptbDetails)
    }

    setNonUsLockPeriod(periodMs: number, signer: string) {
        const ptb = this.setNonUsLockPeriodPTB(periodMs)!
        return SuiClient.getMoveCallBytesFromPTB(ptb, signer)
    }
}
