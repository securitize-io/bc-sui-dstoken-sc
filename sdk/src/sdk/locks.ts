import {SuiClient} from "../easysui";
import {Config} from "./utils/config";
import {getTokenDetails, TokenDetails} from "./token";
import {InvestorLockInfo, LockRecord} from "./domains";
import {Transaction} from "@mysten/sui/transactions";
import {bcs} from "@mysten/sui/bcs";
import * as lockManager from "../generated/securitize/lock_manager";

export class LockService {
    private readonly tokenAddress: string;
    private readonly tokenDetails: TokenDetails;

    constructor(tokenAddress: string) {
        this.tokenAddress = tokenAddress;
        this.tokenDetails = getTokenDetails(tokenAddress);
    }

    // ==== View Functions ====

    /** Returns whether an investor is fully locked (all transfers blocked). */
    async isInvestorLocked(investorId: string, sender: string): Promise<boolean> {
        return (await SuiClient.devInspectBool(this.buildView(lockManager.isInvestorLocked, { investor: investorId }), sender)) ?? false
    }

    async isLiquidateOnly(investorId: string, sender: string): Promise<boolean> {
        return (await SuiClient.devInspectBool(this.buildView(lockManager.isLiquidateOnly, { investor: investorId }), sender)) ?? false
    }

    async lockCountForInvestor(investorId: string, sender: string): Promise<bigint> {
        return SuiClient.devInspectU64(this.buildView(lockManager.lockCount, { investor: investorId }), sender)
    }

    /** Returns full lock state for an investor: fully locked, liquidate-only, and all lock records. */
    async lockInfoForInvestor(investorId: string): Promise<InvestorLockInfo> {
        const investor = await SuiClient.getObject(this.tokenDetails.investorInfo)
        const fields = (investor.data?.content as any)?.fields

        const locksTableId = fields.investor_locks.id
        let lockFields: any
        try {
            lockFields = await SuiClient.getDynamicFieldValue(
                locksTableId,
                '0x1::string::String',
                bcs.string().serialize(investorId).toBytes(),
            )
        } catch (e: any) {
            // Dynamic field not found — investor has no locks
            const msg = e?.message || ''
            if (!msg.includes('not found') && !msg.includes('not%20found')) {
                throw e
            }
        }

        if (!lockFields) {
            return {
                investorId,
                fullyLocked: false,
                liquidateOnly: false,
                locks: []
            }
        }

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

    async getTransferableTokensForInvestor(
        investorId: string,
        balance: bigint,
        timestampMs: bigint,
        sender: string
    ): Promise<bigint> {
        return SuiClient.devInspectU64(this.buildView(lockManager.computeTransferable, { investor: investorId, balance, timestampMs }), sender)
    }

    // ==== Investor Full Lock ====

    lockInvestorPTB(investorId: string, ptb?: Transaction) {
        return this.buildMutation(lockManager.lockInvestor, { investor: investorId }, ptb)
    }

    /** Fully locks an investor, preventing all transfers. */
    async lockInvestor(investorId: string, signer: string) {
        return SuiClient.getMoveCallBytesFromPTB(this.lockInvestorPTB(investorId), signer)
    }

    unlockInvestorPTB(investorId: string, ptb?: Transaction) {
        return this.buildMutation(lockManager.unlockInvestor, { investor: investorId }, ptb)
    }

    /** Unlocks a fully locked investor, allowing transfers again. */
    async unlockInvestor(investorId: string, signer: string) {
        return SuiClient.getMoveCallBytesFromPTB(this.unlockInvestorPTB(investorId), signer)
    }

    // ==== Liquidate-Only ====

    setLiquidateOnlyPTB(investorId: string, enabled: boolean, ptb?: Transaction) {
        return this.buildMutation(lockManager.setLiquidateOnly, { investor: investorId, enabled }, ptb)
    }

    async setLiquidateOnly(investorId: string, enabled: boolean, signer: string) {
        return SuiClient.getMoveCallBytesFromPTB(this.setLiquidateOnlyPTB(investorId, enabled), signer)
    }

    // ==== Lock Record Management ====

    createLockForInvestorPTB(
        investorId: string,
        value: bigint,
        reasonCode: bigint,
        reasonString: string,
        releaseTimeMs: bigint,
        ptb?: Transaction
    ) {
        return this.buildMutation(lockManager.addLock, {
            investor: investorId,
            value,
            reasonCode,
            reasonString,
            releaseTimeMs,
        }, ptb)
    }

    /** Creates a time-based lock record. Use releaseTimeMs=0 for a permanent lock. */
    async createLockForInvestor(
        investorId: string,
        value: bigint,
        reasonCode: bigint,
        reasonString: string,
        releaseTimeMs: bigint,
        signer: string
    ) {
        return SuiClient.getMoveCallBytesFromPTB(
            this.createLockForInvestorPTB(investorId, value, reasonCode, reasonString, releaseTimeMs),
            signer
        )
    }

    removeLockRecordForInvestorPTB(investorId: string, index: bigint, ptb?: Transaction) {
        return this.buildMutation(lockManager.removeLock, { investor: investorId, index }, ptb)
    }

    async removeLockRecordForInvestor(investorId: string, index: bigint, signer: string) {
        return SuiClient.getMoveCallBytesFromPTB(this.removeLockRecordForInvestorPTB(investorId, index), signer)
    }

    // ==== Private Helpers ====

    private get pkg() { return Config.vars.PACKAGE_ID }
    private get typeArgs(): [string] { return [this.tokenAddress] }

    private buildView(fn: Function, extraArgs: Record<string, any> = {}): Transaction {
        const ptb = new Transaction()
        fn({ package: this.pkg, arguments: { registry: this.tokenDetails.investorInfo, ...extraArgs }, typeArguments: this.typeArgs })(ptb)
        return ptb
    }

    private buildMutation(fn: Function, extraArgs: Record<string, any>, ptb?: Transaction): Transaction {
        ptb ??= new Transaction()
        fn({ package: this.pkg, arguments: { registry: this.tokenDetails.investorInfo, ...extraArgs, auth: this.tokenDetails.auth, version: Config.vars.VERSION }, typeArguments: this.typeArgs })(ptb)
        return ptb
    }
}
