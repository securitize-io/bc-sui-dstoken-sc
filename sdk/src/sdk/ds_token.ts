import { ObjectOwner } from '@mysten/sui/client'
import { normalizeSuiAddress } from '@mysten/sui/utils'
import { MoveType, SuiClient } from 'ts-utils/src/utils/sui_client'
import { ADMIN_KEYPAIR, Config } from 'ts-utils/src/config/config'

interface SuiObjectCreated {
    digest: string
    objectId: string
    objectType: string
    owner: ObjectOwner
    sender: string
    type: 'created'
    version: string
}

export async function create_ds_token() {
    const result = await SuiClient.moveCall({
        signer: ADMIN_KEYPAIR,
        target: `${Config.vars.PACKAGE_ID}::voloro::create_ds_token`,
        args: [Config.vars.SETUP_AUTH, normalizeSuiAddress('0xc')],
        argTypes: [MoveType.object, MoveType.object],
    })

    const treasury = (
        result.objectChanges?.find(
            (x) => x.type === 'created' && x.objectType.includes('ds_token::Treasury')
        ) as SuiObjectCreated
    ).objectId

    return treasury
}
