import {Rule} from "./Rule";
import {SuiClient} from "../../easysui";
import {newPTBDetails, PTBDetails} from "../domains";

export class AuthorizedSecurities extends Rule {
    constructor(tokenAddress: string) {
        super(tokenAddress, 'AuthorizedSecurities', 'authorized_securities')
    }

    registerPTB(
        max_supply?: bigint,
        ptbDetails?: PTBDetails,
    ) {
        ptbDetails ??= newPTBDetails()
        const ptb = ptbDetails.ptb

        const rule = this.newRule(ptb, [
            ptb.pure.u64(max_supply || 0)
        ], ptbDetails)

        return this._registerPTB(rule, ptbDetails)
    }

    async register(
        signer: string,
        max_supply?: bigint,
    ) {
        const ptb = this.registerPTB(max_supply)
        return SuiClient.getMoveCallBytesFromPTB(ptb, signer)
    }

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
