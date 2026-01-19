import {CLOCK_ID, deriveObjectId, MoveType, SuiClient} from "../easysui";
import {Config} from "./utils/config";
import {getTokenDetails, TokenDetails} from "./token";
import {Transaction} from "@mysten/sui/transactions";
import {TokenMetadata} from "./domains";
import {bcs} from "@mysten/sui/bcs";

export class DSToken {
    private readonly tokenAddress: string;
    private readonly tokenDetails: TokenDetails;

    constructor(tokenAddress: string) {
        this.tokenAddress = tokenAddress;
        this.tokenDetails = getTokenDetails(tokenAddress);
    }

    private getTarget(func: string) {
        return `${Config.vars.PACKAGE_ID}::ds_token::${func}`
    }

    private buildGetPTB(func: string, args: any[]) {
        return SuiClient.getPTB(
            this.getTarget(func),
            [this.tokenAddress],
            args,
        )
    }

    private buildSetPTB(func: string, args: any[], ptb?: Transaction, argTypes: any[] = []) {
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

    private buildSetBytes(ptb: Transaction, signer: string) {
        return SuiClient.getMoveCallBytesFromPTB(ptb, signer)
    }

    // ==== View Functions ====

    async isPaused(sender: string): Promise<boolean> {
        const ptb = this.buildGetPTB('is_paused', [this.tokenDetails.treasury])
        const result = await SuiClient.devInspectBool(ptb, sender)
        return result ?? false
    }

    async getTotalIssued(treasuryCap?: string): Promise<string> {
        treasuryCap ??= (await this.getCurrency()).treasury_cap_id

        if (!treasuryCap) {
            throw new Error(`Unable to get total issued.`)
        }

        const res = await SuiClient.getObject(treasuryCap)
        const value = (res.data?.content as any)?.fields?.total_supply?.fields?.value

        if (!value) {
            throw new Error(`Unable to find treasury cap ${treasuryCap}.`)
        }

        return value
    }

    async getMetadata(sender: string): Promise<TokenMetadata> {
        const fields = await this.getCurrency()

        return {
            name: fields.name,
            symbol: fields.symbol,
            decimals: fields.decimals,
            description: fields.description,
            iconUri: fields.icon_url,
            totalIssued: await this.getTotalIssued(fields.treasury_cap_id),
            isPaused: await this.isPaused(sender),
        }
    }

    private async getCurrency() {
        const res = await SuiClient.getObject(this.tokenDetails.currency)
        const fields = (res.data?.content as any)?.fields

        if (!fields) {
            throw new Error("Unable to find metadata.")
        }
        return fields;
    }

// ==== Token Management Functions ====

    setMetadataPTB(
        name?: string,
        description?: string,
        iconUrl?: string,
        ptb?: Transaction
    ) {
        ptb ??= new Transaction()
        const args = [
            this.tokenDetails.treasury,
            this.tokenDetails.auth,
            this.tokenDetails.currency,
            name,
            description,
            iconUrl,
            Config.vars.VERSION,
        ]
        const argsTypes = [
            MoveType.object,
            MoveType.object,
            MoveType.object,
            MoveType.string_opt,
            MoveType.string_opt,
            MoveType.string_opt,
            MoveType.object,
        ]
        return this.buildSetPTB('set_metadata', args, ptb, argsTypes)
    }

    async setMetadata(
        signer: string,
        name?: string,
        description?: string,
        iconUrl?: string,
    ) {
        const ptb = this.setMetadataPTB(name, description, iconUrl)
        return this.buildSetBytes(ptb, signer)
    }

    getPASVault(address: string) {
        const key = 'VaultKey'
        const serializedBcs = bcs.struct(key, { address: bcs.Address }).serialize({ address })
        return deriveObjectId(Config.vars.PAS_NAMESPACE, 'vault', key, Config.vars.PAS_PACKAGE_ID, undefined, serializedBcs)
    }

    issuePTB(
        to: string,
        value: bigint,
        valuesLocked: bigint[],
        releaseTimes: number[],
        issuanceTimeMS: number,
        ptb?: Transaction,
    ) {
        ptb ??= new Transaction()
        const pasVault = this.getPASVault(to);
        const args = [
            this.tokenDetails.treasury,
            this.tokenDetails.auth,
            this.tokenDetails.investorInfo,
            this.tokenDetails.complianceConfig,
            this.tokenDetails.pasRule,
            pasVault,
            to,
            value,
            Config.vars.VERSION,
            valuesLocked,
            releaseTimes,
            issuanceTimeMS,
            CLOCK_ID,
        ]
        const argsTypes = [
            MoveType.object,
            MoveType.object,
            MoveType.object,
            MoveType.object,
            MoveType.object,
            MoveType.object,
            MoveType.address,
            MoveType.u64,
            MoveType.object,
            MoveType.vec_u64,
            MoveType.vec_u64,
            MoveType.u64,
            MoveType.object,
        ]
        return this.buildSetPTB('issue_tokens', args, ptb, argsTypes)
    }

    async issue(
        signer: string,
        to: string,
        value: bigint,
        valuesLocked: bigint[],
        releaseTimes: number[],
        issuanceTimeMS: number,
    ) {
        const ptb = this.issuePTB(to, value, valuesLocked, releaseTimes, issuanceTimeMS)
        return this.buildSetBytes(ptb, signer)
    }

    issueNoVaultPTB(
        to: string,
        value: bigint,
        valuesLocked: bigint[],
        releaseTimes: number[],
        issuanceTimeMS: number,
        ptb?: Transaction,
    ) {
        ptb ??= new Transaction()
        const args = [
            this.tokenDetails.treasury,
            this.tokenDetails.auth,
            this.tokenDetails.investorInfo,
            this.tokenDetails.complianceConfig,
            this.tokenDetails.pasRule,
            Config.vars.PAS_NAMESPACE,
            to,
            value,
            Config.vars.VERSION,
            valuesLocked,
            releaseTimes,
            issuanceTimeMS,
            CLOCK_ID,
        ]
        const argsTypes = [
            MoveType.object,
            MoveType.object,
            MoveType.object,
            MoveType.object,
            MoveType.object,
            MoveType.object,
            MoveType.address,
            MoveType.u64,
            MoveType.object,
            MoveType.vec_u64,
            MoveType.vec_u64,
            MoveType.u64,
            MoveType.object,
        ]
        return this.buildSetPTB('issue_tokens_no_vault', args, ptb, argsTypes)
    }

    async issueNoVault(
        signer: string,
        to: string,
        value: bigint,
        valuesLocked: bigint[],
        releaseTimes: number[],
        issuanceTimeMS: number,
    ) {
        const ptb = this.issueNoVaultPTB(to, value, valuesLocked, releaseTimes, issuanceTimeMS)
        return this.buildSetBytes(ptb, signer)
    }

    burnPTB(
        from: string,
        value: bigint,
        reason: string,
        ptb?: Transaction,
    ) {
        ptb ??= new Transaction()
        const pasVault = this.getPASVault(from);
        const args = [
            this.tokenDetails.treasury,
            this.tokenDetails.auth,
            this.tokenDetails.investorInfo,
            this.tokenDetails.pasRule,
            pasVault,
            from,
            value,
            reason,
            Config.vars.VERSION,
        ]
        const argsTypes = [
            MoveType.object,
            MoveType.object,
            MoveType.object,
            MoveType.object,
            MoveType.object,
            MoveType.address,
            MoveType.u64,
            MoveType.string,
            MoveType.object,
        ]
        return this.buildSetPTB('burn', args, ptb, argsTypes)
    }

    async burn(
        signer: string,
        from: string,
        value: bigint,
        reason: string,
    ) {
        const ptb = this.burnPTB(from, value, reason)
        return this.buildSetBytes(ptb, signer)
    }

    seizePTB(
        from: string,
        to: string,
        value: bigint,
        reason: string,
        ptb?: Transaction,
    ) {
        ptb ??= new Transaction()
        const fromPASVault = this.getPASVault(from);
        const toVault = this.getPASVault(to);
        const args = [
            this.tokenDetails.auth,
            this.tokenDetails.investorInfo,
            this.tokenDetails.pasRule,
            fromPASVault,
            from,
            toVault,
            to,
            value,
            reason,
            Config.vars.VERSION,
        ]
        const argsTypes = [
            MoveType.object,
            MoveType.object,
            MoveType.object,
            MoveType.object,
            MoveType.address,
            MoveType.object,
            MoveType.address,
            MoveType.u64,
            MoveType.string,
            MoveType.object,
        ]
        return this.buildSetPTB('seize', args, ptb, argsTypes)
    }

    async seize(
        signer: string,
        from: string,
        to: string,
        value: bigint,
        reason: string,
    ) {
        const ptb = this.seizePTB(from, to, value, reason)
        return this.buildSetBytes(ptb, signer)
    }

    pausePTB(ptb?: Transaction) {
        ptb ??= new Transaction()
        const args = [
            this.tokenDetails.treasury,
            this.tokenDetails.auth,
            Config.vars.VERSION,
        ]
        return this.buildSetPTB('pause', args, ptb)
    }

    async pause(signer: string) {
        const ptb = this.pausePTB()
        return this.buildSetBytes(ptb, signer)
    }

    unpausePTB(ptb?: Transaction) {
        ptb ??= new Transaction()
        const args = [
            this.tokenDetails.treasury,
            this.tokenDetails.auth,
            Config.vars.VERSION,
        ]
        return this.buildSetPTB('unpause', args, ptb)
    }

    async unpause(signer: string) {
        const ptb = this.unpausePTB()
        return this.buildSetBytes(ptb, signer)
    }

    transferPTB(
        from: string,
        to: string,
        amount: bigint,
        ptb?: Transaction,
    ) {
        ptb ??= new Transaction()
        const fromRwaVault = this.getPASVault(from)
        const toRwaVault = this.getPASVault(to)
        const auth = ptb.moveCall({
            target: `${Config.vars.PAS_PACKAGE_ID}::vault::new_auth`,
        })
        const transferRequest = ptb.moveCall({
            target: `${Config.vars.PAS_PACKAGE_ID}::vault::transfer`,
            typeArguments: [this.tokenAddress],
            arguments: [
                ptb.object(fromRwaVault),
                auth,
                ptb.object(toRwaVault),
                ptb.pure.u64(amount),
            ],
        })

        const args = [
            this.tokenDetails.treasury,
            this.tokenDetails.investorInfo,
            this.tokenDetails.complianceConfig,
            this.tokenDetails.pasRule,
            transferRequest,
            Config.vars.VERSION,
            CLOCK_ID,
        ]
        const argsTypes = [
            MoveType.object,
            MoveType.object,
            MoveType.object,
            MoveType.object,
            MoveType.object,
            MoveType.object,
            MoveType.object,
        ]
        return this.buildSetPTB('transfer', args, ptb, argsTypes)
    }

    async transfer(
        signer: string,
        from: string,
        to: string,
        amount: bigint,
    ) {
        const ptb = this.transferPTB(from, to, amount)
        return this.buildSetBytes(ptb, signer)
    }
}
