import {
    assertToken,
    complianceRules,
    countriesComplianceStatuses,
    createTestToken,
    owners,
} from './test_utils'
import { deploy } from '../src/sdk/utils/deploy'

describe('Ds token', () => {
    beforeAll(async () => {
        await deploy()
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
