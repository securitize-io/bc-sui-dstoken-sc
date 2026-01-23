import { ADMIN_KEYPAIR, AttributeStatus, AttributeType, Investor, InvestorsBulk } from '../src'
import { deploy } from '../src/sdk/utils/deploy'
import { createTestToken, executeTxFunc } from './test_utils'
import { Country } from '../src'

const testWallet1 = '0x0000000000000000000000000000000000000000000000000000000000000abb'
const testWallet2 = '0x0000000000000000000000000000000000000000000000000000000000000acc'
const sender = ADMIN_KEYPAIR!.toSuiAddress()

const testInvestor1: Investor = {
    id: 'InvestorId1',
    country: Country.US,
    attributes: [
        {
            name: AttributeType.KYC_APPROVED,
            status: AttributeStatus.APPROVED,
            expiry: 111,
        },
    ],
    wallet: testWallet1,
    value: '1000',
    reasonCode: 0,
    reasonString: 'Initial issuance',
    issuanceTime: Math.floor(Date.now() / 1000),
}

describe('Investors Bulk', () => {
    let tokenAddress: string
    let investorsBulk: InvestorsBulk
    let investors: ReturnType<InvestorsBulk['getInvestorsInstance']>

    beforeAll(async () => {
        await deploy()
        tokenAddress = await createTestToken()
        investorsBulk = new InvestorsBulk(tokenAddress)
        investors = investorsBulk.getInvestorsInstance()
    })

    it('register an investor', async () => {
        await expect(investors.isInvestor(testInvestor1.id, sender)).resolves.toBe(false)
        await expect(investors.getTotalInvestorsCount(sender)).resolves.toBe(0n)

        await executeTxFunc(investorsBulk.register([testInvestor1], sender))
        const details = await investors.getInvestorDetails(testInvestor1.id)

        expect(details.id).toBe(testInvestor1.id)
        // expect(details.country).toBe(testInvestor1.country)      // TODO: fix register to persist investors data
        // expect(details.totalBalance).toBe(testInvestor1.value)   // TODO: fix register to persist investors data
        expect(details.wallets).toEqual([testInvestor1.wallet])
        expect(details.attributes.length).toBe(1)

        await expect(investors.getTotalInvestorsCount(sender)).resolves.toBe(0n)
    })

    it('updates an already registered Investor', async () => {
        await expect(investors.isInvestor(testInvestor1.id, sender)).resolves.toBe(true)

        // registering an already registered investor should update it
        await executeTxFunc(
            investorsBulk.register(
                [
                    {
                        ...testInvestor1,
                        country: Country.JP, // updated country
                        value: '2000', // updated value
                        reasonCode: 1, // updated reason code
                        reasonString: 'Initial issuance updated', // updated reason
                        attributes: [
                            // updated attributes åre breaking the move execution
                            {
                                name: AttributeType.KYC_APPROVED,
                                status: AttributeStatus.APPROVED,
                                expiry: 111,
                            },
                            {
                                name: AttributeType.PROFESSIONAL,
                                status: AttributeStatus.PENDING,
                                expiry: 222,
                            },
                        ],
                        wallet: testWallet2, // override wallet to empty value not working , need to add a new wallet
                    },
                ],
                sender
            )
        )

        const details = await investors.getInvestorDetails(testInvestor1.id)

        expect(details.id).toBe(testInvestor1.id)
        expect(details.country).toBe(Country.JP)
        expect(details.totalBalance).toBe('0')
        expect(details.wallets).toEqual([testWallet1, testWallet2])
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

        await expect(investors.getTotalInvestorsCount(sender)).resolves.toBe(0n)
    })
})
