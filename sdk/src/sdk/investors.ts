import {SuiClient} from "../easysui";
import {Config} from "./utils/config";
import {getTokenDetails} from "./token";

export async  function registerInvestor(signer: string, tokenAddress: string, investorId: string) {
    const tokenDetails = getTokenDetails(tokenAddress)
    return SuiClient.getMoveCallBytes({
        signer,
        target: `${Config.vars.PACKAGE_ID}::registry_service::register_investor`,
        typeArgs: [tokenAddress],
        args: [
            tokenDetails.investorInfo,
            tokenDetails.auth,
            investorId,
            Config.vars.VERSION
        ],
    })
}