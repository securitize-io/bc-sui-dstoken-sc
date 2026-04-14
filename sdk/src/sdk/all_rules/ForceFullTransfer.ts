import {Rule} from "./Rule";
import {SuiClient} from "../../easysui";
import {newPTBDetails, PTBDetails} from "../domains/PTBDetails";

export class ForceFullTransfer extends Rule {
    constructor(tokenAddress: string) {
        super(tokenAddress, 'ForceFullTransfer', 'force_full_transfer')
    }

    // ==== Registration ====

    registerPTB(
        forceFullTransferUs?: boolean,
        forceFullTransferWorldwide?: boolean,
        ptbDetails?: PTBDetails,
    ) {
        ptbDetails ??= newPTBDetails()
        const ptb = ptbDetails.ptb

        const rule = this.newRule(ptb, [
            ptb.pure.bool(!!forceFullTransferUs),
            ptb.pure.bool(!!forceFullTransferWorldwide),
        ], ptbDetails)

        return this._registerPTB(rule, ptbDetails)
    }

    async register(
        signer: string,
        forceFullTransferUs?: boolean,
        forceFullTransferWorldwide?: boolean,
    ) {
        const ptb = this.registerPTB(forceFullTransferUs, forceFullTransferWorldwide)
        return SuiClient.getMoveCallBytesFromPTB(ptb, signer)
    }

    // ==== Setters ====

    setForceUsPTB(force?: boolean, ptbDetails?: PTBDetails) {
        if (force === undefined) {
            return
        }
        ptbDetails ??= newPTBDetails()
        return this.setRule('set_force_us', [ptbDetails.ptb.pure.bool(force)], ptbDetails)
    }

    setForceUs(force: boolean, signer: string) {
        const ptb = this.setForceUsPTB(force)!
        return SuiClient.getMoveCallBytesFromPTB(ptb, signer)
    }

    setForceWorldwidePTB(force?: boolean, ptbDetails?: PTBDetails) {
        if (force === undefined) {
            return
        }
        ptbDetails ??= newPTBDetails()
        return this.setRule('set_force_worldwide', [ptbDetails.ptb.pure.bool(force)], ptbDetails)
    }

    setForceWorldwide(force: boolean, signer: string) {
        const ptb = this.setForceWorldwidePTB(force)!
        return SuiClient.getMoveCallBytesFromPTB(ptb, signer)
    }
}
