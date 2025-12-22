import {CLOCK_ID, deriveObjectId, MoveType, SuiClient} from "../easysui";
import {Config} from "./utils/config";
import {getTokenDetails, TokenDetails} from "./token";
import {Transaction} from "@mysten/sui/transactions";
import {TokenMetadata} from "./domains/TokenMetadata";
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

    async getTotalIssued(treasuryCap?: string) {
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

    getRwaVault(address: string) {
        const key = 'RwaVaultKey'
        const serializedBcs = bcs.struct(key, { address: bcs.Address }).serialize({ address })
        return deriveObjectId(Config.vars.RWA_REGISTRY, 'vault', key, Config.vars.RWA_PACKAGE_ID, undefined, serializedBcs)
    }

    issuePTB(
        to: string,
        value: bigint,
        valuesLocked: number[],
        releaseTimes: number[],
        reason: string,
        ptb?: Transaction,
    ) {
        ptb ??= new Transaction()
        let rwaVault = this.getRwaVault(to);
        const args = [
            this.tokenDetails.treasury,
            this.tokenDetails.auth,
            this.tokenDetails.investorInfo,
            this.tokenDetails.complianceConfig,
            this.tokenDetails.rwaRule,
            rwaVault,
            to,
            value,
            Config.vars.VERSION,
            valuesLocked,
            releaseTimes,
            reason,
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
            MoveType.string,
            MoveType.object,
        ]
        return this.buildSetPTB('issue_tokens', args, ptb, argsTypes)
    }

    async issue(
        signer: string,
        to: string,
        value: bigint,
        valuesLocked: number[],
        releaseTimes: number[],
        reason: string,
    ) {
        const ptb = this.issuePTB(to, value, valuesLocked, releaseTimes, reason)
        return this.buildSetBytes(ptb, signer)
    }
}
