import {SuiClient} from "../easysui";
import {Config} from "./utils/config";

export async  function registerInvestor(signer: string, tokenAddress: string, investorId: string) {
    // TODO: Get the details using tokenAddress from onchain
    const investorInfo = "0xac6adbf2dc4110fd5c4726c5b3ecbf364612f67715eb5c167cca723722c28ae7"
    const auth = "0xc7f2d9c5804bc781899bd745332cc41c2fb373ec5f00cc0043e8a7ce477b162a"

    return SuiClient.getMoveCallBytes({
        signer,
        target: `${Config.vars.PACKAGE_ID}::registry_service::register_investor`,
        typeArgs: [tokenAddress],
        args: [
            investorInfo,
            auth,
            investorId,
            Config.vars.VERSION
        ],
    })
}