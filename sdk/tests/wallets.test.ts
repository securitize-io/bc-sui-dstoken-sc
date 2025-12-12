import {
    ADMIN_KEYPAIR,
    Wallets,
    Investors,
    createWallet
} from '../src'
import {deploy} from "../src/sdk/utils/deploy";
import {createTestToken, executeTxFunc} from "./test_utils";

const sender = ADMIN_KEYPAIR!.toSuiAddress();

describe('Wallets', () => {
    let tokenAddress: string
    let wallets: Wallets
    let investors: Investors
    let testIssuerWallet: string
    let testPlatformWallet: string

    beforeAll(async () => {
        await deploy()
        tokenAddress = await createTestToken()
        wallets = new Wallets(tokenAddress)
        investors = new Investors(tokenAddress)

        // Create test wallets for special wallet assignment
        testIssuerWallet = createWallet().toSuiAddress()
        testPlatformWallet = createWallet().toSuiAddress()
    })

    describe('Issuer Wallet Management', () => {
        it('should add issuer wallet', async () => {
            // Verify wallet is not an issuer initially
            await expect(wallets.isIssuerWallet(testIssuerWallet, sender)).resolves.toBe(false)
            await expect(wallets.isPlatformWallet(testIssuerWallet, sender)).resolves.toBe(false)

            // Add issuer wallet
            await executeTxFunc(wallets.addIssuerWallet(testIssuerWallet, sender))

            // Verify wallet is now an issuer wallet
            await expect(wallets.isIssuerWallet(testIssuerWallet, sender)).resolves.toBe(true)
            await expect(wallets.isPlatformWallet(testIssuerWallet, sender)).resolves.toBe(false)
        })

        it('should remove issuer wallet', async () => {
            // Verify issuer wallet exists
            await expect(wallets.isIssuerWallet(testIssuerWallet, sender)).resolves.toBe(true)

            // Remove issuer wallet
            await executeTxFunc(wallets.removeSpecialWallet(testIssuerWallet, sender))

            // Verify wallet is no longer a special wallet
            await expect(wallets.isIssuerWallet(testIssuerWallet, sender)).resolves.toBe(false)
            await expect(wallets.isPlatformWallet(testIssuerWallet, sender)).resolves.toBe(false)
        })
    })

    describe('Platform Wallet Management', () => {
        it('should add platform wallet', async () => {
            // Verify wallet is not a platform wallet initially
            await expect(wallets.isPlatformWallet(testPlatformWallet, sender)).resolves.toBe(false)
            await expect(wallets.isIssuerWallet(testPlatformWallet, sender)).resolves.toBe(false)

            // Add platform wallet
            await executeTxFunc(wallets.addPlatformWallet(testPlatformWallet, sender))

            // Verify wallet is now a platform wallet
            await expect(wallets.isPlatformWallet(testPlatformWallet, sender)).resolves.toBe(true)
            await expect(wallets.isIssuerWallet(testPlatformWallet, sender)).resolves.toBe(false)
        })

        it('should remove platform wallet', async () => {
            // Verify platform wallet exists
            await expect(wallets.isPlatformWallet(testPlatformWallet, sender)).resolves.toBe(true)

            // Remove platform wallet
            await executeTxFunc(wallets.removeSpecialWallet(testPlatformWallet, sender))

            // Verify wallet is no longer a special wallet
            await expect(wallets.isPlatformWallet(testPlatformWallet, sender)).resolves.toBe(false)
            await expect(wallets.isIssuerWallet(testPlatformWallet, sender)).resolves.toBe(false)
        })
    })

    describe('Special Wallet Edge Cases', () => {
        it('should not allow adding issuer wallet that belongs to an investor', async () => {
            const testWallet = createWallet().toSuiAddress()
            const testInvestorId = "TestInvestor1"

            // First register an investor and add wallet
            await executeTxFunc(investors.registerInvestor(testInvestorId, sender))
            await executeTxFunc(investors.addWallet(testInvestorId, testWallet, sender))

            // Verify wallet belongs to investor
            await expect(investors.isWallet(testWallet, sender)).resolves.toBe(true)

            // Try to add as issuer wallet (should fail - EWalletBelongsToInvestor)
            await expect(
                executeTxFunc(wallets.addIssuerWallet(testWallet, sender))
            ).rejects.toThrow()

            // Clean up
            await executeTxFunc(investors.removeWallet(testInvestorId, testWallet, sender))
            await executeTxFunc(investors.removeInvestor(testInvestorId, sender))
        })

        it('should not allow adding platform wallet that belongs to an investor', async () => {
            const testWallet = createWallet().toSuiAddress()
            const testInvestorId = "TestInvestor2"

            // First register an investor and add wallet
            await executeTxFunc(investors.registerInvestor(testInvestorId, sender))
            await executeTxFunc(investors.addWallet(testInvestorId, testWallet, sender))

            // Try to add as platform wallet (should fail - EWalletBelongsToInvestor)
            await expect(
                executeTxFunc(wallets.addPlatformWallet(testWallet, sender))
            ).rejects.toThrow()

            // Clean up
            await executeTxFunc(investors.removeWallet(testInvestorId, testWallet, sender))
            await executeTxFunc(investors.removeInvestor(testInvestorId, sender))
        })

        it('should not allow direct wallet type change', async () => {
            const testWallet = createWallet().toSuiAddress()

            // Add as issuer wallet
            await executeTxFunc(wallets.addIssuerWallet(testWallet, sender))
            await expect(wallets.isIssuerWallet(testWallet, sender)).resolves.toBe(true)

            // Try to change to platform wallet directly (should fail - EDirectWalletChange)
            await expect(
                executeTxFunc(wallets.addPlatformWallet(testWallet, sender))
            ).rejects.toThrow()

            // Clean up
            await executeTxFunc(wallets.removeSpecialWallet(testWallet, sender))
        })

        it('should allow wallet type change after removal', async () => {
            const testWallet = createWallet().toSuiAddress()

            // Add as issuer wallet
            await executeTxFunc(wallets.addIssuerWallet(testWallet, sender))
            await expect(wallets.isIssuerWallet(testWallet, sender)).resolves.toBe(true)

            // Remove issuer wallet
            await executeTxFunc(wallets.removeSpecialWallet(testWallet, sender))
            await expect(wallets.isIssuerWallet(testWallet, sender)).resolves.toBe(false)

            // Now add as platform wallet (should succeed)
            await executeTxFunc(wallets.addPlatformWallet(testWallet, sender))
            await expect(wallets.isPlatformWallet(testWallet, sender)).resolves.toBe(true)

            // Clean up
            await executeTxFunc(wallets.removeSpecialWallet(testWallet, sender))
        })

        it('should not allow removing non-special wallet', async () => {
            const testWallet = createWallet().toSuiAddress()

            // Verify wallet is not a special wallet
            await expect(wallets.isIssuerWallet(testWallet, sender)).resolves.toBe(false)
            await expect(wallets.isPlatformWallet(testWallet, sender)).resolves.toBe(false)

            // Try to remove (should fail - ENotSpecialWallet)
            await expect(
                executeTxFunc(wallets.removeSpecialWallet(testWallet, sender))
            ).rejects.toThrow()
        })
    })

    describe('Multiple Special Wallets', () => {
        it('should handle multiple issuer wallets', async () => {
            const issuerWallet1 = createWallet().toSuiAddress()
            const issuerWallet2 = createWallet().toSuiAddress()
            const issuerWallet3 = createWallet().toSuiAddress()

            // Add multiple issuer wallets
            await executeTxFunc(wallets.addIssuerWallet(issuerWallet1, sender))
            await executeTxFunc(wallets.addIssuerWallet(issuerWallet2, sender))
            await executeTxFunc(wallets.addIssuerWallet(issuerWallet3, sender))

            // Verify all are issuer wallets
            await expect(wallets.isIssuerWallet(issuerWallet1, sender)).resolves.toBe(true)
            await expect(wallets.isIssuerWallet(issuerWallet2, sender)).resolves.toBe(true)
            await expect(wallets.isIssuerWallet(issuerWallet3, sender)).resolves.toBe(true)

            // Clean up
            await executeTxFunc(wallets.removeSpecialWallet(issuerWallet1, sender))
            await executeTxFunc(wallets.removeSpecialWallet(issuerWallet2, sender))
            await executeTxFunc(wallets.removeSpecialWallet(issuerWallet3, sender))
        })

        it('should handle multiple platform wallets', async () => {
            const platformWallet1 = createWallet().toSuiAddress()
            const platformWallet2 = createWallet().toSuiAddress()

            // Add multiple platform wallets
            await executeTxFunc(wallets.addPlatformWallet(platformWallet1, sender))
            await executeTxFunc(wallets.addPlatformWallet(platformWallet2, sender))

            // Verify all are platform wallets
            await expect(wallets.isPlatformWallet(platformWallet1, sender)).resolves.toBe(true)
            await expect(wallets.isPlatformWallet(platformWallet2, sender)).resolves.toBe(true)

            // Clean up
            await executeTxFunc(wallets.removeSpecialWallet(platformWallet1, sender))
            await executeTxFunc(wallets.removeSpecialWallet(platformWallet2, sender))
        })

        it('should handle mix of issuer and platform wallets', async () => {
            const issuerWallet = createWallet().toSuiAddress()
            const platformWallet = createWallet().toSuiAddress()

            // Add different types
            await executeTxFunc(wallets.addIssuerWallet(issuerWallet, sender))
            await executeTxFunc(wallets.addPlatformWallet(platformWallet, sender))

            // Verify correct types
            await expect(wallets.isIssuerWallet(issuerWallet, sender)).resolves.toBe(true)
            await expect(wallets.isPlatformWallet(issuerWallet, sender)).resolves.toBe(false)
            await expect(wallets.isPlatformWallet(platformWallet, sender)).resolves.toBe(true)
            await expect(wallets.isIssuerWallet(platformWallet, sender)).resolves.toBe(false)

            // Clean up
            await executeTxFunc(wallets.removeSpecialWallet(issuerWallet, sender))
            await executeTxFunc(wallets.removeSpecialWallet(platformWallet, sender))
        })
    })
})
