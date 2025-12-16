import {ADMIN_KEYPAIR} from '../src'
import {deploy} from '../src/sdk/utils/deploy'
import {createTestToken, executeTxFunc, testTokenRequest,} from './test_utils'
import {DSToken} from "../src/sdk/DSToken";

const sender = ADMIN_KEYPAIR!.toSuiAddress()

describe('DSToken', () => {
    let tokenAddress: string
    let dsToken: DSToken

    beforeAll(async () => {
        await deploy()
        tokenAddress = await createTestToken()
        dsToken = new DSToken(tokenAddress)
    })

    describe('metadata', () => {
        it('should get total issued', async () => {
            const totalIssued = await dsToken.getTotalIssued()
            expect(totalIssued).toBe('0')
        })

        it('should have original metadata', async () => {
            const data = await dsToken.getMetadata(sender)
            expect(data.name).toBe(testTokenRequest.tokenDescription.name)
            expect(data.symbol).toBe(testTokenRequest.tokenDescription.symbol)
            expect(data.decimals).toBe(testTokenRequest.tokenDescription.decimals)
            expect(data.description).toBe(testTokenRequest.tokenDescription.description)
            expect(data.totalIssued).toBe('0')
            expect(data.isPaused).toBe(false)
        })

        it('should update name', async () => {
            await executeTxFunc(dsToken.setMetadata(sender, "new_name", undefined, undefined))

            const data = await dsToken.getMetadata(sender)
            expect(data.name).toBe("new_name")
            expect(data.symbol).toBe(testTokenRequest.tokenDescription.symbol)
            expect(data.decimals).toBe(testTokenRequest.tokenDescription.decimals)
            expect(data.description).toBe(testTokenRequest.tokenDescription.description)
            expect(data.iconUri).toBe(testTokenRequest.tokenDescription.iconUri)
            expect(data.totalIssued).toBe('0')
            expect(data.isPaused).toBe(false)
        })

        it('should update description', async () => {
            await executeTxFunc(dsToken.setMetadata(sender, undefined, "new description", undefined))

            const data = await dsToken.getMetadata(sender)
            expect(data.name).toBe("new_name")
            expect(data.symbol).toBe(testTokenRequest.tokenDescription.symbol)
            expect(data.decimals).toBe(testTokenRequest.tokenDescription.decimals)
            expect(data.description).toBe("new description")
            expect(data.iconUri).toBe(testTokenRequest.tokenDescription.iconUri)
            expect(data.totalIssued).toBe('0')
            expect(data.isPaused).toBe(false)
        })

        it('should update icon_url', async () => {
            await executeTxFunc(dsToken.setMetadata(sender, undefined, undefined, "new iconUri"))

            const data = await dsToken.getMetadata(sender)
            expect(data.name).toBe("new_name")
            expect(data.symbol).toBe(testTokenRequest.tokenDescription.symbol)
            expect(data.decimals).toBe(testTokenRequest.tokenDescription.decimals)
            expect(data.description).toBe("new description")
            expect(data.iconUri).toBe("new iconUri")
            expect(data.totalIssued).toBe('0')
            expect(data.isPaused).toBe(false)
        })

        it('should update all', async () => {
            await executeTxFunc(dsToken.setMetadata(sender, "all_name", "all description", "all iconUri"))

            const data = await dsToken.getMetadata(sender)
            expect(data.name).toBe("all_name")
            expect(data.symbol).toBe(testTokenRequest.tokenDescription.symbol)
            expect(data.decimals).toBe(testTokenRequest.tokenDescription.decimals)
            expect(data.description).toBe("all description")
            expect(data.iconUri).toBe("all iconUri")
            expect(data.totalIssued).toBe('0')
            expect(data.isPaused).toBe(false)
        })
    })
})
