import {SuiClient} from "../easysui";
import {Config} from "./utils/config";

export async  function registerInvestor(signer: string, tokenAddress: string, investorId: string) {
    // TODO: Get the details using tokenAddress from onchain
    const investorInfo = "0x0f7a929560b1b6b0f8ac9cdcc707b66e49993da2ebcdf95ef776925cd228e02c"
    const auth = "0xb831d9961cbe7d565e860dad67a0f834ab93a0c1611f06a839a487e1edd4e763"

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