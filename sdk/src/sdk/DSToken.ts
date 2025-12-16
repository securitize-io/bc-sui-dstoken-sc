import {CLOCK_ID, deriveObjectId, MoveType, SuiClient} from "../easysui";
import {Config} from "./utils/config";
import {getTokenDetails, TokenDetails} from "./token";
import {Transaction} from "@mysten/sui/transactions";
import {COIN_REGISTRY} from "../easysui/config/config";
import {TokenMetadata} from "./domains/TokenMetadata";

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
}
