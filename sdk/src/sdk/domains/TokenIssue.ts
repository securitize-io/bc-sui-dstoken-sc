export interface TokenIssue {
    to: string
    value: bigint
}

export interface BulkTokenIssue {
    identity: string
    issuanceTime: number
    wallets: TokenIssue[]
}

export interface BulkTokenBurn {
    identity: string
    wallets: TokenIssue[]
}