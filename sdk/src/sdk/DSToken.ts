import { deriveObjectId, SuiClient } from '../easysui'
import { Config } from './utils/config'
import { getTokenDetails, TokenDetails } from './token'
import { Transaction } from '@mysten/sui/transactions'
import { TokenMetadata, PTBDetails, newPTBDetails } from './domains'
import { bcs } from '@mysten/sui/bcs'
import * as dsToken from '../generated/securitize/ds_token'

export class DSToken {
    private readonly tokenAddress: string
    private readonly tokenDetails: TokenDetails

    constructor(tokenAddress: string) {
        this.tokenAddress = tokenAddress
        this.tokenDetails = getTokenDetails(tokenAddress)
    }

    // ==== View Functions ====

    /** Returns whether the token is currently paused. */
    async isPaused(sender: string): Promise<boolean> {
        const ptb = new Transaction()
        dsToken.isPaused({
            package: this.pkg,
            arguments: { treasury: this.tokenDetails.treasury },
            typeArguments: this.typeArgs,
        })(ptb)
        const result = await SuiClient.devInspectBool(ptb, sender)
        return result ?? false
    }

    /** Returns the total supply of the token from the TreasuryCap. */
    async getTotalIssued(treasuryCap?: string): Promise<string> {
        treasuryCap ??= (await this.getCurrency()).treasury_cap_id

        if (!treasuryCap) {
            throw new Error(`Unable to get total issued.`)
        }

        const res = await SuiClient.getObject(treasuryCap)
        const value = (res.data?.content as any)?.fields?.total_supply?.value

        if (!value) {
            throw new Error(`Unable to find treasury cap ${treasuryCap}.`)
        }

        return value
    }

    /** Returns token metadata including name, symbol, decimals, description, total supply, and pause state. */
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

    // ==== Token Metadata ====

    setMetadataPTB(name?: string, description?: string, iconUrl?: string, ptb?: Transaction) {
        ptb ??= new Transaction()
        dsToken.setMetadata({
            package: this.pkg,
            arguments: {
                treasury: this.tokenDetails.treasury,
                auth: this.tokenDetails.auth,
                currency: this.tokenDetails.currency,
                name: name ?? null,
                description: description ?? null,
                iconUrl: iconUrl ?? null,
                version: Config.vars.VERSION,
            },
            typeArguments: this.typeArgs,
        })(ptb)
        return ptb
    }

    /** Updates token metadata (name, description, icon URL). Pass undefined to leave a field unchanged. */
    async setMetadata(signer: string, name?: string, description?: string, iconUrl?: string) {
        return this.buildSetBytes(this.setMetadataPTB(name, description, iconUrl), signer)
    }

    // ==== Pause / Unpause ====

    pausePTB(ptb?: Transaction) {
        ptb ??= new Transaction()
        dsToken.pause({
            package: this.pkg,
            arguments: { treasury: this.tokenDetails.treasury, auth: this.tokenDetails.auth, version: Config.vars.VERSION },
            typeArguments: this.typeArgs,
        })(ptb)
        return ptb
    }

    /** Pauses the token, preventing all transfers, issuance, and burns. */
    async pause(signer: string) {
        return this.buildSetBytes(this.pausePTB(), signer)
    }

    unpausePTB(ptb?: Transaction) {
        ptb ??= new Transaction()
        dsToken.unpause({
            package: this.pkg,
            arguments: { treasury: this.tokenDetails.treasury, auth: this.tokenDetails.auth, version: Config.vars.VERSION },
            typeArguments: this.typeArgs,
        })(ptb)
        return ptb
    }

    /** Unpauses the token, resuming normal operations. */
    async unpause(signer: string) {
        return this.buildSetBytes(this.unpausePTB(), signer)
    }

    // ==== Issuance ====

