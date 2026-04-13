import {
    assertToken,
    complianceRules,
    countriesComplianceStatuses,
    createTestToken,
    owners,
} from './test_utils'
import { deploy } from '../src/sdk/utils/deploy'
import { ADMIN_KEYPAIR } from '../src'

describe('Ds token', () => {
    beforeAll(async () => {
        await deploy(ADMIN_KEYPAIR!)
    })

    it('should deploy a token', async () => {
        const tokenAddress = await createTestToken(
            complianceRules,
            countriesComplianceStatuses,
            owners
        )
        assertToken(tokenAddress)
    })
})
