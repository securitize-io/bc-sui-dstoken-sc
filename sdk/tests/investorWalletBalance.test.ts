import { ADMIN_KEYPAIR, createFundedWallet, DSToken, Investors } from '../src'
import { deploy } from '../src/sdk/utils/deploy'
import { createTestToken, executeTxFunc, registerInvestor } from './test_utils'
import { Keypair } from '@mysten/sui/cryptography'

const sender = ADMIN_KEYPAIR!.toSuiAddress()

describe('Investor Wallet Balance', () => {
    let tokenAddress: string
    let dsToken: DSToken
    let investors: Investors
    let wallet1: Keypair
    let wallet2: Keypair
    let wallet3: Keypair
    let issuanceTimeMS: number

    const investorId = 'WalletBalanceTestInvestor'
    const investorId2 = 'WalletBalanceTestInvestor2'

    beforeAll(async () => {
        await deploy()
        issuanceTimeMS = new Date().getTime()
        tokenAddress = await createTestToken()
        dsToken = new DSToken(tokenAddress)
        investors = new Investors(tokenAddress)

        // Create funded wallets for testing
        wallet1 = await createFundedWallet()
        wallet2 = await createFundedWallet()
        wallet3 = await createFundedWallet()
    })

    describe('investorWalletBalanceTotal', () => {
        it('should return 0 for newly registered investor with no tokens', async () => {
            await registerInvestor(tokenAddress, investorId, [wallet1.toSuiAddress()])

            const totalBalance = await investors.investorWalletBalanceTotal(investorId, sender)

            expect(totalBalance).toBe(0n)
        })

        it('should return correct total after issuing tokens to single wallet', async () => {
            await executeTxFunc(
                dsToken.issue(
                    sender,
                    wallet1.toSuiAddress(),
                    1_000_000n,
                    0,
                    '',
                    [],
                    [],
                    issuanceTimeMS
                )
            )

            const totalBalance = await investors.investorWalletBalanceTotal(investorId, sender)

            expect(totalBalance).toBe(1_000_000n)
        })

        it('should return correct total after adding second wallet with tokens', async () => {
            // Add second wallet to investor
            await executeTxFunc(investors.addWallet(investorId, wallet2.toSuiAddress(), sender))

            // Issue tokens to second wallet
            await executeTxFunc(
                dsToken.issue(
                    sender,
                    wallet2.toSuiAddress(),
                    500_000n,
                    0,
                    '',
                    [],
                    [],
                    issuanceTimeMS
                )
            )

            const totalBalance = await investors.investorWalletBalanceTotal(investorId, sender)

            // 1,000,000 (wallet1) + 500,000 (wallet2) = 1,500,000
            expect(totalBalance).toBe(1_500_000n)
        })

        it('should return correct total after adding third wallet with tokens', async () => {
            // Add third wallet to investor
            await executeTxFunc(investors.addWallet(investorId, wallet3.toSuiAddress(), sender))

            // Issue tokens to third wallet
            await executeTxFunc(
                dsToken.issue(
                    sender,
                    wallet3.toSuiAddress(),
                    250_000n,
                    0,
                    '',
                    [],
                    [],
                    issuanceTimeMS
                )
            )

            const totalBalance = await investors.investorWalletBalanceTotal(investorId, sender)

            // 1,000,000 + 500,000 + 250,000 = 1,750,000
            expect(totalBalance).toBe(1_750_000n)
        })

        it('should update total after burning tokens from one wallet', async () => {
            await executeTxFunc(dsToken.burn(sender, wallet1.toSuiAddress(), 200_000n, 'test burn'))

            const totalBalance = await investors.investorWalletBalanceTotal(investorId, sender)

            // 800,000 + 500,000 + 250,000 = 1,550,000
            expect(totalBalance).toBe(1_550_000n)
        })

        it('should update total after transfer between wallets of same investor', async () => {
            // Transfer from wallet1 to wallet2 (both belong to same investor)
            await executeTxFunc(
                dsToken.transfer(
                    wallet1.toSuiAddress(),
                    wallet1.toSuiAddress(),
                    wallet2.toSuiAddress(),
                    100_000n
                ),
                wallet1
            )

            const totalBalance = await investors.investorWalletBalanceTotal(investorId, sender)

            // Total should remain the same: 1,550,000
            expect(totalBalance).toBe(1_550_000n)
        })

        it('should return correct total when two wallets assigned but only one receives tokens', async () => {
            // Create a new investor with two wallets from the start
            const twoWalletInvestorId = 'TwoWalletInvestor'
            const walletA = await createFundedWallet()
            const walletB = await createFundedWallet()

            // Register investor and add both wallets
            await registerInvestor(tokenAddress, twoWalletInvestorId, [
                walletA.toSuiAddress(),
                walletB.toSuiAddress(),
            ])

            // Verify initial total balance is 0
            const initialBalance = await investors.investorWalletBalanceTotal(
                twoWalletInvestorId,
                sender
            )
            expect(initialBalance).toBe(0n)

            // Issue tokens to only ONE wallet (walletA)
            await executeTxFunc(
                dsToken.issue(
                    sender,
                    walletA.toSuiAddress(),
                    750_000n,
                    0,
                    '',
                    [],
                    [],
                    issuanceTimeMS
                )
            )

            // Verify total balance equals the amount issued to the single wallet
            const totalBalance = await investors.investorWalletBalanceTotal(
                twoWalletInvestorId,
                sender
            )
            expect(totalBalance).toBe(750_000n)

            // Verify individual wallet balances
            const walletABalance = await investors.investorWalletBalance(
                walletA.toSuiAddress(),
                sender
            )
            const walletBBalance = await investors.investorWalletBalance(
                walletB.toSuiAddress(),
                sender
            )
            expect(walletABalance).toBe(750_000n)
            expect(walletBBalance).toBe(0n)

            // Verify sum of individual balances equals total
            expect(walletABalance + walletBBalance).toBe(totalBalance)
        })

        it('should accumulate total correctly with multiple issuances to same wallet', async () => {
            const multiIssuanceInvestorId = 'MultiIssuanceInvestor'
            const multiWallet = await createFundedWallet()

            await registerInvestor(tokenAddress, multiIssuanceInvestorId, [
                multiWallet.toSuiAddress(),
            ])

            // First issuance
            await executeTxFunc(
                dsToken.issue(
                    sender,
                    multiWallet.toSuiAddress(),
                    100_000n,
                    0,
                    '',
                    [],
                    [],
                    issuanceTimeMS
                )
            )

            let totalBalance = await investors.investorWalletBalanceTotal(
                multiIssuanceInvestorId,
                sender
            )
            expect(totalBalance).toBe(100_000n)

            // Second issuance to same wallet
            await executeTxFunc(
                dsToken.issue(
                    sender,
                    multiWallet.toSuiAddress(),
                    200_000n,
                    0,
                    '',
                    [],
                    [],
                    issuanceTimeMS
                )
            )

            totalBalance = await investors.investorWalletBalanceTotal(
                multiIssuanceInvestorId,
                sender
            )
            expect(totalBalance).toBe(300_000n)

            // Third issuance to same wallet
            await executeTxFunc(
                dsToken.issue(
                    sender,
                    multiWallet.toSuiAddress(),
                    50_000n,
                    0,
                    '',
                    [],
                    [],
                    issuanceTimeMS
                )
            )

            totalBalance = await investors.investorWalletBalanceTotal(
                multiIssuanceInvestorId,
                sender
            )
            expect(totalBalance).toBe(350_000n)
        })

        it('should return 0 after all tokens are burned from investor wallets', async () => {
            const burnAllInvestorId = 'BurnAllInvestor'
            const burnWallet = await createFundedWallet()

            await registerInvestor(tokenAddress, burnAllInvestorId, [burnWallet.toSuiAddress()])

            // Issue tokens
            await executeTxFunc(
                dsToken.issue(
                    sender,
                    burnWallet.toSuiAddress(),
                    500_000n,
                    0,
                    '',
                    [],
                    [],
                    issuanceTimeMS
                )
            )

            let totalBalance = await investors.investorWalletBalanceTotal(burnAllInvestorId, sender)
            expect(totalBalance).toBe(500_000n)

            // Burn all tokens
            await executeTxFunc(
                dsToken.burn(sender, burnWallet.toSuiAddress(), 500_000n, 'burn all')
            )

            totalBalance = await investors.investorWalletBalanceTotal(burnAllInvestorId, sender)
            expect(totalBalance).toBe(0n)
        })

        it('should handle multiple wallets with varying balances correctly', async () => {
            const varyingBalanceInvestorId = 'VaryingBalanceInvestor'
            const varyingWallet1 = await createFundedWallet()
            const varyingWallet2 = await createFundedWallet()
            const varyingWallet3 = await createFundedWallet()

            // Register investor with all three wallets
            await registerInvestor(tokenAddress, varyingBalanceInvestorId, [
                varyingWallet1.toSuiAddress(),
                varyingWallet2.toSuiAddress(),
                varyingWallet3.toSuiAddress(),
            ])

            // Issue different amounts to each wallet
            await executeTxFunc(
                dsToken.issue(
                    sender,
                    varyingWallet1.toSuiAddress(),
                    1_000_000n,
                    0,
                    '',
                    [],
                    [],
                    issuanceTimeMS
                )
            )
            await executeTxFunc(
                dsToken.issue(
                    sender,
                    varyingWallet2.toSuiAddress(),
                    2_500_000n,
                    0,
                    '',
                    [],
                    [],
                    issuanceTimeMS
                )
            )
            await executeTxFunc(
                dsToken.issue(
                    sender,
                    varyingWallet3.toSuiAddress(),
                    500_000n,
                    0,
                    '',
                    [],
                    [],
                    issuanceTimeMS
                )
            )

            const totalBalance = await investors.investorWalletBalanceTotal(
                varyingBalanceInvestorId,
                sender
            )

            // 1,000,000 + 2,500,000 + 500,000 = 4,000,000
            expect(totalBalance).toBe(4_000_000n)
        })

        it('should correctly isolate balances between different investors', async () => {
            const isolatedInvestorA = 'IsolatedInvestorA'
            const isolatedInvestorB = 'IsolatedInvestorB'
            const isolatedWalletA = await createFundedWallet()
            const isolatedWalletB = await createFundedWallet()

            await registerInvestor(tokenAddress, isolatedInvestorA, [
                isolatedWalletA.toSuiAddress(),
            ])
            await registerInvestor(tokenAddress, isolatedInvestorB, [
                isolatedWalletB.toSuiAddress(),
            ])

            // Issue tokens to investor A only
            await executeTxFunc(
                dsToken.issue(
                    sender,
                    isolatedWalletA.toSuiAddress(),
                    1_000_000n,
                    0,
                    '',
                    [],
                    [],
                    issuanceTimeMS
                )
            )

            const balanceA = await investors.investorWalletBalanceTotal(isolatedInvestorA, sender)
            const balanceB = await investors.investorWalletBalanceTotal(isolatedInvestorB, sender)

            expect(balanceA).toBe(1_000_000n)
            expect(balanceB).toBe(0n)

            // Issue tokens to investor B
            await executeTxFunc(
                dsToken.issue(
                    sender,
                    isolatedWalletB.toSuiAddress(),
                    500_000n,
                    0,
                    '',
                    [],
                    [],
                    issuanceTimeMS
                )
            )

            // Verify A's balance unchanged
            const balanceAAfter = await investors.investorWalletBalanceTotal(
                isolatedInvestorA,
                sender
            )
            const balanceBAfter = await investors.investorWalletBalanceTotal(
                isolatedInvestorB,
                sender
            )

            expect(balanceAAfter).toBe(1_000_000n)
            expect(balanceBAfter).toBe(500_000n)
        })
    })

    describe('investorWalletBalance', () => {
        it('should return correct balance for each individual wallet', async () => {
            // After previous tests:
            // wallet1: 1,000,000 - 200,000 (burn) - 100,000 (transfer) = 700,000
            // wallet2: 500,000 + 100,000 (transfer) = 600,000
            // wallet3: 250,000

            const balance1 = await investors.investorWalletBalance(wallet1.toSuiAddress(), sender)
            const balance2 = await investors.investorWalletBalance(wallet2.toSuiAddress(), sender)
            const balance3 = await investors.investorWalletBalance(wallet3.toSuiAddress(), sender)

            expect(balance1).toBe(700_000n)
            expect(balance2).toBe(600_000n)
            expect(balance3).toBe(250_000n)
        })

        it('should return 0 for wallet with no tokens', async () => {
            const newWallet = await createFundedWallet()
            await registerInvestor(tokenAddress, investorId2, [newWallet.toSuiAddress()])

            const balance = await investors.investorWalletBalance(newWallet.toSuiAddress(), sender)

            expect(balance).toBe(0n)
        })

        it('should sum of individual wallets equal total balance', async () => {
            const balance1 = await investors.investorWalletBalance(wallet1.toSuiAddress(), sender)
            const balance2 = await investors.investorWalletBalance(wallet2.toSuiAddress(), sender)
            const balance3 = await investors.investorWalletBalance(wallet3.toSuiAddress(), sender)
            const totalBalance = await investors.investorWalletBalanceTotal(investorId, sender)

            expect(balance1 + balance2 + balance3).toBe(totalBalance)
        })

        it('should update wallet balance after additional issuance', async () => {
            const balanceBefore = await investors.investorWalletBalance(
                wallet2.toSuiAddress(),
                sender
            )

            await executeTxFunc(
                dsToken.issue(
                    sender,
                    wallet2.toSuiAddress(),
                    300_000n,
                    0,
                    '',
                    [],
                    [],
                    issuanceTimeMS
                )
            )

            const balanceAfter = await investors.investorWalletBalance(
                wallet2.toSuiAddress(),
                sender
            )

            expect(balanceAfter).toBe(balanceBefore + 300_000n)
        })

        it('should update wallet balance after transfer to different investor', async () => {
            const otherInvestorWallet = await createFundedWallet()
            await registerInvestor(tokenAddress, 'OtherInvestor', [
                otherInvestorWallet.toSuiAddress(),
            ])

            const balanceBefore = await investors.investorWalletBalance(
                wallet1.toSuiAddress(),
                sender
            )

            // Transfer from wallet1 to different investor
            await executeTxFunc(
                dsToken.transfer(
                    wallet1.toSuiAddress(),
                    wallet1.toSuiAddress(),
                    otherInvestorWallet.toSuiAddress(),
                    150_000n
                ),
                wallet1
            )

            const balanceAfter = await investors.investorWalletBalance(
                wallet1.toSuiAddress(),
                sender
            )

            expect(balanceAfter).toBe(balanceBefore - 150_000n)
        })
    })

    describe('edge cases', () => {
        it('total balance should match getInvestorDetails totalBalance', async () => {
            const details = await investors.getInvestorDetails(investorId)
            const totalBalance = await investors.investorWalletBalanceTotal(investorId, sender)

            expect(totalBalance).toBe(BigInt(details.totalBalance))
        })

        it('should handle wallet removed from investor', async () => {
            // Get current balances
            const totalBefore = await investors.investorWalletBalanceTotal(investorId, sender)
            const wallet3Balance = await investors.investorWalletBalance(
                wallet3.toSuiAddress(),
                sender
            )

            // Remove wallet3 from investor (note: this may require moving tokens first based on contract logic)
            // First burn tokens from wallet3 to make it empty
            await executeTxFunc(
                dsToken.burn(sender, wallet3.toSuiAddress(), wallet3Balance, 'removing wallet')
            )

            await executeTxFunc(investors.removeWallet(investorId, wallet3.toSuiAddress(), sender))

            const totalAfter = await investors.investorWalletBalanceTotal(investorId, sender)

            expect(totalAfter).toBe(totalBefore - wallet3Balance)
        })
    })
})
