import {createDSToken} from "../sdk/ds_token";
import {DeploymentRequest} from "../sdk/domains";

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

export async function deployToken() {
    await createDSToken(request)
}

deployToken().then()