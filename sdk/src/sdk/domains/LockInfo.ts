export interface LockRecord {
    value: bigint;
    reasonCode: bigint;
    reasonString: string;
    releaseTimeMs: bigint;
}

export interface InvestorLockInfo {
    investorId: string;
    fullyLocked: boolean;
    liquidateOnly: boolean;
    locks: LockRecord[];
}
