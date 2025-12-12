import {
    ADMIN_KEYPAIR,
    isInvestor,
    registerInvestor, removeInvestor
} from '../src'
import {deploy} from "../src/sdk/utils/deploy";
import {createTestToken, executeTxFunc} from "./test_utils";

const testInvestor1 = "InvestorId1"

describe('Investors', () => {
    let tokenAddress: string

    beforeAll(async () => {
        await deploy()
        tokenAddress = await createTestToken()
    })

    it('registerInvestor', async () => {
        await expect(isInvestor(ADMIN_KEYPAIR!.toSuiAddress(), tokenAddress, testInvestor1)).resolves.toBe(false)

        await executeTxFunc(registerInvestor(ADMIN_KEYPAIR!.toSuiAddress(), tokenAddress, testInvestor1));

        await expect(isInvestor(ADMIN_KEYPAIR!.toSuiAddress(), tokenAddress, testInvestor1)).resolves.toBe(true)
    })

    it('removeInvestor', async () => {
        await expect(isInvestor(ADMIN_KEYPAIR!.toSuiAddress(), tokenAddress, testInvestor1)).resolves.toBe(true)

        await executeTxFunc(removeInvestor(ADMIN_KEYPAIR!.toSuiAddress(), tokenAddress, testInvestor1));

        await expect(isInvestor(ADMIN_KEYPAIR!.toSuiAddress(), tokenAddress, testInvestor1)).resolves.toBe(false)
    })
})
