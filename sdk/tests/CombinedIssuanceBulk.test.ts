import {
    ADMIN_KEYPAIR,
    AttributeStatus,
    AttributeType,
    Country,
    createFundedWallet,
    createWallet,
    Investor,
    Investors,
    DSToken,
    CombinedIssuanceBulk,
} from '../src'
import { deploy } from '../src/sdk/utils/deploy'
import { assertInvestorBalance, createTestToken, executeTxFunc } from './test_utils'

const sender = ADMIN_KEYPAIR!.toSuiAddress()

describe('CombinedIssuanceBulk', () => {
    let tokenAddress: string
    let combinedIssuanceBulk: CombinedIssuanceBulk
    let investors: Investors
    let dsToken: DSToken
    let issuanceTime: number

    beforeAll(async () => {
        await deploy()
        tokenAddress = await createTestToken()
        combinedIssuanceBulk = new CombinedIssuanceBulk(tokenAddress)
        investors = new Investors(tokenAddress)
        dsToken = new DSToken(tokenAddress)
        issuanceTime = Date.now()
    })

    describe('Bulk Registration with register()', () => {
        it('should register multiple investors and issue tokens in a single transaction', async () => {
            const wallet1 = await createFundedWallet()
            const wallet2 = await createFundedWallet()
            const wallet3 = await createFundedWallet()
            const releaseTime = new Date().getTime()

            const investorsList: Investor[] = [
                {
                    id: 'bulk_investor_1',
                    country: Country.US,
                    wallet: wallet1.toSuiAddress(),
                    value: '500',
                    reasonCode: 0,
                    reasonString: 'Bulk issuance 1',
                    issuanceTime,
                    attributes: [
                        {
                            name: AttributeType.KYC_APPROVED,
                            status: AttributeStatus.APPROVED,
                            expiry: new Date().getTime(),
                        },
                    ],
                },
                {
                    id: 'bulk_investor_1',
                    country: Country.US,
                    wallet: wallet1.toSuiAddress(),
                    value: '500',
                    reasonCode: 0,
                    reasonString: 'Bulk issuance 1',
                    issuanceTime,
                    attributes: [
                        {
                            name: AttributeType.KYC_APPROVED,
                            status: AttributeStatus.APPROVED,
                            expiry: new Date().getTime(),
                        },
                    ],
                },
                {
                    id: 'bulk_investor_2',
                    country: Country.EU,
                    wallet: wallet2.toSuiAddress(),
                    value: '2000',
                    reasonCode: 0,
                    reasonString: 'Bulk issuance 2',
                    issuanceTime,
                    attributes: [
                        {
                            name: AttributeType.ACCREDITED,
                            status: AttributeStatus.APPROVED,
                            expiry: new Date().getTime(),
                        },
                    ],
                    lock: {
                        value: '2000',
                        releaseTime,
                        reason: 'Vesting period',
                        reasonCode: 1,
                    },
                },
                {
                    id: 'bulk_investor_3',
                    country: Country.JP,
                    wallet: wallet3.toSuiAddress(),
                    value: '500',
                    reasonCode: 0,
                    reasonString: 'Bulk issuance 3',
                    issuanceTime,
                },
            ]

            const totalIssuedBefore = await dsToken.getTotalIssued()

            await executeTxFunc(combinedIssuanceBulk.register(investorsList, sender))

            // Verify all investors were registered
            await expect(investors.isInvestor('bulk_investor_1', sender)).resolves.toBe(true)
            await expect(investors.isInvestor('bulk_investor_2', sender)).resolves.toBe(true)
            await expect(investors.isInvestor('bulk_investor_3', sender)).resolves.toBe(true)

            // Verify tokens were issued
            await assertInvestorBalance(tokenAddress, 'bulk_investor_1', '1000')
            await assertInvestorBalance(tokenAddress, 'bulk_investor_2', '2000')
            await assertInvestorBalance(tokenAddress, 'bulk_investor_3', '500')

            const totalIssuedAfter = await dsToken.getTotalIssued()
            expect(totalIssuedAfter).toBe((parseInt(totalIssuedBefore) + 3500).toString())
        })
    })

    describe('Bulk Registration with registerExecution()', () => {
        it('should register 1000 investors using execution method', async () => {
            const investorList: Investor[] = []
            const numberOfInvestors = 1000
            const tokenPerInvestor = 1000

            for (let i = 0; i < numberOfInvestors; i++) {
                investorList.push({
                    id: `b_investor_${i}`,
                    country: i % 3 === 0 ? Country.US : i % 3 === 1 ? Country.EU : Country.JP,
                    wallet: createWallet().toSuiAddress(),
                    value: tokenPerInvestor.toString(),
                    reasonCode: 0,
                    reasonString: `Larger bulk issuance ${i}`,
                    issuanceTime,
                })
            }

            const totalIssuedBefore = await dsToken.getTotalIssued()
            await combinedIssuanceBulk.registerExecution(investorList, ADMIN_KEYPAIR!)

            for (let i = 0; i < numberOfInvestors; i++) {
                await expect(
                    investors.isInvestor(`b_investor_${i}`, sender)
                ).resolves.toBe(true)
                await assertInvestorBalance(tokenAddress, `b_investor_${i}`, tokenPerInvestor.toString())
            }

            const totalIssuedAfter = await dsToken.getTotalIssued()
            expect(totalIssuedAfter).toBe((parseInt(totalIssuedBefore) + numberOfInvestors * tokenPerInvestor).toString())
        }, 300000)
    })
})
