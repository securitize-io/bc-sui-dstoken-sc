import {normalizeSuiAddress} from '@mysten/sui/utils'
import {ADMIN_KEYPAIR, SuiClient} from '../easysui'
import {Config} from "./utils/config";
import {DeploymentRequest} from "./domains";
import {Transaction} from "@mysten/sui/transactions";

export async function create_ds_token(request: DeploymentRequest) {
    //TODO: deploy token contract first

    const ptb = new Transaction()
    const tokenSymbol = request.tokenDescription.symbol

    const [
        auth,
        treasury,
        investorInfo,
        complianceConfig,
        setupFinalize
    ] = ptb.moveCall({
        target: `${Config.vars.PACKAGE_ID}::${tokenSymbol}::create_ds_token`,
        arguments: [
            ptb.pure.string(tokenSymbol),
            ptb.pure.string(tokenSymbol),
            ptb.pure.string("https://aggregator.walrus-mainnet.h2o-nodes.com/v1/blobs/DYlIcfM32ICsXfTJR69kQ6Vv4roYnQbOvoUbRiwsg6g"),
            ptb.pure.u8(request.tokenDescription.decimals),
            ptb.object(Config.vars.SETUP_AUTH),
            ptb.object(Config.vars.RWA_REGISTRY),
            ptb.object(normalizeSuiAddress('0xc')),
            ptb.object(Config.vars.VERSION),
        ],
    })

    // TODO: Add extra rules to compliance here

    ptb.moveCall({
        target: `${Config.vars.PACKAGE_ID}::setup::finalize_setup`,
        typeArguments: [`${Config.vars.PACKAGE_ID}::${tokenSymbol}::${tokenSymbol.toUpperCase()}`],
        arguments: [
            setupFinalize,
            auth,
            treasury,
            investorInfo,
            complianceConfig,
            ptb.object(Config.vars.VERSION)
        ]
    })

    const result = await SuiClient.signAndExecute(ptb, ADMIN_KEYPAIR!)

    console.log(result);
    
    return result

    // return {
    //     id: "", //TODO: get token id / address
    // }
}
