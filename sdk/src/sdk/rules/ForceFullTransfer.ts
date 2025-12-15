import {Rule} from "./Rule";
import {Transaction} from "@mysten/sui/transactions";
import {SuiClient} from "../../easysui";
import {PTBDetails} from "../domains/ptb_details";

export class ForceFullTransfer extends Rule {
    constructor(tokenAddress: string) {
        super(tokenAddress, 'ForceFullTransfer', 'force_full_transfer')
    }

    registerPTB(
        force_full_transfer_us?: boolean, // forceFullTransfer
        force_full_transfer_worldwide?: boolean, // worldWideForceFullTransfer
        ptbDetails?: PTBDetails,
    ) {
        const ptb = ptbDetails ? ptbDetails.ptb : new Transaction()

        const rule = this.newRule(ptb, [
            ptb.pure.bool(!!force_full_transfer_us),
            ptb.pure.bool(!!force_full_transfer_worldwide),
        ])

        return this._registerPTB(rule, ptbDetails)
    }

    async register(
        signer: string,
        force_full_transfer_us?: boolean, // forceFullTransfer
        force_full_transfer_worldwide?: boolean, // worldWideForceFullTransfer
    ) {
        const ptb = this.registerPTB(force_full_transfer_us, force_full_transfer_worldwide)
        return SuiClient.getMoveCallBytesFromPTB(ptb, signer)
    }
}