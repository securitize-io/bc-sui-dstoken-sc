import {ADMIN_KEYPAIR, AttributeStatus, AttributeType, Investors} from '../src'
import {deploy} from "../src/sdk/utils/deploy";
import {createTestToken, executeTxFunc} from "./test_utils";
import {Country} from "../src";

const testInvestor1 = "InvestorId1"
const testWallet1 = "0x0000000000000000000000000000000000000000000000000000000000000abb"
const testWallet2 = "0x0000000000000000000000000000000000000000000000000000000000000acc"
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
        const details = await investors.getInvestorDetails(testInvestor1)

        expect(details.id).toBe(testInvestor1)
        expect(details.country).toBe("")
        expect(details.totalBalance).toBe("0")
        expect(details.wallets).toEqual([])
        expect(details.attributes.length).toBe(0)

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

        const details = await investors.getInvestorDetails(testInvestor1)

        expect(details.id).toBe(testInvestor1)
        expect(details.country).toBe(Country.US)
        expect(details.totalBalance).toBe("0")
        expect(details.wallets).toEqual([testWallet1])
        expect(details.attributes.length).toBe(2)
        expect(details.attributes).toContainEqual({
            name: AttributeType.KYC_APPROVED,
            status: AttributeStatus.APPROVED,
            expiry: 111,
        })
        expect(details.attributes).toContainEqual({
            name: AttributeType.PROFESSIONAL,
            status: AttributeStatus.PENDING,
            expiry: 222,
        })

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

        const details = await investors.getInvestorDetails(testInvestor1)

        expect(details.id).toBe(testInvestor1)
        expect(details.country).toBe(Country.JP)
        expect(details.totalBalance).toBe("0")
        expect(details.wallets).toEqual([testWallet1])
        expect(details.attributes.length).toBe(2)
        expect(details.attributes).toContainEqual({
            name: AttributeType.KYC_APPROVED,
            status: AttributeStatus.APPROVED,
            expiry: 111,
        })
        expect(details.attributes).toContainEqual({
            name: AttributeType.PROFESSIONAL,
            status: AttributeStatus.PENDING,
            expiry: 222,
        })
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

        const details = await investors.getInvestorDetails(testInvestor1)

        expect(details.id).toBe(testInvestor1)
        expect(details.country).toBe(Country.JP)
        expect(details.totalBalance).toBe("0")
        expect(details.wallets).toEqual([testWallet1])
        expect(details.attributes.length).toBe(3)
        expect(details.attributes).toContainEqual({
            name: AttributeType.KYC_APPROVED,
            status: AttributeStatus.APPROVED,
            expiry: 111,
        })
        expect(details.attributes).toContainEqual({
            name: AttributeType.PROFESSIONAL,
            status: AttributeStatus.PENDING,
            expiry: 222,
        })
        expect(details.attributes).not.toContainEqual({
            name: AttributeType.ACCREDITED,
            status: AttributeStatus.REJECTED,
            expiry: 333,
        })
        expect(details.attributes).toContainEqual({
            name: AttributeType.ACCREDITED,
            status: AttributeStatus.APPROVED,
            expiry: 444,
        })
    })

    it('update wallets', async () => {
        await executeTxFunc(investors.addWallet(testInvestor1, testWallet2, sender))
        await expect(investors.isWallet(testWallet1, sender)).resolves.toBeTruthy()
        await expect(investors.getInvestorIdByWallet(testWallet1, sender)).resolves.toBe(testInvestor1)
        await expect(investors.isWallet(testWallet2, sender)).resolves.toBeTruthy()
        await expect(investors.getInvestorIdByWallet(testWallet2, sender)).resolves.toBe(testInvestor1)

        const details1 = await investors.getInvestorDetails(testInvestor1)
        expect(details1.wallets).toEqual([testWallet1, testWallet2])

        await executeTxFunc(investors.removeWallet(testInvestor1, testWallet2, sender))
        await expect(investors.isWallet(testWallet2, sender)).resolves.toBeFalsy()
        await expect(investors.getInvestorIdByWallet(testWallet2, sender)).resolves.toBe("")

        const details2 = await investors.getInvestorDetails(testInvestor1)
        expect(details2.wallets).toEqual([testWallet1])
    })

    it('removeInvestor', async () => {
        await expect(investors.isInvestor(testInvestor1, sender)).resolves.toBe(true)
        await expect(investors.getTotalInvestorsCount(sender)).resolves.toBe(0n)

        await executeTxFunc(investors.removeWallet(testInvestor1, testWallet1, sender));
        await expect(investors.isWallet(testWallet1, sender)).resolves.toBeFalsy()
        await expect(investors.isWallet(testWallet2, sender)).resolves.toBeFalsy()
        await executeTxFunc(investors.removeInvestor(testInvestor1, sender));

        await expect(investors.isInvestor(testInvestor1, sender)).resolves.toBe(false)
        await expect(investors.getTotalInvestorsCount(sender)).resolves.toBe(0n)

        await expect(investors.getInvestorDetails(testInvestor1)).rejects.toBe(`Investor ${testInvestor1} does not exist.`)
    })
})
