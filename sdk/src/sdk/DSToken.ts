import { CLOCK_ID, deriveObjectId, MoveType, SuiClient } from '../easysui'
import { Config } from './utils/config'
import { getTokenDetails, TokenDetails } from './token'
import { Transaction } from '@mysten/sui/transactions'
import { TokenMetadata } from './domains'
import { bcs } from '@mysten/sui/bcs'

export class DSToken {
    private readonly tokenAddress: string
    private readonly tokenDetails: TokenDetails

    constructor(tokenAddress: string) {
        this.tokenAddress = tokenAddress
        this.tokenDetails = getTokenDetails(tokenAddress)
    }

    private getTarget(func: string) {
        return `${Config.vars.PACKAGE_ID}::ds_token::${func}`
    }

    private buildGetPTB(func: string, args: any[]) {
        return SuiClient.getPTB(this.getTarget(func), [this.tokenAddress], args)
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
            throw new Error('Unable to find metadata.')
        }
        return fields
    }

    // ==== Token Management Functions ====

    setMetadataPTB(name?: string, description?: string, iconUrl?: string, ptb?: Transaction) {
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

    async setMetadata(signer: string, name?: string, description?: string, iconUrl?: string) {
        const ptb = this.setMetadataPTB(name, description, iconUrl)
        return this.buildSetBytes(ptb, signer)
    }

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
        const args = [
            this.tokenDetails.treasury,
            this.tokenDetails.auth,
            this.tokenDetails.investorInfo,
            this.tokenDetails.complianceConfig,
            pasAccount,
            to,
            value,
            reasonCode,
            reasonString,
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
            MoveType.address,
            MoveType.u64,
            MoveType.u64,
            MoveType.string,
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
        reasonCode: number,
        reasonString: string,
        valuesLocked: bigint[],
        releaseTimes: number[],
        issuanceTimeMS: number
    ) {
        const ptb = this.issuePTB(
            to,
            value,
            reasonCode,
            reasonString,
            valuesLocked,
            releaseTimes,
            issuanceTimeMS
        )
        return this.buildSetBytes(ptb, signer)
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
        const args = [
            this.tokenDetails.treasury,
            this.tokenDetails.auth,
            this.tokenDetails.investorInfo,
            this.tokenDetails.complianceConfig,
            Config.vars.PAS_NAMESPACE,
            to,
            value,
            reasonCode,
            reasonString,
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
            MoveType.address,
            MoveType.u64,
            MoveType.u64,
            MoveType.string,
            MoveType.object,
            MoveType.vec_u64,
            MoveType.vec_u64,
            MoveType.u64,
            MoveType.object,
        ]
        return this.buildSetPTB('issue_tokens_no_account', args, ptb, argsTypes)
    }

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
        const ptb = this.issueNoAccountPTB(
            to,
            value,
            reasonCode,
            reasonString,
            valuesLocked,
            releaseTimes,
            issuanceTimeMS
        )
        return this.buildSetBytes(ptb, signer)
    }

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
        const args = [
            this.tokenDetails.treasury,
            this.tokenDetails.auth,
            this.tokenDetails.investorInfo,
            this.tokenDetails.pasPolicy,
            clawbackRequest,
            reason,
            Config.vars.VERSION,
        ]
        const argsTypes = [
            MoveType.object,
            MoveType.object,
            MoveType.object,
            MoveType.object,
            MoveType.object,
            MoveType.string,
            MoveType.object,
        ]
        return this.buildSetPTB('burn', args, ptb, argsTypes)
    }

    async burn(signer: string, from: string, value: bigint, reason: string) {
        const ptb = this.burnPTB(from, value, reason)
        return this.buildSetBytes(ptb, signer)
    }

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
        const args = [
            this.tokenDetails.auth,
            this.tokenDetails.investorInfo,
            this.tokenDetails.pasPolicy,
            clawbackRequest,
            toAccount,
            to,
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
            MoveType.string,
            MoveType.object,
        ]
        return this.buildSetPTB('seize', args, ptb, argsTypes)
    }

    async seize(signer: string, from: string, to: string, value: bigint, reason: string) {
        const ptb = this.seizePTB(from, to, value, reason)
        return this.buildSetBytes(ptb, signer)
    }

    pausePTB(ptb?: Transaction) {
        ptb ??= new Transaction()
        const args = [this.tokenDetails.treasury, this.tokenDetails.auth, Config.vars.VERSION]
        return this.buildSetPTB('pause', args, ptb)
    }

    async pause(signer: string) {
        const ptb = this.pausePTB()
        return this.buildSetBytes(ptb, signer)
    }

    unpausePTB(ptb?: Transaction) {
        ptb ??= new Transaction()
        const args = [this.tokenDetails.treasury, this.tokenDetails.auth, Config.vars.VERSION]
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
        transferRequest?: ReturnType<Transaction['moveCall']>
    ) {
        if (!transferRequest) {
            const result = this.initiateSendFundsPTB(from, to, amount, ptb)
            ptb = result.ptb
            transferRequest = result.transferRequest
        } else {
            ptb ??= new Transaction()
        }

        const args = [
            this.tokenDetails.treasury,
            this.tokenDetails.investorInfo,
            this.tokenDetails.complianceConfig,
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
        ]

        ptb = this.buildSetPTB('transfer', args, ptb, argsTypes)
        return this.resolveTransferRequestPTB(transferRequest, ptb)
    }

    async transfer(signer: string, from: string, to: string, amount: bigint) {
        const ptb = this.transferPTB(from, to, amount)
        return this.buildSetBytes(ptb, signer)
    }

    private getTemplatesObjectId() {
        return deriveObjectId(
            Config.vars.PAS_NAMESPACE,
            'keys',
            'TemplateKey',
            Config.vars.PAS_PACKAGE_ID
        )
    }

    setTemplateCommandPTB(command: any, ptb?: Transaction) {
        ptb ??= new Transaction()
        const args = [
            this.tokenDetails.auth,
            this.getTemplatesObjectId(),
            command,
            Config.vars.VERSION,
        ]
        return this.buildSetPTB('set_template_command', args, ptb)
    }

    async setTemplateCommand(signer: string, command: any) {
        const ptb = this.setTemplateCommandPTB(command)
        return this.buildSetBytes(ptb, signer)
    }

    unsetTemplateCommandPTB(ptb?: Transaction) {
        ptb ??= new Transaction()
        const args = [this.tokenDetails.auth, this.getTemplatesObjectId(), Config.vars.VERSION]
        return this.buildSetPTB('unset_template_command', args, ptb)
    }

    async unsetTemplateCommand(signer: string) {
        const ptb = this.unsetTemplateCommandPTB()
        return this.buildSetBytes(ptb, signer)
    }

    buildTransferCommand(ptb: Transaction) {
        const ptbPkg = Config.vars.PTB_PACKAGE_ID
        const pkg = Config.vars.PACKAGE_ID

        const treasuryArg = ptb.moveCall({
            target: `${ptbPkg}::ptb::object_by_type_string`,
            arguments: [ptb.pure.string(`${pkg}::ds_token::Treasury<${this.tokenAddress}>`)],
        })

        const investorsArg = ptb.moveCall({
            target: `${ptbPkg}::ptb::object_by_type_string`,
            arguments: [
                ptb.pure.string(`${pkg}::registry_service::InvestorInfo<${this.tokenAddress}>`),
            ],
        })

        const complianceArg = ptb.moveCall({
            target: `${ptbPkg}::ptb::object_by_type_string`,
            arguments: [
                ptb.pure.string(
                    `${pkg}::compliance_service::ComplianceConfig<${this.tokenAddress}>`
                ),
            ],
        })

        const requestArg = ptb.moveCall({
            target: `${ptbPkg}::ptb::ext_input`,
            typeArguments: [`${Config.vars.PAS_PACKAGE_ID}::templates::PAS`],
            arguments: [ptb.pure.string('request')],
        })

        const versionArg = ptb.moveCall({
            target: `${ptbPkg}::ptb::object_by_type_string`,
            arguments: [ptb.pure.string(`${pkg}::version::Version`)],
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

    setTransferTemplateCommandPTB(ptb?: Transaction) {
        ptb ??= new Transaction()
        const command = this.buildTransferCommand(ptb)
        return this.setTemplateCommandPTB(command, ptb)
    }

    async setTransferTemplateCommand(signer: string) {
        const ptb = this.setTransferTemplateCommandPTB()
        return this.buildSetBytes(ptb, signer)
    }
}