    issuePTB(
        to: string,
        value: bigint,
        reasonCode: number,
        reasonString: string,
        valuesLocked: bigint[],
        releaseTimes: number[],
        issuanceTimeMS: number,
        ptb?: Transaction
    ) {
        ptb ??= new Transaction()
        const pasAccount = this.getPASAccount(to)
        dsToken.issueTokens({
            package: this.pkg,
            arguments: {
                treasury: this.tokenDetails.treasury,
                auth: this.tokenDetails.auth,
                investors: this.tokenDetails.investorInfo,
                complianceConfig: this.tokenDetails.complianceConfig,
                to: pasAccount,
                toAddress: to,
                value,
                reasonCode,
                reasonString,
                version: Config.vars.VERSION,
                valuesLocked,
                releaseTimes,
                issuanceTimeMs: issuanceTimeMS,
            },
            typeArguments: this.typeArgs,
        })(ptb)
        return ptb
    }

    /** Issues tokens to an investor's PAS account. Requires IssueTokens ability. */
    async issue(
        signer: string,
        to: string,
        value: bigint,
        reasonCode: number,
        reasonString: string,
        valuesLocked: bigint[],
        releaseTimes: number[],
        issuanceTimeMS: number
    ) {
        return this.buildSetBytes(this.issuePTB(to, value, reasonCode, reasonString, valuesLocked, releaseTimes, issuanceTimeMS), signer)
    }

    issueNoAccountPTB(
        to: string,
        value: bigint,
        reasonCode: number,
        reasonString: string,
        valuesLocked: bigint[],
        releaseTimes: number[],
        issuanceTimeMS: number,
        ptb?: Transaction
    ) {
        ptb ??= new Transaction()
        dsToken.issueTokensNoAccount({
            package: this.pkg,
            arguments: {
                treasury: this.tokenDetails.treasury,
                auth: this.tokenDetails.auth,
                investors: this.tokenDetails.investorInfo,
                complianceConfig: this.tokenDetails.complianceConfig,
                namespace: Config.vars.PAS_NAMESPACE,
                to,
                value,
                reasonCode,
                reasonString,
                version: Config.vars.VERSION,
                valuesLocked,
                releaseTimes,
                issuanceTimeMs: issuanceTimeMS,
            },
            typeArguments: this.typeArgs,
        })(ptb)
        return ptb
    }

    /** Issues tokens to a wallet, creating the PAS account if it doesn't exist. */
    async issueNoAccount(
        signer: string,
        to: string,
        value: bigint,
        reasonCode: number,
        reasonString: string,
        valuesLocked: bigint[],
        releaseTimes: number[],
        issuanceTimeMS: number
    ) {
        return this.buildSetBytes(this.issueNoAccountPTB(to, value, reasonCode, reasonString, valuesLocked, releaseTimes, issuanceTimeMS), signer)
    }

    // ==== Burn ====

    burnPTB(
        from: string,
        value: bigint,
        reason: string,
        ptb?: Transaction,
        clawbackRequest?: ReturnType<Transaction['moveCall']>
    ) {
        if (!clawbackRequest) {
            const result = this.initiateClawbackFundsPTB(from, value, ptb)
            ptb = result.ptb
            clawbackRequest = result.clawbackRequest
        } else {
            ptb ??= new Transaction()
        }
        dsToken.burn({
            package: this.pkg,
            arguments: {
                treasury: this.tokenDetails.treasury,
                auth: this.tokenDetails.auth,
                investors: this.tokenDetails.investorInfo,
                policy: this.tokenDetails.pasPolicy,
                request: clawbackRequest,
                reason,
                version: Config.vars.VERSION,
            },
            typeArguments: this.typeArgs,
        })(ptb)
        return ptb
    }

    /** Burns tokens from an investor's account. Requires BurnTokens ability. */
    async burn(signer: string, from: string, value: bigint, reason: string) {
        return this.buildSetBytes(this.burnPTB(from, value, reason), signer)
    }

    // ==== Seize ====

    seizePTB(
        from: string,
        to: string,
        value: bigint,
        reason: string,
        ptb?: Transaction,
        clawbackRequest?: ReturnType<Transaction['moveCall']>
    ) {
        if (!clawbackRequest) {
            const result = this.initiateClawbackFundsPTB(from, value, ptb)
            ptb = result.ptb
            clawbackRequest = result.clawbackRequest
        } else {
            ptb ??= new Transaction()
        }
        const toAccount = this.getPASAccount(to)
        dsToken.seize({
            package: this.pkg,
            arguments: {
                auth: this.tokenDetails.auth,
                investors: this.tokenDetails.investorInfo,
                policy: this.tokenDetails.pasPolicy,
                request: clawbackRequest,
                to: toAccount,
                toAddress: to,
                reason,
                version: Config.vars.VERSION,
            },
            typeArguments: this.typeArgs,
        })(ptb)
        return ptb
    }

