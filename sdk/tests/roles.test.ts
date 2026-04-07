import { ADMIN_KEYPAIR, Roles, createWallet, createFundedWallet, SuiClient } from '../src'
import { deploy } from '../src/sdk/utils/deploy'
import { createTestToken, executeTxFunc } from './test_utils'
import { normalizeSuiAddress } from '@mysten/sui/utils'

const sender = ADMIN_KEYPAIR!.toSuiAddress()

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
            await expect(roles.getRole(testExchange)).resolves.toBe('none')
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
            let newOwnerKP = await createFundedWallet()
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

    describe('updateRole Function', () => {
        it('should update role from issuer to transfer_agent in one transaction', async () => {
            const testWallet = createWallet().toSuiAddress()

            // First assign issuer role
            await executeTxFunc(roles.setIssuer(testWallet, sender))
            let role = await roles.getRole(testWallet)
            expect(role).toBe('issuer')

            // Update from issuer to transfer_agent using updateRole
            await executeTxFunc(roles.updateRole(testWallet, 'transfer_agent', sender))

            // Verify role has been updated
            role = await roles.getRole(testWallet)
            expect(role).toBe('transfer_agent')

            // Clean up
            await executeTxFunc(roles.removeTransferAgent(testWallet, sender))
        })

        it('should update role from transfer_agent to exchange in one transaction', async () => {
            const testWallet = createWallet().toSuiAddress()

            // First assign transfer_agent role
            await executeTxFunc(roles.setTransferAgent(testWallet, sender))
            let role = await roles.getRole(testWallet)
            expect(role).toBe('transfer_agent')

            // Update from transfer_agent to exchange using updateRole
            await executeTxFunc(roles.updateRole(testWallet, 'exchange', sender))

            // Verify role has been updated
            role = await roles.getRole(testWallet)
            expect(role).toBe('exchange')

            // Clean up
            await executeTxFunc(roles.removeExchange(testWallet, sender))
        })

        it('should update role from exchange to issuer in one transaction', async () => {
            const testWallet = createWallet().toSuiAddress()

            // First assign exchange role
            await executeTxFunc(roles.setExchange(testWallet, sender))
            let role = await roles.getRole(testWallet)
            expect(role).toBe('exchange')

            // Update from exchange to issuer using updateRole
            await executeTxFunc(roles.updateRole(testWallet, 'issuer', sender))

            // Verify role has been updated
            role = await roles.getRole(testWallet)
            expect(role).toBe('issuer')

            // Clean up
            await executeTxFunc(roles.removeIssuer(testWallet, sender))
        })

        it('should assign initial role from none to issuer', async () => {
            const testWallet = createWallet().toSuiAddress()

            // Verify wallet has no role initially
            let role = await roles.getRole(testWallet)
            expect(role).toBe('none')

            // Assign issuer role using updateRole
            await executeTxFunc(roles.updateRole(testWallet, 'issuer', sender))

            // Verify role has been assigned
            role = await roles.getRole(testWallet)
            expect(role).toBe('issuer')

            // Clean up
            await executeTxFunc(roles.removeIssuer(testWallet, sender))
        })

        it('should throw error when trying to update to same role', async () => {
            const testWallet = createWallet().toSuiAddress()

            // Assign issuer role
            await executeTxFunc(roles.setIssuer(testWallet, sender))

            // Try to update to the same role
            await expect(roles.updateRole(testWallet, 'issuer', sender)).rejects.toThrow(
                'No direct role-to-role change'
            )

            // Clean up
            await executeTxFunc(roles.removeIssuer(testWallet, sender))
        })

        it('should throw error when trying to change master role', async () => {
            // Try to update master role (should fail)
            await expect(roles.updateRole(sender, 'issuer', sender)).rejects.toThrow(
                'No direct role-to-role change'
            )
        })
    })

    describe('Ability Management', () => {
        it('should add ability to issuer role', async () => {
            // Add SeizeTokens ability to issuer role (issuer doesn't have it by default)
            await executeTxFunc(roles.addRoleAbility('issuer', 'SeizeTokens', sender))
        })

        it('should remove ability from issuer role', async () => {
            // Remove SeizeTokens ability from issuer role
            await executeTxFunc(roles.removeRoleAbility('issuer', 'SeizeTokens', sender))
        })

        it('should fail when adding ability that already exists', async () => {
            // IssueTokens is already assigned to issuer role by default
            await expect(
                executeTxFunc(roles.addRoleAbility('issuer', 'IssueTokens', sender))
            ).rejects.toThrow()
        })

        it('should fail when removing ability that does not exist', async () => {
            // Pauser was never added to issuer role
            await expect(
                executeTxFunc(roles.removeRoleAbility('issuer', 'Pauser', sender))
            ).rejects.toThrow()
        })

        it('should fail when non-master tries to add ability', async () => {
            const nonMaster = createWallet().toSuiAddress()

            // Assign issuer role to nonMaster
            await executeTxFunc(roles.setIssuer(nonMaster, sender))

            // Issuer tries to add ability - should fail (only Master has SetAbilities)
            await expect(
                executeTxFunc(roles.addRoleAbility('exchange', 'SeizeTokens', nonMaster))
            ).rejects.toThrow()

            // Clean up
            await executeTxFunc(roles.removeIssuer(nonMaster, sender))
        })

        it('should fail when non-master tries to remove ability', async () => {
            const nonMaster = createWallet().toSuiAddress()

            // Assign issuer role to nonMaster
            await executeTxFunc(roles.setIssuer(nonMaster, sender))

            // Issuer tries to remove ability - should fail
            await expect(
                executeTxFunc(roles.removeRoleAbility('issuer', 'IssueTokens', nonMaster))
            ).rejects.toThrow()

            // Clean up
            await executeTxFunc(roles.removeIssuer(nonMaster, sender))
        })

        it('should not allow removing SetAbilities from master role', async () => {
            // Try to remove SetAbilities from Master - should fail (protected ability)
            await expect(
                executeTxFunc(roles.removeRoleAbility('master', 'SetAbilities', sender))
            ).rejects.toThrow()
        })

        it('should add and remove multiple abilities', async () => {
            // Add multiple abilities to transfer_agent (IssueTokens and MetadataUpdate don't exist by default on transfer_agent)
            await executeTxFunc(roles.addRoleAbility('transfer_agent', 'IssueTokens', sender))
            await executeTxFunc(roles.addRoleAbility('transfer_agent', 'MetadataUpdate', sender))

            // Remove them
            await executeTxFunc(roles.removeRoleAbility('transfer_agent', 'IssueTokens', sender))
            await executeTxFunc(roles.removeRoleAbility('transfer_agent', 'MetadataUpdate', sender))
        })

        it('should handle multiple role updates sequentially', async () => {
            const testWallet = createWallet().toSuiAddress()

            // Start with issuer
            await executeTxFunc(roles.updateRole(testWallet, 'issuer', sender))
            let role = await roles.getRole(testWallet)
            expect(role).toBe('issuer')

            // Update to transfer_agent
            await executeTxFunc(roles.updateRole(testWallet, 'transfer_agent', sender))
            role = await roles.getRole(testWallet)
            expect(role).toBe('transfer_agent')

            // Update to exchange
            await executeTxFunc(roles.updateRole(testWallet, 'exchange', sender))
            role = await roles.getRole(testWallet)
            expect(role).toBe('exchange')

            // Update back to issuer
            await executeTxFunc(roles.updateRole(testWallet, 'issuer', sender))
            role = await roles.getRole(testWallet)
            expect(role).toBe('issuer')

            // Clean up
            await executeTxFunc(roles.removeIssuer(testWallet, sender))
        })
    })

    describe('Service Owner with Upgrade Cap', () => {
        it('should transfer service ownership with upgrade cap', async () => {
            const newOwnerKP = await createFundedWallet()
            const newOwner = newOwnerKP.toSuiAddress()

            const tokenPackageId = normalizeSuiAddress(tokenAddress.split('::')[0])

            // Transfer ownership — setServiceOwner finds and transfers UpgradeCap automatically
            await executeTxFunc(roles.setServiceOwner(newOwner, sender))

            // Verify new owner has Master role
            await expect(roles.getRole(newOwner)).resolves.toBe('master')

            // Verify old owner no longer has Master role
            await expect(roles.getRole(sender)).resolves.toBe('none')

            // Verify new owner owns the token's UpgradeCap
            const newOwnerCaps = await SuiClient.client.listOwnedObjects({
                owner: newOwner,
                type: '0x2::package::UpgradeCap',
                include: { json: true },
            })
            const transferredCap = newOwnerCaps.objects.find((o: any) => {
                return normalizeSuiAddress(o.json?.package) === tokenPackageId
            })
            expect(transferredCap).toBeDefined()

            // Transfer ownership back for other tests
            await executeTxFunc(roles.setServiceOwner(sender, newOwner), newOwnerKP)
        })
    })
})
