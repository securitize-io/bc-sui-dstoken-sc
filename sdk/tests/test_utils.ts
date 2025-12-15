import {ADMIN_KEYPAIR, createDSToken, DeploymentRequest, SuiClient} from "../src";
import {Keypair} from "@mysten/sui/cryptography";

export const testTokenRequest: DeploymentRequest = {
    tokenDescription: {
        name: "VOLORO",
        symbol: "VOLORO",
        decimals: 6,
        type: 'standard',
        tokenMultiplier: '',
        iconUri: 'https://strapi-dev.scand.app/uploads/sui_c07df05f00.png',
        description: 'This is a test securitize token'
    },
    complianceType: 'regulated',
    lockManagerType: 'investor',
    complianceRules: {
        forceAccredited: false,
        forceAccreditedUS: true,
        blockFlowbackEndTime: 1000000,
        worldWideForceFullTransfer: true,
        forceFullTransfer: false,
        minUSTokens: "100000000",
        minEUTokens: "100000000",
        minimumHoldingsPerInvestor: "10000000",
        maximumHoldingsPerInvestor: "10000000",
        totalInvestorsLimit: 1000000000000000,
        usInvestorsLimit: 1000000000000000,
        euRetailInvestorsLimit: 1000000000000000,
        jpInvestorsLimit: 1000000000000000,
        usAccreditedInvestorsLimit: 1000000000,
        nonAccreditedInvestorsLimit: 1000000000,
        maxUSInvestorsPercentage: 1000000000,
        minimumTotalInvestors: 1000000000,
        nonUSLockPeriod: 1000000000,
        usLockPeriod: 1000,
        disallowBackDating: true,
        authorizedSecurities: "10000",
    },
    roles: []
}

export async function createTestToken() {
    const res = await createDSToken(testTokenRequest)
    return res.id
}

export async function executeTxFunc(promise: Promise<string>, signer?: Keypair) {
    signer ??= ADMIN_KEYPAIR!
    const bytes = await promise
    await SuiClient.executeMoveCallBytes(bytes, signer)
}