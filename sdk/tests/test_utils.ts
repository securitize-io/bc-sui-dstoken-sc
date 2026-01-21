import {
    ADMIN_KEYPAIR,
    ComplianceRules,
    CountryComplianceStatus,
    createDSToken,
    DeploymentRequest,
    Investors,
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
    blockFlowbackEndTime: 0,
    worldWideForceFullTransfer: false,
    forceFullTransfer: false,
    minUSTokens: '0',
    minEUTokens: '0',
    minimumHoldingsPerInvestor: '0',
    maximumHoldingsPerInvestor: '0',
    totalInvestorsLimit: 0,
    usInvestorsLimit: 0,
    euRetailInvestorsLimit: 0,
    jpInvestorsLimit: 0,
    usAccreditedInvestorsLimit: 0,
    nonAccreditedInvestorsLimit: 0,
    maxUSInvestorsPercentage: 0,
    minimumTotalInvestors: 0,
    nonUSLockPeriod: 0,
    usLockPeriod: 0,
    disallowBackDating: false,
    authorizedSecurities: '0',
}

export const countriesComplianceStatuses: CountryComplianceStatus[] = [
    {
        "countryName": "AT",
        "complianceStatus": "eu",
        "comment": ""
    },
    {
        "countryName": "BE",
        "complianceStatus": "eu",
        "comment": ""
    },
    {
        "countryName": "BG",
        "complianceStatus": "eu",
        "comment": ""
    },
    {
        "countryName": "HR",
        "complianceStatus": "eu",
        "comment": ""
    },
    {
        "countryName": "CY",
        "complianceStatus": "eu",
        "comment": ""
    },
    {
        "countryName": "CZ",
        "complianceStatus": "eu",
        "comment": ""
    },
    {
        "countryName": "DK",
        "complianceStatus": "eu",
        "comment": ""
    },
    {
        "countryName": "EE",
        "complianceStatus": "eu",
        "comment": ""
    },
    {
        "countryName": "FI",
        "complianceStatus": "eu",
        "comment": ""
    },
    {
        "countryName": "FR",
        "complianceStatus": "eu",
        "comment": ""
    },
    {
        "countryName": "DE",
        "complianceStatus": "eu",
        "comment": ""
    },
    {
        "countryName": "GR",
        "complianceStatus": "eu",
        "comment": ""
    },
    {
        "countryName": "HU",
        "complianceStatus": "eu",
        "comment": ""
    },
    {
        "countryName": "IE",
        "complianceStatus": "eu",
        "comment": ""
    },
    {
        "countryName": "IT",
        "complianceStatus": "eu",
        "comment": ""
    },
    {
        "countryName": "LV",
        "complianceStatus": "eu",
        "comment": ""
    },
    {
        "countryName": "LT",
        "complianceStatus": "eu",
        "comment": ""
    },
    {
        "countryName": "LU",
        "complianceStatus": "eu",
        "comment": ""
    },
    {
        "countryName": "MT",
        "complianceStatus": "eu",
        "comment": ""
    },
    {
        "countryName": "NL",
        "complianceStatus": "eu",
        "comment": ""
    },
    {
        "countryName": "PL",
        "complianceStatus": "eu",
        "comment": ""
    },
    {
        "countryName": "PT",
        "complianceStatus": "eu",
        "comment": ""
    },
    {
        "countryName": "RO",
        "complianceStatus": "eu",
        "comment": ""
    },
    {
        "countryName": "SK",
        "complianceStatus": "eu",
        "comment": ""
    },
    {
        "countryName": "SI",
        "complianceStatus": "eu",
        "comment": ""
    },
    {
        "countryName": "ES",
        "complianceStatus": "eu",
        "comment": ""
    },
    {
        "countryName": "SE",
        "complianceStatus": "eu",
        "comment": ""
    },
    {
        "countryName": "GB",
        "complianceStatus": "eu",
        "comment": ""
    },
    {
        "countryName": "IS",
        "complianceStatus": "eu",
        "comment": ""
    },
    {
        "countryName": "LI",
        "complianceStatus": "eu",
        "comment": ""
    },
    {
        "countryName": "NO",
        "complianceStatus": "eu",
        "comment": ""
    },
    {
        "countryName": "CH",
        "complianceStatus": "eu",
        "comment": ""
    },
    {
        "countryName": "US",
        "complianceStatus": "us",
        "comment": ""
    },
    {
        "countryName": "CN",
        "complianceStatus": "forbidden",
        "comment": ""
    },
    {
        "countryName": "IR",
        "complianceStatus": "forbidden",
        "comment": ""
    },
    {
        "countryName": "SY",
        "complianceStatus": "forbidden",
        "comment": ""
    },
    {
        "countryName": "KP",
        "complianceStatus": "forbidden",
        "comment": ""
    },
    {
        "countryName": "CU",
        "complianceStatus": "forbidden",
        "comment": ""
    },
    {
        "countryName": "UA",
        "complianceStatus": "forbidden",
        "comment": ""
    }
]

export async function createTestToken(
    complianceRules?: ComplianceRules,
    countriesComplianceStatuses?: CountryComplianceStatus[]
) {
    testTokenRequest.complianceRules = complianceRules
    testTokenRequest.countriesComplianceStatuses = countriesComplianceStatuses
    const res = await createDSToken(testTokenRequest)
    return res.id
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