    /** Seizes tokens from one investor and transfers them to an issuer wallet. Requires SeizeTokens ability. */
    async seize(signer: string, from: string, to: string, value: bigint, reason: string) {
        return this.buildSetBytes(this.seizePTB(from, to, value, reason), signer)
    }

    // ==== Transfer ====

    transferPTB(
        from: string,
        to: string,
        amount: bigint,
        ptb?: Transaction,
        transferRequest?: ReturnType<Transaction['moveCall']>
    ) {
        if (!transferRequest) {
            const result = this.initiateSendFundsPTB(from, to, amount, ptb)
            ptb = result.ptb
            transferRequest = result.transferRequest
        } else {
            ptb ??= new Transaction()
        }

        dsToken.transfer({
            package: this.pkg,
            arguments: {
                treasury: this.tokenDetails.treasury,
                investors: this.tokenDetails.investorInfo,
                complianceConfig: this.tokenDetails.complianceConfig,
                request: transferRequest,
                version: Config.vars.VERSION,
            },
            typeArguments: this.typeArgs,
        })(ptb)
        return this.resolveTransferRequestPTB(transferRequest, ptb)
    }

    /** Transfers tokens between investors. Subject to all compliance rules. */
    async transfer(signer: string, from: string, to: string, amount: bigint) {
        return this.buildSetBytes(this.transferPTB(from, to, amount), signer)
    }

    // ==== Template Commands ====

    setTemplateCommandPTB(command: any, ptb?: Transaction, auth?: any) {
        ptb ??= new Transaction()
        dsToken.setTemplateCommand({
            package: this.pkg,
            arguments: {
                auth: auth ?? this.tokenDetails.auth,
                templates: this.getTemplatesObjectId(),
                command,
                version: Config.vars.VERSION,
            },
            typeArguments: this.typeArgs,
        })(ptb)
        return ptb
    }

    async setTemplateCommand(signer: string, command: any) {
        return this.buildSetBytes(this.setTemplateCommandPTB(command), signer)
    }

    unsetTemplateCommandPTB(ptb?: Transaction) {
        ptb ??= new Transaction()
        dsToken.unsetTemplateCommand({
            package: this.pkg,
            arguments: {
                auth: this.tokenDetails.auth,
                templates: this.getTemplatesObjectId(),
                version: Config.vars.VERSION,
            },
            typeArguments: this.typeArgs,
        })(ptb)
        return ptb
    }

    async unsetTemplateCommand(signer: string) {
        return this.buildSetBytes(this.unsetTemplateCommandPTB(), signer)
    }

    setTransferTemplateCommandPTB(ptbDetails?: PTBDetails) {
        ptbDetails ??= newPTBDetails()
        const ptb = ptbDetails.ptb
        const command = this.buildTransferCommand(ptb)
        const auth = ptbDetails.tokenDetails?.auth
        return this.setTemplateCommandPTB(command, ptb, auth)
    }

    async setTransferTemplateCommand(signer: string) {
        return this.buildSetBytes(this.setTransferTemplateCommandPTB(), signer)
    }

    // ==== PAS Integration ====

    getPASAccount(address: string) {
        const key = 'AccountKey'
        const serializedBcs = bcs.struct(key, { address: bcs.Address }).serialize({ address })
        return deriveObjectId(
            Config.vars.PAS_NAMESPACE,
            'keys',
            key,
            Config.vars.PAS_PACKAGE_ID,
            undefined,
            serializedBcs
        )
    }

    initiateClawbackFundsPTB(from: string, value: bigint, ptb?: Transaction) {
        ptb ??= new Transaction()
        const pasAccount = this.getPASAccount(from)
        const clawbackRequest = ptb.moveCall({
            target: `${Config.vars.PAS_PACKAGE_ID}::account::clawback_balance`,
            typeArguments: [this.tokenAddress],
            arguments: [ptb.object(pasAccount), ptb.pure.u64(value)],
        })
        return { ptb, clawbackRequest }
    }

