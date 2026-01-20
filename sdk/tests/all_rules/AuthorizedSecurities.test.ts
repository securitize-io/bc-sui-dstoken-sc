import { ADMIN_KEYPAIR, AuthorizedSecurities } from '../../src'
import { deploy } from '../../src/sdk/utils/deploy'
import { createTestToken, executeTxFunc } from '../test_utils'

const sender = ADMIN_KEYPAIR!.toSuiAddress()

describe('AuthorizedSecurities Rule', () => {
    let tokenAddress: string
    let authorizedSecurities: AuthorizedSecurities

    beforeAll(async () => {
        await deploy()
        tokenAddress = await createTestToken()
        authorizedSecurities = new AuthorizedSecurities(tokenAddress)
    })

    describe('Rule Registration', () => {
        it('should register AuthorizedSecurities rule with max supply', async () => {
            await expect(authorizedSecurities.exists(sender)).resolves.toBe(false)

            await executeTxFunc(
                authorizedSecurities.register(sender, BigInt(1000000))
            )

            await expect(authorizedSecurities.exists(sender)).resolves.toBe(true)
        })

        it('should unregister AuthorizedSecurities rule', async () => {
            await expect(authorizedSecurities.exists(sender)).resolves.toBe(true)

            await executeTxFunc(authorizedSecurities.unregister(sender))

            await expect(authorizedSecurities.exists(sender)).resolves.toBe(false)
        })

        it('should register AuthorizedSecurities with different max supply values', async () => {
            const maxSupplyValues = [
                BigInt(100),
                BigInt(50000),
                BigInt(1000000000),
            ]

            for (const maxSupply of maxSupplyValues) {
                await executeTxFunc(
                    authorizedSecurities.register(sender, maxSupply)
                )
                await expect(authorizedSecurities.exists(sender)).resolves.toBe(true)
                await executeTxFunc(authorizedSecurities.unregister(sender))
                await expect(authorizedSecurities.exists(sender)).resolves.toBe(false)
            }
        })

        it('should not allow registering AuthorizedSecurities rule twice', async () => {
            await executeTxFunc(authorizedSecurities.register(sender, BigInt(1000)))

            await expect(
                executeTxFunc(authorizedSecurities.register(sender, BigInt(2000)))
            ).rejects.toThrow()

            await executeTxFunc(authorizedSecurities.unregister(sender))
        })
    })

    describe('PTB (Programmable Transaction Block) Methods', () => {
        it('should create PTB for registration', async () => {
            const ptb = authorizedSecurities.registerPTB(BigInt(500000))
            expect(ptb).toBeDefined()
            expect(ptb.blockData).toBeDefined()
        })
    })

    describe('Rule Updates', () => {
        it('should be able to set the values', async () => {
            await executeTxFunc(authorizedSecurities.register(sender, BigInt(1000000)))

            await executeTxFunc(authorizedSecurities.setMaxSupply(BigInt(2000000), sender))
            await expect(authorizedSecurities.exists(sender)).resolves.toBe(true)

            await executeTxFunc(authorizedSecurities.unregister(sender))
        })
    })

    describe('Edge Cases', () => {
        it('should handle undefined max supply (defaults to 0 - unlimited)', async () => {
            await executeTxFunc(
                authorizedSecurities.register(sender, undefined)
            )
            await expect(authorizedSecurities.exists(sender)).resolves.toBe(true)
            await executeTxFunc(authorizedSecurities.unregister(sender))
        })

        it('should handle zero max supply (unlimited issuance)', async () => {
            await executeTxFunc(
                authorizedSecurities.register(sender, BigInt(0))
            )
            await expect(authorizedSecurities.exists(sender)).resolves.toBe(true)
            await executeTxFunc(authorizedSecurities.unregister(sender))
        })

        it('should handle large max supply values', async () => {
            const largeSupply = BigInt("18446744073709551615") // Max u64
            await executeTxFunc(
                authorizedSecurities.register(sender, largeSupply)
            )
            await expect(authorizedSecurities.exists(sender)).resolves.toBe(true)
            await executeTxFunc(authorizedSecurities.unregister(sender))
        })
    })
})
