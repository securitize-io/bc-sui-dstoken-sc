import {Rule} from "./Rule";
import {Transaction} from "@mysten/sui/transactions";
import {SuiClient} from "../../easysui";
import {PTBDetails} from "../domains/ptb_details";

export class AccreditedOnly extends Rule {
    constructor(tokenAddress: string) {
        super(tokenAddress, 'AccreditedOnly', 'accredited_only')
    }

    registerPTB(
        force_accredited?: boolean, // forceAccredited
        force_us_accredited?: boolean, // forceAccreditedUS
        ptbDetails?: PTBDetails,
    ) {
        const ptb = ptbDetails ? ptbDetails.ptb : new Transaction()

        const rule = this.newRule(ptb, [
            ptb.pure.bool(!!force_accredited),
            ptb.pure.bool(!!force_us_accredited)
        ])

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