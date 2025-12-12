import {ADMIN_KEYPAIR, createDSToken, DeploymentRequest, SuiClient} from "../src";

export const testTokenRequest: DeploymentRequest = {
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

export async function createTestToken() {
    const res = await createDSToken(testTokenRequest)
    return res.id
}

export async function executeTxFunc(promise: Promise<string>) {
    const bytes = await promise
    await SuiClient.executeMoveCallBytes(bytes, ADMIN_KEYPAIR!)
}