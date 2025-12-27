import { ADMIN_KEYPAIR, CountryCompliance, ComplianceStatus } from '../src'
import { deploy } from '../src/sdk/utils/deploy'
import { createTestToken, executeTxFunc } from './test_utils'

const sender = ADMIN_KEYPAIR!.toSuiAddress()

describe('CountryCompliance', () => {
    let tokenAddress: string
    let countryCompliance: CountryCompliance

    beforeAll(async () => {
        await deploy()
        tokenAddress = await createTestToken()
        countryCompliance = new CountryCompliance(tokenAddress)
    })

    describe('Country Compliance Management', () => {
        it('should set country compliance', async () => {
            await executeTxFunc(countryCompliance.set(sender, 'USA', 'us'))
            await expect(countryCompliance.get('USA', sender)).resolves.toBe('us')
        })

        it('should update existing country compliance with different value', async () => {
            // Set initial compliance region
            await executeTxFunc(countryCompliance.set(sender, 'GB', 'eu'))
            await expect(countryCompliance.get('GB', sender)).resolves.toBe('eu')

            // Update compliance region
            await executeTxFunc(countryCompliance.set(sender, 'GB', 'jp'))
            await expect(countryCompliance.get('GB', sender)).resolves.toBe('jp')

            // Update compliance region with the same value
            await expect(executeTxFunc(countryCompliance.set(sender, 'GB', 'jp'))).rejects.toThrow()

            await expect(countryCompliance.get('GB', sender)).resolves.toBe('jp')
        })

        it('should be able to delete an existent country', async () => {
            await executeTxFunc(countryCompliance.set(sender, 'GB', 'eu'))
            await expect(countryCompliance.get('GB', sender)).resolves.toBe('eu')

            // delete existing country
            await executeTxFunc(countryCompliance.set(sender, 'GB', 'none'))
            await expect(countryCompliance.get('GB', sender)).resolves.toBe('none')
        })

        it('should not be able to delete an non existent country', async () => {
            await expect(
                executeTxFunc(countryCompliance.set(sender, 'GB', 'none'))
            ).rejects.toThrow()
        })

        it('should return none for non-existent country compliance', async () => {
            const country = 'XX' // Non-existent country
            await expect(countryCompliance.get(country, sender)).resolves.toBe('none')
        })

        it('should handle multiple countries with different regions', async () => {
            const countryRegions = [
                { country: 'CA', region: 'us' },
                { country: 'US', region: 'us' },
                { country: 'AU', region: 'jp' },
                { country: 'BR', region: 'eu' },
            ]

            for (const { country, region } of countryRegions) {
                await executeTxFunc(
                    countryCompliance.set(sender, country, region as ComplianceStatus)
                )
                await expect(countryCompliance.get(country, sender)).resolves.toBe(region)
            }
        })
    })

    describe('PTB (Programmable Transaction Block) Methods', () => {
        it('should create PTB for setting country compliance', async () => {
            const ptb = countryCompliance.setCountryCompliancePTB('US', 'us')
            expect(ptb).toBeDefined()
            expect(ptb.blockData).toBeDefined()
        })
    })

    describe('Edge Cases', () => {
        it('should handle empty country code', async () => {
            await executeTxFunc(countryCompliance.set(sender, '', 'us'))
            await expect(countryCompliance.get('', sender)).resolves.toBe('us')
        })
    })
})
