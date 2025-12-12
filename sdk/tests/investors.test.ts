import {
    ADMIN_KEYPAIR,
    Investors
} from '../src'
import {deploy} from "../src/sdk/utils/deploy";
import {createTestToken, executeTxFunc} from "./test_utils";

const testInvestor1 = "InvestorId1"
const testWallet1 = "0xABC"
const sender = ADMIN_KEYPAIR!.toSuiAddress();

describe('Investors', () => {
    let tokenAddress: string
    let investors: Investors

    beforeAll(async () => {
        await deploy()
        tokenAddress = await createTestToken()
        investors = new Investors(tokenAddress)
    })

    it('registerInvestor', async () => {
        await expect(investors.isInvestor(testInvestor1, sender)).resolves.toBe(false)
        await expect(investors.getTotalInvestorsCount(sender)).resolves.toBe(0n)

        await executeTxFunc(investors.registerInvestor(testInvestor1, sender));

        await expect(investors.isInvestor(testInvestor1, sender)).resolves.toBe(true)
        await expect(investors.getUsInvestorCount(sender)).resolves.toBe(0n)
        // await expect(investors.getTotalInvestorsCount(sender)).resolves.toBe(1n)
    })

    it('updateInvestor', async () => {
        await expect(investors.isInvestor(testInvestor1, sender)).resolves.toBe(true)

        await executeTxFunc(investors.updateInvestor(
            testInvestor1,
            "US",
            [testWallet1],
            [0],
            [1],
            [123],
            sender
        ))

        await expect(investors.isInvestor(testInvestor1, sender)).resolves.toBe(true)
        await expect(investors.getInvestorIdByWallet(testWallet1, sender)).resolves.toBe(testInvestor1)
        await expect(investors.getCountry(testInvestor1, sender)).resolves.toBe("US")
        await expect(investors.getAttributeValue(testInvestor1, 0, sender)).resolves.toBe(1n)
        await expect(investors.getAttributeExpiration(testInvestor1, 0, sender)).resolves.toBe(123n)

        // await expect(investors.getUsInvestorCount(sender)).resolves.toBe(1n)
    })

    it('removeInvestor', async () => {
        await expect(investors.isInvestor(testInvestor1, sender)).resolves.toBe(true)
        // await expect(investors.getTotalInvestorsCount(sender)).resolves.toBe(1n)

        // await executeTxFunc(investors.removeWallet(testInvestor1, testWallet1, sender));
        // await executeTxFunc(investors.removeInvestor(testInvestor1, sender));

        // await expect(investors.isInvestor(testInvestor1, sender)).resolves.toBe(false)
        // await expect(investors.getTotalInvestorsCount(sender)).resolves.toBe(0n)
    })
})
