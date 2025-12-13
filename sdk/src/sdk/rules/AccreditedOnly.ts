import {Rule} from "./Rule";
import {Transaction} from "@mysten/sui/transactions";
import {SuiClient} from "../../easysui";

export class AccreditedOnly extends Rule {
    constructor(tokenAddress: string) {
        super(tokenAddress, 'AccreditedOnly', 'accredited_only')
    }

    registerPTB(
        force_accredited?: boolean, // forceAccredited
        force_us_accredited?: boolean, // forceAccreditedUS
        ptb?: Transaction
    ) {
        ptb ??= new Transaction()

        const rule = this.newRule(ptb, [
            ptb.pure.bool(!!force_accredited),
            ptb.pure.bool(!!force_us_accredited)
        ])

        return this._registerPTB(ptb, rule)
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