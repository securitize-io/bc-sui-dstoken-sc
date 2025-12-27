import {
    ADMIN_KEYPAIR,
    createFundedWallet,
    createWallet,
    DSToken,
    DSTokenBulk,
    InvestorsBulk,
    TokenIssue,
    Investor,
} from '../src'
import { deploy } from '../src/sdk/utils/deploy'
import {
    assertInvestorBalance,
    createTestToken,
    executeTxFunc,
    registerInvestor,
} from './test_utils'
import { Keypair } from '@mysten/sui/cryptography'

const sender = ADMIN_KEYPAIR!.toSuiAddress()

describe('DSTokenBulk', () => {
    let tokenAddress: string
    let dsTokenBulk: DSTokenBulk
    let dsToken: DSToken
    let investor1: Keypair
    let investor2: Keypair
    let investor3: Keypair
    let investors: Investor[]
    const numberOfInvestors = 1000
    const tokensPerInvestor = 1000

    beforeAll(async () => {
        await deploy()
        tokenAddress = await createTestToken()
        dsTokenBulk = new DSTokenBulk(tokenAddress)
        dsToken = new DSToken(tokenAddress)

        investor1 = ADMIN_KEYPAIR!
        investor2 = await createFundedWallet()
        investor3 = await createFundedWallet()

        await registerInvestor(tokenAddress, 'investor1', [investor1.toSuiAddress()])
        await registerInvestor(tokenAddress, 'investor2', [investor2.toSuiAddress()])
        await registerInvestor(tokenAddress, 'investor3', [investor3.toSuiAddress()])

        investors = Array.from({ length: numberOfInvestors }).map(
            (_, i) =>
                ({
                    id: `bulk_investor_${i}`,
                    country: 'US',
                    wallet: createWallet().toSuiAddress(),
                }) as Investor
        )
    })

    describe('issue / burn Bulk', () => {
        it('should issue tokens to multiple investors in a single transaction', async () => {
            const totalIssuedBefore = await dsToken.getTotalIssued()
            expect(totalIssuedBefore).toBe('0')

            const tokenIssues: TokenIssue[] = [
                { to: investor1.toSuiAddress(), value: 1_000_000 },
                { to: investor2.toSuiAddress(), value: 500_000 },
                { to: investor3.toSuiAddress(), value: 250_000 },
            ]
            await executeTxFunc(dsTokenBulk.issueBulk(tokenIssues, sender))

            const totalIssuedAfter = await dsToken.getTotalIssued()
            expect(totalIssuedAfter).toBe('1750000')

            await assertInvestorBalance(tokenAddress, 'investor1', '1000000')
            await assertInvestorBalance(tokenAddress, 'investor2', '500000')
            await assertInvestorBalance(tokenAddress, 'investor3', '250000')
        })

        // it('should burn tokens from multiple investors in a single transaction', async () => {
        //     const tokenBurns: TokenIssue[] = [
        //         {to: investor1.toSuiAddress(), value: 500_000},
        //         {to: investor2.toSuiAddress(), value: 500_000},
        //         {to: investor3.toSuiAddress(), value: 200_000}
        //     ]
        //     await executeTxFunc(dsTokenBulk.burnBulk(tokenBurns, sender))
        //
        //     const totalIssuedAfter = await dsToken.getTotalIssued()
        //     expect(totalIssuedAfter).toBe('1200000')
        //
        //     await assertInvestorBalance(tokenAddress, 'investor1', '500000')
        //     await assertInvestorBalance(tokenAddress, 'investor2', '0')
        //     await assertInvestorBalance(tokenAddress, 'investor3', '50000')
        //
        //     const tokenIssues: TokenIssue[] = [
        //         {to: investor1.toSuiAddress(), value: 500_000},
        //         {to: investor2.toSuiAddress(), value: 500_000},
        //         {to: investor3.toSuiAddress(), value: 200_000}
        //     ]
        //     await executeTxFunc(dsTokenBulk.issueBulk(tokenIssues, sender))
        // })

        it('should issue tokens to a single investor', async () => {
            const totalIssuedBefore = await dsToken.getTotalIssued()

            const tokenIssues: TokenIssue[] = [{ to: investor1.toSuiAddress(), value: 300_000 }]

            await executeTxFunc(dsTokenBulk.issueBulk(tokenIssues, sender))

            const totalIssuedAfter = await dsToken.getTotalIssued()
            expect(totalIssuedAfter).toBe((parseInt(totalIssuedBefore) + 300_000).toString())

            await assertInvestorBalance(tokenAddress, 'investor1', '1300000')
        })

        it('should issue tokens to the same investor multiple times in one transaction', async () => {
            const totalIssuedBefore = await dsToken.getTotalIssued()

            const tokenIssues: TokenIssue[] = [
                { to: investor2.toSuiAddress(), value: 100_000 },
                { to: investor2.toSuiAddress(), value: 200_000 },
                { to: investor2.toSuiAddress(), value: 150_000 },
            ]

            await executeTxFunc(dsTokenBulk.issueBulk(tokenIssues, sender))

            const totalIssuedAfter = await dsToken.getTotalIssued()
            expect(totalIssuedAfter).toBe((parseInt(totalIssuedBefore) + 450_000).toString())

            await assertInvestorBalance(tokenAddress, 'investor2', '950000')
        })

        it('should handle empty token issues array', async () => {
            const totalIssuedBefore = await dsToken.getTotalIssued()

            const tokenIssues: TokenIssue[] = []

            await executeTxFunc(dsTokenBulk.issueBulk(tokenIssues, sender))

            const totalIssuedAfter = await dsToken.getTotalIssued()
            expect(totalIssuedAfter).toBe(totalIssuedBefore)
        })

        it('should issue large amounts to multiple investors', async () => {
            const totalIssuedBefore = await dsToken.getTotalIssued()

            const tokenIssues: TokenIssue[] = [
                { to: investor1.toSuiAddress(), value: 10_000_000 },
                { to: investor2.toSuiAddress(), value: 20_000_000 },
                { to: investor3.toSuiAddress(), value: 30_000_000 },
            ]

            await executeTxFunc(dsTokenBulk.issueBulk(tokenIssues, sender))

            const totalIssuedAfter = await dsToken.getTotalIssued()
            expect(totalIssuedAfter).toBe((parseInt(totalIssuedBefore) + 60_000_000).toString())

            await assertInvestorBalance(tokenAddress, 'investor1', '11300000')
            await assertInvestorBalance(tokenAddress, 'investor2', '20950000')
            await assertInvestorBalance(tokenAddress, 'investor3', '30250000')
        })

        it('should issue tokens to 1000 wallets in bulk transactions', async () => {
            const totalIssuedBefore = await dsToken.getTotalIssued()
            const investorsBulk = new InvestorsBulk(tokenAddress)

            await investorsBulk.registerExecution(investors, ADMIN_KEYPAIR!)

            const tokenIssues = investors.map(
                (i) =>
                    ({
                        to: i.wallet,
                        value: tokensPerInvestor,
                    }) as TokenIssue
            )
            await dsTokenBulk.issueExecution(tokenIssues, ADMIN_KEYPAIR!)

            const totalIssuedAfter = await dsToken.getTotalIssued()
            expect(totalIssuedAfter).toBe(
                (parseInt(totalIssuedBefore) + tokensPerInvestor * numberOfInvestors).toString()
            )

            // Verify a few random wallets received their tokens
            await assertInvestorBalance(tokenAddress, 'bulk_investor_0', '1000')
            await assertInvestorBalance(tokenAddress, 'bulk_investor_511', '1000')
            await assertInvestorBalance(tokenAddress, 'bulk_investor_999', '1000')
        }, 300000)

        // it('should burn tokens from 1000 wallets in bulk transactions', async () => {
        //     const totalIssuedBefore = await dsToken.getTotalIssued()
        //
        //     const tokenBurns = investors.slice(0, 500).map((i) => ({
        //         to: i.wallet,
        //         value: tokensPerInvestor - 500
        //     } as TokenIssue))
        //     await dsTokenBulk.burnExecution(tokenBurns, ADMIN_KEYPAIR!)
        //
        //     const totalIssuedAfter = await dsToken.getTotalIssued()
        //     expect(totalIssuedAfter).toBe((parseInt(totalIssuedBefore) - tokensPerInvestor * numberOfInvestors).toString())
        //
        //     // Verify a few random wallets got their tokens burns
        //     await assertInvestorBalance(tokenAddress, 'bulk_investor_0', '500')
        //     await assertInvestorBalance(tokenAddress, 'bulk_investor_499', '500')
        //     await assertInvestorBalance(tokenAddress, 'bulk_investor_500', '500')
        //     await assertInvestorBalance(tokenAddress, 'bulk_investor_511', '1000')
        //     await assertInvestorBalance(tokenAddress, 'bulk_investor_999', '1000')
        // }, 300000) // Increase timeout to 5 minutes for this test
    })
})
