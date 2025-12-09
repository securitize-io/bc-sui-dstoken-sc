import {SuiObjectChangeCreated} from '@mysten/sui/client'
import {normalizeSuiAddress} from '@mysten/sui/utils'
import {ADMIN_KEYPAIR, MoveType, SuiClient} from '@easysui/sdk'
import {Config} from "./utils/config";
import {DeploymentRequest} from "./domains";

export async function create_ds_token(request: DeploymentRequest) {
    const result = await SuiClient.moveCall({
        signer: ADMIN_KEYPAIR,
        target: `${Config.vars.PACKAGE_ID}::voloro::create_ds_token`,
        args: [
            request.tokenDescription.name,
            request.tokenDescription.symbol,
            "https://aggregator.walrus-mainnet.h2o-nodes.com/v1/blobs/DYlIcfM32ICsXfTJR69kQ6Vv4roYnQbOvoUbRiwsg6g",
            request.tokenDescription.decimals,
            Config.vars.SETUP_AUTH,
            Config.vars.RWA_REGISTRY,
            normalizeSuiAddress('0xc'),
            Config.vars.VERSION,
        ],
        argTypes: [
            MoveType.string,
            MoveType.string,
            MoveType.string,
            MoveType.u8,
        ],
    })

    const treasury = (
        result.objectChanges?.find(
            (x) => x.type === 'created' && x.objectType.includes('ds_token::Treasury')
        ) as SuiObjectChangeCreated
    ).objectId

    return result

    // return {
    //     id: "", //TODO: get token id / address
    // }
}
