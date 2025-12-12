import {
    ADMIN_KEYPAIR,
    Roles,
    createWallet,
    createFundedWallet
} from '../src'
import {deploy} from "../src/sdk/utils/deploy";
import {createTestToken, executeTxFunc} from "./test_utils";

const sender = ADMIN_KEYPAIR!.toSuiAddress();

describe('Roles', () => {
    let tokenAddress: string
    let roles: Roles
    let testIssuer: string
    let testExchange: string
    let testTransferAgent: string

    beforeAll(async () => {
        await deploy()
        tokenAddress = await createTestToken()
        roles = new Roles(tokenAddress)

        // Create test wallets for role assignment
        testIssuer = createWallet().toSuiAddress()
        testExchange = createWallet().toSuiAddress()
        testTransferAgent = createWallet().toSuiAddress()
    })

    describe('Issuer Role Management', () => {
        it('should set issuer role', async () => {
            await executeTxFunc(roles.setIssuer(testIssuer, sender))

            const role = await roles.getRole(testIssuer)
            expect(role).toBe('issuer')
        })

        it('should remove issuer role', async () => {
            // Verify issuer role exists
            const roleBefore = await roles.getRole(testIssuer)
            expect(roleBefore).toBe('issuer')

            // Remove issuer role
            await executeTxFunc(roles.removeIssuer(testIssuer, sender))

            // Verify role is removed (should throw or return empty)
            await expect(roles.getRole(testIssuer)).resolves.toBe('none')
        })
    })

    describe('Exchange Role Management', () => {
        it('should set exchange role', async () => {
            await executeTxFunc(roles.setExchange(testExchange, sender))

            const role = await roles.getRole(testExchange)
            expect(role).toBe('exchange')
        })

        it('should remove exchange role', async () => {
            // Verify exchange role exists
            const roleBefore = await roles.getRole(testExchange)
            expect(roleBefore).toBe('exchange')

            // Remove exchange role
            await executeTxFunc(roles.removeExchange(testExchange, sender))

            // Verify role is removed (should throw or return empty)
            await expect(roles.getRole(testIssuer)).resolves.toBe('none')
        })
    })

    describe('TransferAgent Role Management', () => {
        it('should set transfer agent role', async () => {
            await executeTxFunc(roles.setTransferAgent(testTransferAgent, sender))

            const role = await roles.getRole(testTransferAgent)
            expect(role).toBe('transfer_agent')
        })

        it('should remove transfer agent role', async () => {
            // Verify transfer agent role exists
            const roleBefore = await roles.getRole(testTransferAgent)
            expect(roleBefore).toBe('transfer_agent')

            // Remove transfer agent role
            await executeTxFunc(roles.removeTransferAgent(testTransferAgent, sender))

            // Verify role is removed
            await expect(roles.getRole(testTransferAgent)).resolves.toBe('none')
        })
    })

    describe('Master Role (Service Owner)', () => {
        it('should check master role for admin', async () => {
            const role = await roles.getRole(sender)
            expect(role).toBe('master')
        })

        it('should transfer service ownership', async () => {
            let newOwnerKP = await createFundedWallet();
            const newOwner = newOwnerKP.toSuiAddress()

            // Transfer ownership from current master to new owner
            await executeTxFunc(roles.setServiceOwner(newOwner, sender))

            // Verify new owner has Master role
            const newRole = await roles.getRole(newOwner)
            expect(newRole).toBe('master')

            // Verify old owner no longer has Master role
            await expect(roles.getRole(sender)).resolves.toBe('none')

            // Transfer back to original owner for other tests
            await executeTxFunc(roles.setServiceOwner(sender, newOwner), newOwnerKP)
        })
    })

    describe('Role Assignment Edge Cases', () => {
        it('should not allow role reassignment without removal', async () => {
            const testWallet = createWallet().toSuiAddress()

            // Assign issuer role
            await executeTxFunc(roles.setIssuer(testWallet, sender))

            // Try to assign transfer agent role without removing issuer first
            // This should fail due to EDirectRoleToRoleChange
            await expect(
                executeTxFunc(roles.setTransferAgent(testWallet, sender))
            ).rejects.toThrow()

            // Clean up
            await executeTxFunc(roles.removeIssuer(testWallet, sender))
        })

        it('should allow role reassignment after removal', async () => {
            const testWallet = createWallet().toSuiAddress()

            // Assign issuer role
            await executeTxFunc(roles.setIssuer(testWallet, sender))
            let role = await roles.getRole(testWallet)
            expect(role).toBe('issuer')

            // Remove issuer role
            await executeTxFunc(roles.removeIssuer(testWallet, sender))

            // Now assign transfer agent role
            await executeTxFunc(roles.setTransferAgent(testWallet, sender))
            role = await roles.getRole(testWallet)
            expect(role).toBe('transfer_agent')

            // Clean up
            await executeTxFunc(roles.removeTransferAgent(testWallet, sender))
        })
    })
})
