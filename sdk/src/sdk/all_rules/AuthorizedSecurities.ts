import {Rule} from "./Rule";
import {SuiClient} from "../../easysui";
import {newPTBDetails, PTBDetails} from "../domains";

export class AuthorizedSecurities extends Rule {
    constructor(tokenAddress: string) {
        super(tokenAddress, 'AuthorizedSecurities', 'authorized_securities')
    }

    // ==== Registration ====

    registerPTB(
        maxSupply?: bigint,
        ptbDetails?: PTBDetails,
    ) {
        ptbDetails ??= newPTBDetails()
        const ptb = ptbDetails.ptb

        const rule = this.newRule(ptb, [
            ptb.pure.u64(maxSupply || 0)
        ], ptbDetails)

        return this._registerPTB(rule, ptbDetails)
    }

    async register(
        signer: string,
        maxSupply?: bigint,
    ) {
        const ptb = this.registerPTB(maxSupply)
        return SuiClient.getMoveCallBytesFromPTB(ptb, signer)
    }

    // ==== Setters ====

    setMaxSupplyPTB(maxSupply?: bigint, ptbDetails?: PTBDetails) {
        if (maxSupply === undefined) {
            return
        }
        ptbDetails ??= newPTBDetails()
        return this.setRule('set_max_supply', [ptbDetails.ptb.pure.u64(maxSupply)], ptbDetails)
    }

    setMaxSupply(maxSupply: bigint, signer: string) {
        const ptb = this.setMaxSupplyPTB(maxSupply)!
        return SuiClient.getMoveCallBytesFromPTB(ptb, signer)
    }
}
