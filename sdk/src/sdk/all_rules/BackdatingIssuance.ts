import {Rule} from "./Rule";
import {SuiClient} from "../../easysui";
import {newPTBDetails, PTBDetails} from "../domains";

export class BackdatingIssuance extends Rule {
    constructor(tokenAddress: string) {
        super(tokenAddress, 'BackdatingIssuance', 'backdating_issuance')
    }

    // ==== Registration ====

    registerPTB(
        disallowBackdating?: boolean,
        ptbDetails?: PTBDetails,
    ) {
        ptbDetails ??= newPTBDetails()
        const ptb = ptbDetails.ptb

        const rule = this.newRule(ptb, [
            ptb.pure.bool(!!disallowBackdating)
        ], ptbDetails)

        return this._registerPTB(rule, ptbDetails)
    }

    async register(
        signer: string,
        disallowBackdating?: boolean,
    ) {
        const ptb = this.registerPTB(disallowBackdating)
        return SuiClient.getMoveCallBytesFromPTB(ptb, signer)
    }

    // ==== Setters ====

    setDisallowBackdatingPTB(disallow?: boolean, ptbDetails?: PTBDetails) {
        if (disallow === undefined) {
            return
        }
        ptbDetails ??= newPTBDetails()
        return this.setRule('set_disallow_backdating', [ptbDetails.ptb.pure.bool(disallow)], ptbDetails)
    }

    setDisallowBackdating(disallow: boolean, signer: string) {
        const ptb = this.setDisallowBackdatingPTB(disallow)!
        return SuiClient.getMoveCallBytesFromPTB(ptb, signer)
    }
}
