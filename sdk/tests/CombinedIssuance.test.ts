import { ADMIN_KEYPAIR, AttributeStatus, AttributeType, Country, createFundedWallet } from '../src'
import { deploy } from '../src/sdk/utils/deploy'
import { assertInvestorBalance, createTestToken, executeTxFunc } from './test_utils'
import { Investor, Investors, DSToken, CombinedIssuance } from '../src'
import { Keypair } from '@mysten/sui/cryptography'

const sender = ADMIN_KEYPAIR!.toSuiAddress()

describe('CombinedIssuance', () => {
    let tokenAddress: string
    let combinedIssuance: CombinedIssuance
    let investors: Investors
    let dsToken: DSToken
    let wallet1: Keypair
    let wallet2: Keypair
    let issuanceTime: number

    beforeAll(async () => {
        await deploy()
        tokenAddress = await createTestToken()
        combinedIssuance = new CombinedIssuance(tokenAddress)
        investors = new Investors(tokenAddress)
        dsToken = new DSToken(tokenAddress)
        wallet1 = await createFundedWallet()
        wallet2 = await createFundedWallet()
        issuanceTime = Date.now()
    })

    describe('Basic Registration and Issuance', () => {
        it('should register investor and issue tokens in one transaction', async () => {
            const investor: Investor = {
                id: 'investor1',
                country: Country.US,
                wallet: wallet1.toSuiAddress(),
                value: '1000',
                reasonString: 'Initial issuance',
                reasonCode: 0,
                issuanceTime,
                attributes: [
                    {
                        name: AttributeType.KYC_APPROVED,
                        status: AttributeStatus.APPROVED,
                        expiry: Date.now() + 365 * 24 * 60 * 60 * 1000,
                    },
                ],
            }

            await expect(investors.isInvestor(investor.id, sender)).resolves.toBe(false)
            await expect(dsToken.getTotalIssued()).resolves.toBe('0')

            await executeTxFunc(combinedIssuance.register(investor, sender))

            // Verify investor was registered
            await expect(investors.isInvestor(investor.id, sender)).resolves.toBe(true)
            const details = await investors.getInvestorDetails(investor.id)
            expect(details.id).toBe(investor.id)
            expect(details.country).toBe(Country.US)
            expect(details.wallets).toEqual([wallet1.toSuiAddress()])
            expect(details.attributes.length).toBe(1)
            expect(details.attributes[0].name).toBe(AttributeType.KYC_APPROVED)
            expect(details.attributes[0].status).toBe(AttributeStatus.APPROVED)

            // Verify tokens were issued
            await assertInvestorBalance(tokenAddress, investor.id, '1000')
            await expect(dsToken.getTotalIssued()).resolves.toBe('1000')
        })

        it('should register investor without attributes', async () => {
            const investor: Investor = {
                id: 'investor2',
                country: Country.JP,
                wallet: wallet2.toSuiAddress(),
                value: '500',
                reasonString: 'Simple issuance',
                reasonCode: 0,
                issuanceTime,
            }

            await executeTxFunc(combinedIssuance.register(investor, sender))

            // Verify investor
            await expect(investors.isInvestor(investor.id, sender)).resolves.toBe(true)
            const details = await investors.getInvestorDetails(investor.id)
            expect(details.id).toBe(investor.id)
            expect(details.country).toBe(Country.JP)
            expect(details.wallets).toEqual([wallet2.toSuiAddress()])
            expect(details.attributes.length).toBe(0)

            // Verify tokens
            await assertInvestorBalance(tokenAddress, investor.id, '500')
            await expect(dsToken.getTotalIssued()).resolves.toBe('1500')
        })
    })

    describe('Issuance with Locks', () => {
        it('should register investor and issue tokens with a lock', async () => {
            const wallet3 = await createFundedWallet()
            const releaseTime = Date.now() + 30 * 24 * 60 * 60 * 1000 // 30 days from now

            const investor: Investor = {
                id: 'investor3',
                country: Country.EU,
                wallet: wallet3.toSuiAddress(),
                value: '2000',
                reasonString: 'Locked issuance',
                reasonCode: 0,
                issuanceTime,
                lock: {
                    value: '1500',
                    releaseTime,
                    reason: 'Vesting period',
                    reasonCode: 1,
                },
                attributes: [
                    {
                        name: AttributeType.ACCREDITED,
                        status: AttributeStatus.APPROVED,
                        expiry: Date.now() + 365 * 24 * 60 * 60 * 1000,
                    },
                ],
            }

            await executeTxFunc(combinedIssuance.register(investor, sender))

            // Verify investor
            await expect(investors.isInvestor(investor.id, sender)).resolves.toBe(true)
            const details = await investors.getInvestorDetails(investor.id)
            expect(details.id).toBe(investor.id)
            expect(details.country).toBe(Country.EU)

            // Verify tokens were issued
            await assertInvestorBalance(tokenAddress, investor.id, '2000')
            await expect(dsToken.getTotalIssued()).resolves.toBe('3500')
        })
    })

    describe('Multiple Attributes', () => {
        it('should register investor with multiple attributes', async () => {
            const wallet5 = await createFundedWallet()
            const futureExpiry = Date.now() + 365 * 24 * 60 * 60 * 1000

            const investor: Investor = {
                id: 'investor5',
                country: Country.US,
                wallet: wallet5.toSuiAddress(),
                value: '3000',
                reasonString: 'Multiple attributes',
                reasonCode: 0,
                issuanceTime,
                attributes: [
                    {
                        name: AttributeType.KYC_APPROVED,
                        status: AttributeStatus.APPROVED,
                        expiry: futureExpiry,
                    },
                    {
                        name: AttributeType.ACCREDITED,
                        status: AttributeStatus.APPROVED,
                        expiry: futureExpiry,
                    },
                    {
                        name: AttributeType.PROFESSIONAL,
                        status: AttributeStatus.PENDING,
                        expiry: futureExpiry,
                    },
                ],
            }

            await executeTxFunc(combinedIssuance.register(investor, sender))

            const details = await investors.getInvestorDetails(investor.id)
            expect(details.id).toBe(investor.id)
            expect(details.attributes.length).toBe(3)
            expect(details.attributes).toContainEqual({
                name: AttributeType.KYC_APPROVED,
                status: AttributeStatus.APPROVED,
                expiry: futureExpiry,
            })
            expect(details.attributes).toContainEqual({
                name: AttributeType.ACCREDITED,
                status: AttributeStatus.APPROVED,
                expiry: futureExpiry,
            })
            expect(details.attributes).toContainEqual({
                name: AttributeType.PROFESSIONAL,
                status: AttributeStatus.PENDING,
                expiry: futureExpiry,
            })

            await assertInvestorBalance(tokenAddress, investor.id, '3000')
            await expect(dsToken.getTotalIssued()).resolves.toBe('6500')
        })
    })

    describe('PTB (Programmable Transaction Block) Methods', () => {
        it('should create PTB for registration', () => {
            const investor: Investor = {
                id: 'investor_ptb',
                country: Country.EU,
                wallet: '0x0000000000000000000000000000000000000000000000000000000000000123',
                value: '100',
                reasonString: 'PTB test',
                reasonCode: 0,
                issuanceTime,
            }

            const ptb = combinedIssuance.registerPTB(investor)
            expect(ptb).toBeDefined()
            expect(ptb.blockData).toBeDefined()
        })

        it('should create PTB with lock', () => {
            const investor: Investor = {
                id: 'investor_ptb_lock',
                country: Country.JP,
                wallet: '0x0000000000000000000000000000000000000000000000000000000000000456',
                value: '200',
                reasonString: 'PTB lock test',
                reasonCode: 0,
                issuanceTime,
                lock: {
                    value: '150',
                    releaseTime: Date.now() + 90 * 24 * 60 * 60 * 1000,
                    reason: 'Vesting',
                    reasonCode: 1,
                },
            }

            const ptb = combinedIssuance.registerPTB(investor)
            expect(ptb).toBeDefined()
            expect(ptb.blockData).toBeDefined()
        })
    })

    describe('Edge Cases', () => {
        it('should handle minimum token issuance', async () => {
            const wallet6 = await createFundedWallet()

            const investor: Investor = {
                id: 'investor6',
                country: Country.EU,
                wallet: wallet6.toSuiAddress(),
                value: '1',
                reasonString: 'Minimum issuance',
                reasonCode: 0,
                issuanceTime,
            }

            await executeTxFunc(combinedIssuance.register(investor, sender))

            await expect(investors.isInvestor(investor.id, sender)).resolves.toBe(true)
            await assertInvestorBalance(tokenAddress, investor.id, '1')
        })

        it('should handle large token issuance', async () => {
            const wallet7 = await createFundedWallet()

            const investor: Investor = {
                id: 'investor7',
                country: Country.JP,
                wallet: wallet7.toSuiAddress(),
                value: '1000000000',
                reasonString: 'Large issuance',
                reasonCode: 0,
                issuanceTime,
            }

            await executeTxFunc(combinedIssuance.register(investor, sender))

            await expect(investors.isInvestor(investor.id, sender)).resolves.toBe(true)
            await assertInvestorBalance(tokenAddress, investor.id, '1000000000')
        })

        it('should handle investor with empty attributes array', async () => {
            const wallet8 = await createFundedWallet()

            const investor: Investor = {
                id: 'investor8',
                country: Country.US,
                wallet: wallet8.toSuiAddress(),
                value: '500',
                reasonString: 'Empty attributes',
                reasonCode: 0,
                issuanceTime,
                attributes: [],
            }

            await executeTxFunc(combinedIssuance.register(investor, sender))

            const details = await investors.getInvestorDetails(investor.id)
            expect(details.attributes.length).toBe(0)
            await assertInvestorBalance(tokenAddress, investor.id, '500')
        })
    })
})
