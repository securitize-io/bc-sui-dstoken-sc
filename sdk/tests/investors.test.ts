import {ADMIN_KEYPAIR, AttributeStatus, AttributeType, Investors} from '../src'
import {deploy} from "../src/sdk/utils/deploy";
import {createTestToken, executeTxFunc} from "./test_utils";
import {Country} from "../src/sdk/domains/Country";

const testInvestor1 = "InvestorId1"
const testWallet1 = "0xABB"
const testWallet2 = "0xACC"
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
        await expect(investors.getTotalInvestorsCount(sender)).resolves.toBe(0n)
    })

    it('updateInvestor', async () => {
        await expect(investors.isInvestor(testInvestor1, sender)).resolves.toBe(true)

        await executeTxFunc(investors.updateInvestor(
            testInvestor1,
            Country.US,
            [testWallet1],
            [AttributeType.KYC_APPROVED, AttributeType.PROFESSIONAL],
            [AttributeStatus.APPROVED, AttributeStatus.PENDING],
            [111, 222],
            sender
        ))

        await expect(investors.isWallet(testWallet1, sender)).resolves.toBeTruthy()
        await expect(investors.getInvestorIdByWallet(testWallet1, sender)).resolves.toBe(testInvestor1)
        await expect(investors.getCountry(testInvestor1, sender)).resolves.toBe(Country.US)
        await expect(investors.getAttributeValue(testInvestor1, AttributeType.KYC_APPROVED, sender)).resolves.toBe(AttributeStatus.APPROVED)
        await expect(investors.getAttributeExpiration(testInvestor1, AttributeType.KYC_APPROVED, sender)).resolves.toBe(111n)
        await expect(investors.getAttributeValue(testInvestor1, AttributeType.PROFESSIONAL, sender)).resolves.toBe(AttributeStatus.PENDING)
        await expect(investors.getAttributeExpiration(testInvestor1, AttributeType.PROFESSIONAL, sender)).resolves.toBe(222n)

        await expect(investors.getUsInvestorCount(sender)).resolves.toBe(0n)
    })

    it('update country', async () => {
        await executeTxFunc(investors.setCountry(testInvestor1, Country.JP, sender))
        await expect(investors.getCountry(testInvestor1, sender)).resolves.toBe(Country.JP)
        await expect(investors.getUsInvestorCount(sender)).resolves.toBe(0n)
        await expect(investors.getJpInvestorCount(sender)).resolves.toBe(0n)
    })

    it('update attributes', async () => {
        await executeTxFunc(investors.setAttribute(
            testInvestor1,
            AttributeType.ACCREDITED,
            AttributeStatus.REJECTED,
            333,
            sender
        ))
        await expect(investors.getAttributeValue(testInvestor1, AttributeType.ACCREDITED, sender)).resolves.toBe(AttributeStatus.REJECTED)
        await expect(investors.getAttributeExpiration(testInvestor1, AttributeType.ACCREDITED, sender)).resolves.toBe(333n)

        await executeTxFunc(investors.setAttribute(
            testInvestor1,
            AttributeType.ACCREDITED,
            AttributeStatus.APPROVED,
            444,
            sender
        ))
        await expect(investors.getAttributeValue(testInvestor1, AttributeType.ACCREDITED, sender)).resolves.toBe(AttributeStatus.APPROVED)
        await expect(investors.getAttributeExpiration(testInvestor1, AttributeType.ACCREDITED, sender)).resolves.toBe(444n)
    })

    it('update wallets', async () => {
        await executeTxFunc(investors.addWallet(testInvestor1, testWallet2, sender))
        await expect(investors.isWallet(testWallet1, sender)).resolves.toBeTruthy()
        await expect(investors.getInvestorIdByWallet(testWallet1, sender)).resolves.toBe(testInvestor1)
        await expect(investors.isWallet(testWallet2, sender)).resolves.toBeTruthy()
        await expect(investors.getInvestorIdByWallet(testWallet2, sender)).resolves.toBe(testInvestor1)

        await executeTxFunc(investors.removeWallet(testInvestor1, testWallet2, sender))
        await expect(investors.isWallet(testWallet2, sender)).resolves.toBeFalsy()
        await expect(investors.getInvestorIdByWallet(testWallet2, sender)).resolves.toBe("")
    })

    it('removeInvestor', async () => {
        await expect(investors.isInvestor(testInvestor1, sender)).resolves.toBe(true)
        await expect(investors.getTotalInvestorsCount(sender)).resolves.toBe(0n)

        await executeTxFunc(investors.removeWallet(testInvestor1, testWallet1, sender));
        await executeTxFunc(investors.removeInvestor(testInvestor1, sender));

        await expect(investors.isInvestor(testInvestor1, sender)).resolves.toBe(false)
        await expect(investors.getTotalInvestorsCount(sender)).resolves.toBe(0n)
    })
})