    initiateSendFundsPTB(from: string, to: string, amount: bigint, ptb?: Transaction) {
        ptb ??= new Transaction()
        const fromRwaAccount = this.getPASAccount(from)
        const toRwaAccount = this.getPASAccount(to)
        const auth = ptb.moveCall({
            target: `${Config.vars.PAS_PACKAGE_ID}::account::new_auth`,
        })
        const transferRequest = ptb.moveCall({
            target: `${Config.vars.PAS_PACKAGE_ID}::account::send_balance`,
            typeArguments: [this.tokenAddress],
            arguments: [
                ptb.object(fromRwaAccount),
                auth,
                ptb.object(toRwaAccount),
                ptb.pure.u64(amount),
            ],
        })
        return { ptb, transferRequest }
    }

    resolveTransferRequestPTB(
        transferRequest: ReturnType<Transaction['moveCall']>,
        ptb: Transaction
    ) {
        ptb.moveCall({
            target: `${Config.vars.PAS_PACKAGE_ID}::send_funds::resolve_balance`,
            typeArguments: [this.tokenAddress],
            arguments: [transferRequest, ptb.object(this.tokenDetails.pasPolicy)],
        })
        return ptb
    }

    buildTransferCommand(ptb: Transaction) {
        const ptbPkg = Config.vars.PTB_PACKAGE_ID
        const pkg = Config.vars.PACKAGE_ID

        const treasuryArg = ptb.moveCall({
            target: `${ptbPkg}::ptb::object_by_id`,
            arguments: [ptb.pure.id(this.tokenDetails.treasury)],
        })

        const investorsArg = ptb.moveCall({
            target: `${ptbPkg}::ptb::object_by_id`,
            arguments: [ptb.pure.id(this.tokenDetails.investorInfo)],
        })

        const complianceArg = ptb.moveCall({
            target: `${ptbPkg}::ptb::object_by_id`,
            arguments: [ptb.pure.id(this.tokenDetails.complianceConfig)],
        })

        const requestArg = ptb.moveCall({
            target: `${ptbPkg}::ptb::ext_input`,
            typeArguments: [`${Config.vars.PAS_PACKAGE_ID}::templates::PAS`],
            arguments: [ptb.pure.string('request')],
        })

        const versionArg = ptb.moveCall({
            target: `${ptbPkg}::ptb::object_by_id`,
            arguments: [ptb.pure.id(Config.vars.VERSION)],
        })

        const clockArg = ptb.moveCall({
            target: `${ptbPkg}::ptb::clock`,
        })

        const argsVec = ptb.makeMoveVec({
            type: `${ptbPkg}::ptb::Argument`,
            elements: [treasuryArg, investorsArg, complianceArg, requestArg, versionArg, clockArg],
        })

        const typeArgsVec = ptb.makeMoveVec({
            type: '0x1::string::String',
            elements: [ptb.pure.string(this.tokenAddress)],
        })

        return ptb.moveCall({
            target: `${ptbPkg}::ptb::move_call`,
            arguments: [
                ptb.pure.string(pkg),
                ptb.pure.string('ds_token'),
                ptb.pure.string('transfer'),
                argsVec,
                typeArgsVec,
            ],
        })
    }

    // ==== Private Helpers ====

    private get pkg() { return Config.vars.PACKAGE_ID }
    private get typeArgs(): [string] { return [this.tokenAddress] }

    private buildSetBytes(ptb: Transaction, signer: string) {
        return SuiClient.getMoveCallBytesFromPTB(ptb, signer)
    }

    private async getCurrency() {
        const res = await SuiClient.getObject(this.tokenDetails.currency)
        const fields = (res.data?.content as any)?.fields

        if (!fields) {
            throw new Error('Unable to find metadata.')
        }
        return fields
    }

    private getTemplatesObjectId() {
        return deriveObjectId(
            Config.vars.PAS_NAMESPACE,
            'keys',
            'TemplateKey',
            Config.vars.PAS_PACKAGE_ID
        )
    }
}
