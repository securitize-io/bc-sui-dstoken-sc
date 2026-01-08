import {Rule} from "./Rule";
import {SuiClient} from "../../easysui";
import {newPTBDetails, PTBDetails} from "../domains/PTBDetails";

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
}