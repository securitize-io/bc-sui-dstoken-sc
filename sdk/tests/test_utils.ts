import {
    ADMIN_KEYPAIR,
    ComplianceRules,
    CountryComplianceStatus,
    createDSToken,
    createWallet,
    DeploymentRequest,
    Investors,
    Owners,
    SuiClient,
} from '../src'
import { Keypair } from '@mysten/sui/cryptography'

export const testTokenRequest: DeploymentRequest = {
    tokenDescription: {
        name: 'VOLORO',
        symbol: 'VOLORO',
        decimals: 6,
        type: 'standard',
        tokenMultiplier: '',
        iconUri: 'https://strapi-dev.scand.app/uploads/sui_c07df05f00.png',
        description: 'This is a test securitize token',
    },
    complianceType: 'regulated',
    lockManagerType: 'investor',
    roles: [],
}

export const complianceRules = {
    forceAccredited: false,
    forceAccreditedUS: false,
    blockFlowbackEndTime: 1000000,
    worldWideForceFullTransfer: false,
    forceFullTransfer: false,
    minUSTokens: '100000000',
    minEUTokens: '100000000',
    minimumHoldingsPerInvestor: '10000000',
    maximumHoldingsPerInvestor: '10000000',
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
    disallowBackDating: false,
    authorizedSecurities: '10000',
}

export const countriesComplianceStatuses: CountryComplianceStatus[] = [
    {
        countryName: 'GR',
        complianceStatus: 'eu',
    },
    {
        countryName: 'US',
        complianceStatus: 'us',
    },
    {
        countryName: 'JP',
        complianceStatus: 'jp',
    },
    {
        countryName: 'NK',
        complianceStatus: 'forbidden',
    },
]

export const owners: Owners = {
    tokenOwner: ADMIN_KEYPAIR!.toSuiAddress(),
    walletRegistrarOwner: createWallet().toSuiAddress(),
    walletRegistrarOwnerType: createWallet().toSuiAddress(),
    redemptionAddress: createWallet().toSuiAddress(),
    omnibusTBEAddress: createWallet().toSuiAddress(),
}

export async function createTestToken(
    complianceRules?: ComplianceRules,
    countriesComplianceStatuses?: CountryComplianceStatus[],
    owners?: Owners
) {
    testTokenRequest.complianceRules = complianceRules
    testTokenRequest.countriesComplianceStatuses = countriesComplianceStatuses
    testTokenRequest.owners = owners
    const res = await createDSToken(testTokenRequest)
    return res.id
}

export function assertToken(actual: string, req: DeploymentRequest = testTokenRequest) {
    const tokenDescription = req.tokenDescription
    const regex = new RegExp(
        `^0x[0-9a-fA-F]+::${tokenDescription.name.toLowerCase()}::${tokenDescription.symbol}$`
    )
    expect(actual).toMatch(regex)
}

export async function executeTxFunc(promise: Promise<string>, signer?: Keypair) {
    signer ??= ADMIN_KEYPAIR!
    const bytes = await promise
    await SuiClient.executeMoveCallBytes(bytes, signer)
}

export async function registerInvestor(
    tokenAddress: string,
    investorId: string,
    wallets?: string[],
    signer?: Keypair
) {
    signer ??= ADMIN_KEYPAIR!
    const signerAddress = signer.toSuiAddress()
    const investors = new Investors(tokenAddress)
    await executeTxFunc(investors.registerInvestor(investorId, signerAddress), signer)

    wallets ??= [signerAddress]
    for (const w of wallets) {
        await executeTxFunc(investors.addWallet(investorId, w, signerAddress), signer)
    }
}

export async function assertInvestorBalance(
    tokenAddress: string,
    investorId: string,
    balance: string
) {
    const investors = new Investors(tokenAddress)
    const details = await investors.getInvestorDetails(investorId)
    expect(details.totalBalance).toBe(balance)
}
