import {deploy as baseDeploy} from '@easysui/sdk'
import {Config} from "./config";
import {create_ds_token} from "../ds_token";
import {DeploymentRequest} from "../domains";

const request: DeploymentRequest = {
    tokenDescription: {
        name: "VOLORO",
        symbol: "VOLORO",
        decimals: 6,
        type: 'standard',
        tokenMultiplier: ''
    },
    complianceType: 'notRegulated',
    lockManagerType: 'wallet',
    roles: []
}

export async function deploy() {
    const deployMsg = await baseDeploy(Config)
    await create_ds_token(request)
    return deployMsg
}