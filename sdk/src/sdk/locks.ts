import {MoveType, SuiClient} from "../easysui";
import {Config} from "./utils/config";
import {getTokenDetails} from "./token";
import {CLOCK_ID} from "../easysui/config/config";
import {InvestorLockInfo, LockRecord} from "./domains";
import {Transaction} from "@mysten/sui/transactions";
import {bcs} from "@mysten/sui/bcs";

export class LockService {
    private readonly tokenAddress: string;
    private readonly tokenDetails: any;

    constructor(tokenAddress: string) {
        this.tokenAddress = tokenAddress;
        this.tokenDetails = getTokenDetails(tokenAddress);
    }

    private getTarget(func: string) {
        return `${Config.vars.PACKAGE_ID}::lock_manager::${func}`
    }

    private buildGetPTB(func: string, args: any[], argTypes: MoveType[]) {
        return SuiClient.getPTB(
            this.getTarget(func),
            [this.tokenAddress],
            [this.tokenDetails.investorInfo, ...args],
            [MoveType.object, ...argTypes],
        )
    }

    private _buildSetPTB(func: string, args: any[], argTypes?: MoveType[], ptb?: Transaction) {
        args = [
            this.tokenDetails.investorInfo,
            ...args,
            this.tokenDetails.auth,
            Config.vars.VERSION
        ]
        return SuiClient.getPTB(
            this.getTarget(func),
            [this.tokenAddress],
            args,
            argTypes,
            undefined,
            false,
            ptb
        )
    }

    private buildSetPTB(signer: string, func: string, args: any[], argTypes?: MoveType[], ptb?: Transaction) {
        const _ptb = this._buildSetPTB(func, args, argTypes, ptb)
        return SuiClient.getMoveCallBytesFromPTB(_ptb, signer)
    }

    // ==== Investor-level Locks ====

    /**
     * Fully locks an investor's account, preventing all transfers.
     */
    lockInvestorPTB(investorId: string, ptb?: Transaction) {
        return this._buildSetPTB('lock_investor', [investorId], [], ptb)
    }

    async lockInvestor(investorId: string, signer: string) {
        const ptb = this.lockInvestorPTB(investorId)
        return SuiClient.getMoveCallBytesFromPTB(ptb, signer)
    }

    /**
     * Unlocks a fully locked investor's account, allowing transfers again.
     */
    unlockInvestorPTB(investorId: string, ptb?: Transaction) {
        return this._buildSetPTB('unlock_investor', [investorId], [], ptb)
    }

    async unlockInvestor(investorId: string, signer: string) {
        const ptb = this.unlockInvestorPTB(investorId)
        return SuiClient.getMoveCallBytesFromPTB(ptb, signer)
    }

    /**
     * Checks if an investor is fully locked.
     */
    async isInvestorLocked(investorId: string, sender: string): Promise<boolean> {
        const ptb = this.buildGetPTB('is_investor_locked', [investorId], [MoveType.string])
        return (await SuiClient.devInspectBool(ptb, sender)) ?? false
    }

    // ==== Liquidate-Only ====

    /**
     * Sets the liquidate-only restriction for an investor.
     * When enabled, the investor can only transfer tokens to the issuer wallet.
     */
    setLiquidateOnlyPTB(investorId: string, enabled: boolean, ptb?: Transaction) {
        return this._buildSetPTB('set_liquidate_only', [investorId, enabled], [], ptb)
    }

    async setLiquidateOnly(investorId: string, enabled: boolean, signer: string) {
        const ptb = this.setLiquidateOnlyPTB(investorId, enabled)
        return SuiClient.getMoveCallBytesFromPTB(ptb, signer)
    }

    /**
     * Checks if an investor has liquidate-only restriction.
     */
    async isLiquidateOnly(investorId: string, sender: string): Promise<boolean> {
        const ptb = this.buildGetPTB('is_liquidate_only', [investorId], [MoveType.string])
        return (await SuiClient.devInspectBool(ptb, sender)) ?? false
    }

    // ==== Lock Information ====

    /**
     * Returns the number of lock records for an investor.
     */
    async lockCountForInvestor(investorId: string, sender: string): Promise<bigint> {
        const ptb = this.buildGetPTB('lock_count', [investorId], [MoveType.string])
        return SuiClient.devInspectU64(ptb, sender)
    }

