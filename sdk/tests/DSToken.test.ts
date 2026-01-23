import { ADMIN_KEYPAIR, createFundedWallet, DSToken, Wallets } from '../src'
import { deploy } from '../src/sdk/utils/deploy'
import {
    assertInvestorBalance,
    createTestToken,
    executeTxFunc,
    registerInvestor,
    testTokenRequest,
} from './test_utils'
import { Keypair } from '@mysten/sui/cryptography'

const sender = ADMIN_KEYPAIR!.toSuiAddress()

describe('DSToken', () => {
    let tokenAddress: string
    let dsToken: DSToken
    let investor2: Keypair
    let issuer: Keypair
    let issuanceTimeMS: number

    beforeAll(async () => {
        await deploy()
        issuanceTimeMS = new Date().getTime()
        tokenAddress = await createTestToken()
        dsToken = new DSToken(tokenAddress)
        investor2 = await createFundedWallet()
        issuer = await createFundedWallet()
        await registerInvestor(tokenAddress, 'testInvestor')
        await registerInvestor(tokenAddress, 'testInvestor2', [investor2.toSuiAddress()])
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
            await executeTxFunc(dsToken.setMetadata(sender, 'new_name', undefined, undefined))

            const data = await dsToken.getMetadata(sender)
            expect(data.name).toBe('new_name')
            expect(data.symbol).toBe(testTokenRequest.tokenDescription.symbol)
            expect(data.decimals).toBe(testTokenRequest.tokenDescription.decimals)
            expect(data.description).toBe(testTokenRequest.tokenDescription.description)
            expect(data.iconUri).toBe(testTokenRequest.tokenDescription.iconUri)
            expect(data.totalIssued).toBe('0')
            expect(data.isPaused).toBe(false)
        })

        it('should update description', async () => {
            await executeTxFunc(
                dsToken.setMetadata(sender, undefined, 'new description', undefined)
            )

            const data = await dsToken.getMetadata(sender)
            expect(data.name).toBe('new_name')
            expect(data.symbol).toBe(testTokenRequest.tokenDescription.symbol)
            expect(data.decimals).toBe(testTokenRequest.tokenDescription.decimals)
            expect(data.description).toBe('new description')
            expect(data.iconUri).toBe(testTokenRequest.tokenDescription.iconUri)
            expect(data.totalIssued).toBe('0')
            expect(data.isPaused).toBe(false)
        })

        it('should update icon_url', async () => {
            await executeTxFunc(dsToken.setMetadata(sender, undefined, undefined, 'new iconUri'))

            const data = await dsToken.getMetadata(sender)
            expect(data.name).toBe('new_name')
            expect(data.symbol).toBe(testTokenRequest.tokenDescription.symbol)
            expect(data.decimals).toBe(testTokenRequest.tokenDescription.decimals)
            expect(data.description).toBe('new description')
            expect(data.iconUri).toBe('new iconUri')
            expect(data.totalIssued).toBe('0')
            expect(data.isPaused).toBe(false)
        })

        it('should update all', async () => {
            await executeTxFunc(
                dsToken.setMetadata(sender, 'all_name', 'all description', 'all iconUri')
            )

            const data = await dsToken.getMetadata(sender)
            expect(data.name).toBe('all_name')
            expect(data.symbol).toBe(testTokenRequest.tokenDescription.symbol)
            expect(data.decimals).toBe(testTokenRequest.tokenDescription.decimals)
            expect(data.description).toBe('all description')
            expect(data.iconUri).toBe('all iconUri')
            expect(data.totalIssued).toBe('0')
            expect(data.isPaused).toBe(false)
        })
    })

    describe('issue/burn tokens', () => {
        it('should issue tokens', async () => {
            const totalIssued = await dsToken.getTotalIssued()
            expect(totalIssued).toBe('0')

            await executeTxFunc(dsToken.issue(sender, sender, 1_000_000n, 0, '', [], [], issuanceTimeMS))

            const totalIssuedAfter = await dsToken.getTotalIssued()
            expect(totalIssuedAfter).toBe('1000000')
            await assertInvestorBalance(tokenAddress, 'testInvestor', '1000000')
        })

        it('should issue tokens with no vault', async () => {
            const totalIssued = await dsToken.getTotalIssued()
            expect(totalIssued).toBe('1000000')

            await executeTxFunc(dsToken.issueNoVault(sender, sender, 1_000_000n, 0, '', [], [], issuanceTimeMS))

            const totalIssuedAfter = await dsToken.getTotalIssued()
            expect(totalIssuedAfter).toBe('2000000')
            await assertInvestorBalance(tokenAddress, 'testInvestor', '2000000')
        })

        it('should burn tokens', async () => {
            await executeTxFunc(dsToken.burn(sender, sender, 500_000n, 'reason'))

            const totalIssuedAfter = await dsToken.getTotalIssued()
            expect(totalIssuedAfter).toBe('1500000')
            await assertInvestorBalance(tokenAddress, 'testInvestor', '1500000')
        })
    })

    describe('pause/unpause tokens', () => {
        it('should pause/unpause tokens', async () => {
            await expect(dsToken.isPaused(sender)).resolves.toBeFalsy()
            await executeTxFunc(dsToken.pause(sender))
            await expect(dsToken.isPaused(sender)).resolves.toBeTruthy()
            await executeTxFunc(dsToken.unpause(sender))
            await expect(dsToken.isPaused(sender)).resolves.toBeFalsy()
        })

        it('should not allow token transfers when paused', async () => {
            await expect(dsToken.isPaused(sender)).resolves.toBeFalsy()
            await executeTxFunc(dsToken.pause(sender))
            await expect(dsToken.isPaused(sender)).resolves.toBeTruthy()

            await expect(
                executeTxFunc(dsToken.transfer(sender, sender, investor2.toSuiAddress(), 300_000n))
            ).rejects.toThrow()

            await executeTxFunc(dsToken.unpause(sender))
            await expect(dsToken.isPaused(sender)).resolves.toBeFalsy()
        })
    })

    describe('transfer', () => {
        it('should transfer tokens', async () => {
            await executeTxFunc(dsToken.issue(sender, sender, 1_000_000n, 0, '', [], [], issuanceTimeMS))
            await assertInvestorBalance(tokenAddress, 'testInvestor', '2500000')
            await assertInvestorBalance(tokenAddress, 'testInvestor2', '0')

            await executeTxFunc(
                dsToken.transfer(sender, sender, investor2.toSuiAddress(), 300_000n)
            )

            await assertInvestorBalance(tokenAddress, 'testInvestor', '2200000')
            await assertInvestorBalance(tokenAddress, 'testInvestor2', '300000')
        })
    })

    describe('seize tokens', () => {
        it('should seize tokens', async () => {
            const totalIssued = parseInt(await dsToken.getTotalIssued())

            await executeTxFunc(dsToken.issue(sender, sender, 1_000_000n, 0, '', [], [], issuanceTimeMS))
            await executeTxFunc(
                dsToken.issue(sender, investor2.toSuiAddress(), 500_000n, 0, '', [], [], issuanceTimeMS)
            )

            const wallets = new Wallets(tokenAddress)
            await executeTxFunc(wallets.addIssuerWallet(issuer.toSuiAddress(), sender))

            // testInvestor2 had 300,000 from transfer + 500,000 new = 800,000
            await assertInvestorBalance(tokenAddress, 'testInvestor2', '800000')
            await expect(dsToken.getTotalIssued()).resolves.toBe(
                (totalIssued + 1_000_000 + 500_000).toString()
            )

            await executeTxFunc(
                dsToken.seize(
                    sender,
                    investor2.toSuiAddress(),
                    issuer.toSuiAddress(),
                    300_000n,
                    'reason'
                )
            )

            // 800,000 - 300,000 seized = 500,000
            await assertInvestorBalance(tokenAddress, 'testInvestor2', '500000')
            await expect(dsToken.getTotalIssued()).resolves.toBe(
                (totalIssued + 1_000_000 + 500_000).toString()
            )
        })
    })
})
