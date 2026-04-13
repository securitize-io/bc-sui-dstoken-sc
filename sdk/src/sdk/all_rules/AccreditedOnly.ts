import {Rule} from "./Rule";
import {SuiClient} from "../../easysui";
import {newPTBDetails, PTBDetails} from "../domains";

export class AccreditedOnly extends Rule {
    constructor(tokenAddress: string) {
        super(tokenAddress, 'AccreditedOnly', 'accredited_only')
    }

    // ==== Registration ====

    registerPTB(
        forceAccredited?: boolean,
        forceUsAccredited?: boolean,
        ptbDetails?: PTBDetails,
    ) {
        ptbDetails ??= newPTBDetails()
        const ptb = ptbDetails.ptb

        const rule = this.newRule(ptb, [
            ptb.pure.bool(!!forceAccredited),
            ptb.pure.bool(!!forceUsAccredited)
        ], ptbDetails)

        return this._registerPTB(rule, ptbDetails)
    }

    async register(
        signer: string,
        forceAccredited?: boolean,
        forceUsAccredited?: boolean,
    ) {
        const ptb = this.registerPTB(forceAccredited, forceUsAccredited)
        return SuiClient.getMoveCallBytesFromPTB(ptb, signer)
    }

    // ==== Setters ====

    setForceAccreditedPTB(force?: boolean, ptbDetails?: PTBDetails) {
        if (force === undefined) {
            return
        }
        ptbDetails ??= newPTBDetails()
        return this.setRule('set_force_accredited', [ptbDetails.ptb.pure.bool(force)], ptbDetails)
    }

    setForceAccredited(force: boolean, signer: string) {
        const ptb = this.setForceAccreditedPTB(force)!
        return SuiClient.getMoveCallBytesFromPTB(ptb, signer)
    }

    setForceUsAccreditedPTB(force?: boolean, ptbDetails?: PTBDetails) {
        if (force === undefined) {
            return
        }
        ptbDetails ??= newPTBDetails()
        return this.setRule('set_force_us_accredited', [ptbDetails.ptb.pure.bool(force)], ptbDetails)
    }

    setForceUsAccredited(force: boolean, signer: string) {
        const ptb = this.setForceUsAccreditedPTB(force)!
        return SuiClient.getMoveCallBytesFromPTB(ptb, signer)
    }
}