    /**
     * Gets detailed lock information for an investor by reading on-chain state.
     */
    async lockInfoForInvestor(investorId: string): Promise<InvestorLockInfo> {
        const investor = await SuiClient.getObject(this.tokenDetails.investorInfo)
        const fields = (investor.data?.content as any)?.fields

        const locksTableId = fields.investor_locks.id
        let lockObject: any
        try {
            const { object } = await SuiClient.client.core.getDynamicObjectField({
                parentId: locksTableId,
                name: {
                    type: '0x1::string::String',
                    bcs: bcs.string().serialize(investorId).toBytes(),
                },
                include: { json: true },
            })
            lockObject = object
        } catch {
            // Dynamic field not found — investor has no locks
        }

        if (!lockObject) {
            return {
                investorId,
                fullyLocked: false,
                liquidateOnly: false,
                locks: []
            }
        }

        const lockFields = (lockObject as any).json

        const fullyLocked = lockFields.fully_locked
        const liquidateOnly = lockFields.liquidate_only

        const locks: LockRecord[] = lockFields.locks.map((lock: any) => ({
            value: BigInt(lock.value),
            reasonCode: BigInt(lock.reason_code),
            reasonString: lock.reason_string,
            releaseTimeMs: BigInt(lock.release_time_ms),
        }))

        return {
            investorId,
            fullyLocked,
            liquidateOnly,
            locks,
        }
    }

    // ==== Transferability Helpers ====

    /**
     * Computes the transferable token amount for an investor given their balance.
     * Takes into account full locks and time-based lock records.
     */
    async getTransferableTokensForInvestor(
        investorId: string,
        balance: bigint,
        timestampMs: bigint,
        sender: string
    ): Promise<bigint> {
        const ptb = this.buildGetPTB(
            'compute_transferable',
            [investorId, balance, timestampMs],
            [MoveType.string, MoveType.u64, MoveType.u64]
        )
        return SuiClient.devInspectU64(ptb, sender)
    }

    // ==== Lock Record Management ====

    /**
     * Adds a time-based lock record for a specific token amount.
     * @param investorId - The investor ID
     * @param value - The amount of tokens to lock (must be > 0)
     * @param reasonCode - A numeric code identifying the reason for the lock
     * @param reasonString - A human-readable reason for the lock
     * @param releaseTimeMs - The timestamp in milliseconds when the lock expires (0 for permanent)
     */
    createLockForInvestorPTB(
        investorId: string,
        value: bigint,
        reasonCode: bigint,
        reasonString: string,
        releaseTimeMs: bigint,
        ptb?: Transaction
    ) {
        ptb = ptb ?? new Transaction()
        const args = [
            this.tokenDetails.investorInfo,
            investorId,
            value,
            reasonCode,
            reasonString,
            releaseTimeMs,
            this.tokenDetails.auth,
            Config.vars.VERSION,
            CLOCK_ID
        ]
        const argTypes = [
            MoveType.object,
            MoveType.string,
            MoveType.u64,
            MoveType.u64,
            MoveType.string,
            MoveType.u64,
            MoveType.object,
            MoveType.object,
            MoveType.object,
        ]
        return SuiClient.getPTB(
            this.getTarget('add_lock'),
            [this.tokenAddress],
            args,
            argTypes,
            undefined,
            false,
            ptb
        )
    }

    async createLockForInvestor(
        investorId: string,
        value: bigint,
        reasonCode: bigint,
        reasonString: string,
        releaseTimeMs: bigint,
        signer: string
    ) {
        const ptb = this.createLockForInvestorPTB(
            investorId,
            value,
            reasonCode,
            reasonString,
            releaseTimeMs
        )
        return SuiClient.getMoveCallBytesFromPTB(ptb, signer)
    }

    /**
     * Removes a lock record at the specified index for an investor.
     * @param investorId - The investor ID
     * @param index - The index of the lock to remove
     */
    removeLockRecordForInvestorPTB(investorId: string, index: bigint, ptb?: Transaction) {
        ptb = ptb ?? new Transaction()
        const args = [
            this.tokenDetails.investorInfo,
            investorId,
            index,
            this.tokenDetails.auth,
            Config.vars.VERSION
        ]
        const argTypes = [
            MoveType.object,
            MoveType.string,
            MoveType.u64,
            MoveType.object,
            MoveType.object,
        ]
        return SuiClient.getPTB(
            this.getTarget('remove_lock'),
            [this.tokenAddress],
            args,
            argTypes,
            undefined,
            false,
            ptb
        )
    }

    async removeLockRecordForInvestor(investorId: string, index: bigint, signer: string) {
        const ptb = this.removeLockRecordForInvestorPTB(investorId, index)
        return SuiClient.getMoveCallBytesFromPTB(ptb, signer)
    }
}
