import {Rule} from "./Rule";
import {SuiClient} from "../../easysui";
import {newPTBDetails, PTBDetails} from "../domains";

export class AccreditedOnly extends Rule {
    constructor(tokenAddress: string) {
        super(tokenAddress, 'AccreditedOnly', 'accredited_only')
    }

    registerPTB(
        force_accredited?: boolean, // forceAccredited
        force_us_accredited?: boolean, // forceAccreditedUS
        ptbDetails?: PTBDetails,
    ) {
        ptbDetails ??= newPTBDetails()
        const ptb = ptbDetails.ptb

        const rule = this.newRule(ptb, [
            ptb.pure.bool(!!force_accredited),
            ptb.pure.bool(!!force_us_accredited)
        ], ptbDetails)

        return this._registerPTB(rule, ptbDetails)
    }

    async register(
        signer: string,
        force_accredited?: boolean, // forceAccredited
        force_us_accredited?: boolean, // forceAccreditedUS
    ) {
        const ptb = this.registerPTB(force_accredited, force_us_accredited)
        return SuiClient.getMoveCallBytesFromPTB(ptb, signer)
    }

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
        const ptb = this.setForceAccreditedPTB(force)!
        return SuiClient.getMoveCallBytesFromPTB(ptb, signer)
    }
}