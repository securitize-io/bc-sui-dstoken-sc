import { ADMIN_KEYPAIR, createFundedWallet, Investors, LockService } from '../src'
import { deploy } from '../src/sdk/utils/deploy'
import { createTestToken, executeTxFunc, registerInvestor } from './test_utils'
import { Keypair } from '@mysten/sui/cryptography'

const sender = ADMIN_KEYPAIR!.toSuiAddress()

describe('LockService', () => {
    let tokenAddress: string
    let lockService: LockService
    let investor1: Keypair
    let investor2: Keypair
    let investor3: Keypair

    const testInvestor1 = 'LockTestInvestor1'
    const testInvestor2 = 'LockTestInvestor2'
    const testInvestor3 = 'LockTestInvestor3'

    beforeAll(async () => {
        await deploy()
        tokenAddress = await createTestToken()
        lockService = new LockService(tokenAddress)

        investor1 = await createFundedWallet()
        investor2 = await createFundedWallet()
        investor3 = await createFundedWallet()

        // Register test investors
        await registerInvestor(tokenAddress, testInvestor1, [investor1.toSuiAddress()])
        await registerInvestor(tokenAddress, testInvestor2, [investor2.toSuiAddress()])
        await registerInvestor(tokenAddress, testInvestor3, [investor3.toSuiAddress()])
    })

    describe('Investor Full Lock', () => {
        it('should check investor is not locked initially', async () => {
            await expect(lockService.isInvestorLocked(testInvestor1, sender)).resolves.toBe(false)
        })

        it('should lock investor', async () => {
            await executeTxFunc(lockService.lockInvestor(testInvestor1, sender))
            await expect(lockService.isInvestorLocked(testInvestor1, sender)).resolves.toBe(true)
        })

        it('should fail to lock already locked investor', async () => {
            // Investor is already locked from previous test
            await expect(lockService.isInvestorLocked(testInvestor1, sender)).resolves.toBe(true)

            // Try to lock again (should fail - EAlreadyLocked)
            await expect(
                executeTxFunc(lockService.lockInvestor(testInvestor1, sender))
            ).rejects.toThrow()
        })

        it('should unlock investor', async () => {
            // Investor is locked
            await expect(lockService.isInvestorLocked(testInvestor1, sender)).resolves.toBe(true)

            // Unlock
            await executeTxFunc(lockService.unlockInvestor(testInvestor1, sender))
            await expect(lockService.isInvestorLocked(testInvestor1, sender)).resolves.toBe(false)
        })

        it('should fail to unlock investor that is not locked', async () => {
            // Investor is not locked
            await expect(lockService.isInvestorLocked(testInvestor1, sender)).resolves.toBe(false)

            // Try to unlock (should fail - ENotLocked)
            await expect(
                executeTxFunc(lockService.unlockInvestor(testInvestor1, sender))
            ).rejects.toThrow()
        })

        it('should allow re-locking after unlock', async () => {
            // Investor is not locked
            await expect(lockService.isInvestorLocked(testInvestor1, sender)).resolves.toBe(false)

            // Lock again
            await executeTxFunc(lockService.lockInvestor(testInvestor1, sender))
            await expect(lockService.isInvestorLocked(testInvestor1, sender)).resolves.toBe(true)

            // Unlock for cleanup
            await executeTxFunc(lockService.unlockInvestor(testInvestor1, sender))
        })
    })

    describe('Liquidate-Only Restriction', () => {
        it('should check investor is not liquidate-only initially', async () => {
            await expect(lockService.isLiquidateOnly(testInvestor2, sender)).resolves.toBe(false)
        })

        it('should set liquidate-only to true', async () => {
            await executeTxFunc(lockService.setLiquidateOnly(testInvestor2, true, sender))
            await expect(lockService.isLiquidateOnly(testInvestor2, sender)).resolves.toBe(true)
        })

        it('should set liquidate-only to false', async () => {
            await expect(lockService.isLiquidateOnly(testInvestor2, sender)).resolves.toBe(true)

            await executeTxFunc(lockService.setLiquidateOnly(testInvestor2, false, sender))
            await expect(lockService.isLiquidateOnly(testInvestor2, sender)).resolves.toBe(false)
        })

        it('should allow setting liquidate-only multiple times', async () => {
            // Set to true
            await executeTxFunc(lockService.setLiquidateOnly(testInvestor2, true, sender))
            await expect(lockService.isLiquidateOnly(testInvestor2, sender)).resolves.toBe(true)

            // Set to true again (should work)
            await executeTxFunc(lockService.setLiquidateOnly(testInvestor2, true, sender))
            await expect(lockService.isLiquidateOnly(testInvestor2, sender)).resolves.toBe(true)

            // Set to false
            await executeTxFunc(lockService.setLiquidateOnly(testInvestor2, false, sender))
            await expect(lockService.isLiquidateOnly(testInvestor2, sender)).resolves.toBe(false)
        })
    })

    describe('Lock Records', () => {
        it('should have zero lock count initially', async () => {
            await expect(lockService.lockCountForInvestor(testInvestor3, sender)).resolves.toBe(0n)
        })

        it('should add a lock record with permanent lock (releaseTime = 0)', async () => {
            const value = 1000n
            const reasonCode = 1n
            const reasonString = 'Compliance hold'
            const releaseTimeMs = 0n // Permanent lock

            await executeTxFunc(
                lockService.createLockForInvestor(
                    testInvestor3,
                    value,
                    reasonCode,
                    reasonString,
                    releaseTimeMs,
                    sender
                )
            )

            await expect(lockService.lockCountForInvestor(testInvestor3, sender)).resolves.toBe(1n)

            // Verify lock info
            const lockInfo = await lockService.lockInfoForInvestor(testInvestor3)
            expect(lockInfo.investorId).toBe(testInvestor3)
            expect(lockInfo.fullyLocked).toBe(false)
            expect(lockInfo.liquidateOnly).toBe(false)
            expect(lockInfo.locks.length).toBe(1)
            expect(lockInfo.locks[0].value).toBe(value)
            expect(lockInfo.locks[0].reasonCode).toBe(reasonCode)
            expect(lockInfo.locks[0].reasonString).toBe(reasonString)
            expect(lockInfo.locks[0].releaseTimeMs).toBe(releaseTimeMs)
        })

        it('should add a lock record with future release time', async () => {
            const value = 2000n
            const reasonCode = 2n
            const reasonString = 'Time-based lock'
            const releaseTimeMs = BigInt(Date.now() + 365 * 24 * 60 * 60 * 1000) // 1 year from now

            await executeTxFunc(
                lockService.createLockForInvestor(
                    testInvestor3,
                    value,
                    reasonCode,
                    reasonString,
                    releaseTimeMs,
                    sender
                )
            )

            await expect(lockService.lockCountForInvestor(testInvestor3, sender)).resolves.toBe(2n)

            // Verify lock info
            const lockInfo = await lockService.lockInfoForInvestor(testInvestor3)
            expect(lockInfo.locks.length).toBe(2)
            expect(lockInfo.locks[1].value).toBe(value)
            expect(lockInfo.locks[1].reasonCode).toBe(reasonCode)
            expect(lockInfo.locks[1].reasonString).toBe(reasonString)
            expect(lockInfo.locks[1].releaseTimeMs).toBe(releaseTimeMs)
        })

        it('should fail to add lock with zero value', async () => {
            const value = 0n // Invalid - must be > 0
            const reasonCode = 3n
            const reasonString = 'Invalid lock'
            const releaseTimeMs = 0n

            await expect(
                executeTxFunc(
                    lockService.createLockForInvestor(
                        testInvestor3,
                        value,
                        reasonCode,
                        reasonString,
                        releaseTimeMs,
                        sender
                    )
                )
            ).rejects.toThrow()

            // Lock count should remain the same
            await expect(lockService.lockCountForInvestor(testInvestor3, sender)).resolves.toBe(2n)
        })

        it('should fail to add lock with past release time', async () => {
            const value = 500n
            const reasonCode = 4n
            const reasonString = 'Past lock'
            const releaseTimeMs = BigInt(Date.now() - 1000) // 1 second in the past

            await expect(
                executeTxFunc(
                    lockService.createLockForInvestor(
                        testInvestor3,
                        value,
                        reasonCode,
                        reasonString,
                        releaseTimeMs,
                        sender
                    )
                )
            ).rejects.toThrow()

            // Lock count should remain the same
            await expect(lockService.lockCountForInvestor(testInvestor3, sender)).resolves.toBe(2n)
        })

        it('should remove a lock record by index', async () => {
            // We have 2 locks, remove the first one (index 0)
            await expect(lockService.lockCountForInvestor(testInvestor3, sender)).resolves.toBe(2n)

            await executeTxFunc(
                lockService.removeLockRecordForInvestor(testInvestor3, 0n, sender)
            )

            await expect(lockService.lockCountForInvestor(testInvestor3, sender)).resolves.toBe(1n)

            // The remaining lock should be the second one (which was at index 1, now at index 0)
            const lockInfo = await lockService.lockInfoForInvestor(testInvestor3)
            expect(lockInfo.locks.length).toBe(1)
            expect(lockInfo.locks[0].reasonCode).toBe(2n) // The time-based lock
        })

        it('should fail to remove lock at invalid index', async () => {
            // We have 1 lock at index 0, try to remove at index 1 (out of range)
            await expect(lockService.lockCountForInvestor(testInvestor3, sender)).resolves.toBe(1n)

            await expect(
                executeTxFunc(
                    lockService.removeLockRecordForInvestor(testInvestor3, 1n, sender)
                )
            ).rejects.toThrow()

            // Lock count should remain the same
            await expect(lockService.lockCountForInvestor(testInvestor3, sender)).resolves.toBe(1n)
        })

        it('should remove the last remaining lock', async () => {
            await expect(lockService.lockCountForInvestor(testInvestor3, sender)).resolves.toBe(1n)

            await executeTxFunc(
                lockService.removeLockRecordForInvestor(testInvestor3, 0n, sender)
            )

            await expect(lockService.lockCountForInvestor(testInvestor3, sender)).resolves.toBe(0n)

            const lockInfo = await lockService.lockInfoForInvestor(testInvestor3)
            expect(lockInfo.locks.length).toBe(0)
        })
    })

    describe('Transferable Tokens Calculation', () => {
        const transferTestInvestor = testInvestor1

        it('should return full balance when no locks', async () => {
            const balance = 10000n
            const timestampMs = BigInt(Date.now())

            const transferable = await lockService.getTransferableTokensForInvestor(
                transferTestInvestor,
                balance,
                timestampMs,
                sender
            )

            expect(transferable).toBe(balance)
        })

        it('should return 0 when fully locked', async () => {
            // Lock the investor
            await executeTxFunc(lockService.lockInvestor(transferTestInvestor, sender))

            const balance = 10000n
            const timestampMs = BigInt(Date.now())

            const transferable = await lockService.getTransferableTokensForInvestor(
                transferTestInvestor,
                balance,
                timestampMs,
                sender
            )

            expect(transferable).toBe(0n)

            // Unlock for further tests
            await executeTxFunc(lockService.unlockInvestor(transferTestInvestor, sender))
        })

        it('should subtract locked amount from balance', async () => {
            const lockValue = 3000n
            const balance = 10000n
            const releaseTimeMs = 0n // Permanent lock

            // Add a lock
            await executeTxFunc(
                lockService.createLockForInvestor(
                    transferTestInvestor,
                    lockValue,
                    1n,
                    'Test lock',
                    releaseTimeMs,
                    sender
                )
            )

            const timestampMs = BigInt(Date.now())

            const transferable = await lockService.getTransferableTokensForInvestor(
                transferTestInvestor,
                balance,
                timestampMs,
                sender
            )

            expect(transferable).toBe(balance - lockValue)

            // Clean up
            await executeTxFunc(
                lockService.removeLockRecordForInvestor(transferTestInvestor, 0n, sender)
            )
        })

        it('should return 0 when locked amount exceeds balance', async () => {
            const lockValue = 15000n // More than balance
            const balance = 10000n
            const releaseTimeMs = 0n

            // Add a lock
            await executeTxFunc(
                lockService.createLockForInvestor(
                    transferTestInvestor,
                    lockValue,
                    1n,
                    'Large lock',
                    releaseTimeMs,
                    sender
                )
            )

            const timestampMs = BigInt(Date.now())

            const transferable = await lockService.getTransferableTokensForInvestor(
                transferTestInvestor,
                balance,
                timestampMs,
                sender
            )

            expect(transferable).toBe(0n)

            // Clean up
            await executeTxFunc(
                lockService.removeLockRecordForInvestor(transferTestInvestor, 0n, sender)
            )
        })

        it('should not count expired locks in locked sum', async () => {
            const lockValue = 5000n
            const balance = 10000n
            // Use a future release time
            const futureReleaseTimeMs = BigInt(Date.now() + 60 * 60 * 1000) // 1 hour from now

            // Add a time-based lock
            await executeTxFunc(
                lockService.createLockForInvestor(
                    transferTestInvestor,
                    lockValue,
                    1n,
                    'Time-based lock',
                    futureReleaseTimeMs,
                    sender
                )
            )

            // Query with current timestamp (lock should be active)
            const currentTimestampMs = BigInt(Date.now())
            const transferableNow = await lockService.getTransferableTokensForInvestor(
                transferTestInvestor,
                balance,
                currentTimestampMs,
                sender
            )
            expect(transferableNow).toBe(balance - lockValue)

            // Query with future timestamp (lock should be expired)
            const farFutureTimestampMs = futureReleaseTimeMs + 1000n
            const transferableFuture = await lockService.getTransferableTokensForInvestor(
                transferTestInvestor,
                balance,
                farFutureTimestampMs,
                sender
            )
            expect(transferableFuture).toBe(balance)

            // Clean up
            await executeTxFunc(
                lockService.removeLockRecordForInvestor(transferTestInvestor, 0n, sender)
            )
        })
    })

    describe('Lock Info Retrieval', () => {
        const infoTestInvestor = testInvestor2

        it('should return default lock info for investor with no locks', async () => {
            const lockInfo = await lockService.lockInfoForInvestor(infoTestInvestor)

            expect(lockInfo.investorId).toBe(infoTestInvestor)
            expect(lockInfo.fullyLocked).toBe(false)
            expect(lockInfo.liquidateOnly).toBe(false)
            expect(lockInfo.locks).toEqual([])
        })

        it('should reflect full lock status in lock info', async () => {
            await executeTxFunc(lockService.lockInvestor(infoTestInvestor, sender))

            const lockInfo = await lockService.lockInfoForInvestor(infoTestInvestor)
            expect(lockInfo.fullyLocked).toBe(true)
            expect(lockInfo.liquidateOnly).toBe(false)

            await executeTxFunc(lockService.unlockInvestor(infoTestInvestor, sender))
        })

        it('should reflect liquidate-only status in lock info', async () => {
            await executeTxFunc(lockService.setLiquidateOnly(infoTestInvestor, true, sender))

            const lockInfo = await lockService.lockInfoForInvestor(infoTestInvestor)
            expect(lockInfo.fullyLocked).toBe(false)
            expect(lockInfo.liquidateOnly).toBe(true)

            await executeTxFunc(lockService.setLiquidateOnly(infoTestInvestor, false, sender))
        })

        it('should include all lock records in lock info', async () => {
            // Add multiple locks
            await executeTxFunc(
                lockService.createLockForInvestor(
                    infoTestInvestor,
                    1000n,
                    1n,
                    'First lock',
                    0n,
                    sender
                )
            )
            await executeTxFunc(
                lockService.createLockForInvestor(
                    infoTestInvestor,
                    2000n,
                    2n,
                    'Second lock',
                    0n,
                    sender
                )
            )
            await executeTxFunc(
                lockService.createLockForInvestor(
                    infoTestInvestor,
                    3000n,
                    3n,
                    'Third lock',
                    0n,
                    sender
                )
            )

            const lockInfo = await lockService.lockInfoForInvestor(infoTestInvestor)
            expect(lockInfo.locks.length).toBe(3)

            // Verify each lock
            expect(lockInfo.locks[0]).toEqual({
                value: 1000n,
                reasonCode: 1n,
                reasonString: 'First lock',
                releaseTimeMs: 0n,
            })
            expect(lockInfo.locks[1]).toEqual({
                value: 2000n,
                reasonCode: 2n,
                reasonString: 'Second lock',
                releaseTimeMs: 0n,
            })
            expect(lockInfo.locks[2]).toEqual({
                value: 3000n,
                reasonCode: 3n,
                reasonString: 'Third lock',
                releaseTimeMs: 0n,
            })

            // Clean up
            await executeTxFunc(lockService.removeLockRecordForInvestor(infoTestInvestor, 0n, sender))
            await executeTxFunc(lockService.removeLockRecordForInvestor(infoTestInvestor, 0n, sender))
            await executeTxFunc(lockService.removeLockRecordForInvestor(infoTestInvestor, 0n, sender))
        })
    })

    describe('Combined Lock States', () => {
        const combinedTestInvestor = testInvestor3

        it('should handle investor with full lock and lock records', async () => {
            // Add a lock record
            await executeTxFunc(
                lockService.createLockForInvestor(
                    combinedTestInvestor,
                    5000n,
                    1n,
                    'Record lock',
                    0n,
                    sender
                )
            )

            // Also fully lock
            await executeTxFunc(lockService.lockInvestor(combinedTestInvestor, sender))

            const lockInfo = await lockService.lockInfoForInvestor(combinedTestInvestor)
            expect(lockInfo.fullyLocked).toBe(true)
            expect(lockInfo.locks.length).toBe(1)

            // Transferable should be 0 because fully locked
            const transferable = await lockService.getTransferableTokensForInvestor(
                combinedTestInvestor,
                10000n,
                BigInt(Date.now()),
                sender
            )
            expect(transferable).toBe(0n)

            // Unlock
            await executeTxFunc(lockService.unlockInvestor(combinedTestInvestor, sender))

            // Now transferable should account for the lock record
            const transferableAfterUnlock = await lockService.getTransferableTokensForInvestor(
                combinedTestInvestor,
                10000n,
                BigInt(Date.now()),
                sender
            )
            expect(transferableAfterUnlock).toBe(5000n)

            // Clean up
            await executeTxFunc(lockService.removeLockRecordForInvestor(combinedTestInvestor, 0n, sender))
        })

        it('should handle investor with liquidate-only and lock records', async () => {
            // Add a lock record
            await executeTxFunc(
                lockService.createLockForInvestor(
                    combinedTestInvestor,
                    3000n,
                    1n,
                    'Combined lock',
                    0n,
                    sender
                )
            )

            // Also set liquidate-only
            await executeTxFunc(lockService.setLiquidateOnly(combinedTestInvestor, true, sender))

            const lockInfo = await lockService.lockInfoForInvestor(combinedTestInvestor)
            expect(lockInfo.liquidateOnly).toBe(true)
            expect(lockInfo.fullyLocked).toBe(false)
            expect(lockInfo.locks.length).toBe(1)

            // Clean up
            await executeTxFunc(lockService.setLiquidateOnly(combinedTestInvestor, false, sender))
            await executeTxFunc(lockService.removeLockRecordForInvestor(combinedTestInvestor, 0n, sender))
        })
    })

    describe('Multiple Lock Records', () => {
        const multiLockInvestor = testInvestor1

        it('should add multiple lock records', async () => {
            // Add 5 lock records
            for (let i = 1; i <= 5; i++) {
                await executeTxFunc(
                    lockService.createLockForInvestor(
                        multiLockInvestor,
                        BigInt(i * 1000),
                        BigInt(i),
                        `Lock ${i}`,
                        0n,
                        sender
                    )
                )
            }

            await expect(lockService.lockCountForInvestor(multiLockInvestor, sender)).resolves.toBe(5n)

            const lockInfo = await lockService.lockInfoForInvestor(multiLockInvestor)
            expect(lockInfo.locks.length).toBe(5)

            // Verify total locked amount
            const totalLocked = lockInfo.locks.reduce((sum, lock) => sum + lock.value, 0n)
            expect(totalLocked).toBe(15000n) // 1000 + 2000 + 3000 + 4000 + 5000
        })

        it('should calculate correct transferable with multiple locks', async () => {
            const balance = 20000n
            const timestampMs = BigInt(Date.now())

            const transferable = await lockService.getTransferableTokensForInvestor(
                multiLockInvestor,
                balance,
                timestampMs,
                sender
            )

            // Total locked is 15000, so transferable should be 20000 - 15000 = 5000
            expect(transferable).toBe(5000n)
        })

        it('should remove locks using swap-remove behavior', async () => {
            // Remove lock at index 1 (which was "Lock 2" with value 2000)
            await executeTxFunc(
                lockService.removeLockRecordForInvestor(multiLockInvestor, 1n, sender)
            )

            await expect(lockService.lockCountForInvestor(multiLockInvestor, sender)).resolves.toBe(4n)

            // The last element (Lock 5) should now be at index 1 due to swap-remove
            const lockInfo = await lockService.lockInfoForInvestor(multiLockInvestor)
            expect(lockInfo.locks.length).toBe(4)
            expect(lockInfo.locks[1].reasonString).toBe('Lock 5')
            expect(lockInfo.locks[1].value).toBe(5000n)
        })

        it('should clean up all remaining locks', async () => {
            // Remove all remaining locks
            while ((await lockService.lockCountForInvestor(multiLockInvestor, sender)) > 0n) {
                await executeTxFunc(
                    lockService.removeLockRecordForInvestor(multiLockInvestor, 0n, sender)
                )
            }

            await expect(lockService.lockCountForInvestor(multiLockInvestor, sender)).resolves.toBe(0n)
        })
    })
})
