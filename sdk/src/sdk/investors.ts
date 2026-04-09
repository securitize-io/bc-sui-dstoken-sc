import { MoveType, SuiClient } from '../easysui'
import { Config } from './utils/config'
import { getTokenDetails } from './token'
import {
    Attribute,
    AttributeStatus,
    AttributeType,
    toAttributeStatus,
    toAttributeType,
} from './domains'
import { InvestorDetails } from './domains'
import { Transaction } from '@mysten/sui/transactions'
import { bcs } from '@mysten/sui/bcs'

export class Investors {
    private readonly tokenAddress: string
    private readonly tokenDetails: any

    constructor(tokenAddress: string) {
        this.tokenAddress = tokenAddress
        this.tokenDetails = getTokenDetails(tokenAddress)
    }

    private getTarget(func: string) {
        return `${Config.vars.PACKAGE_ID}::registry_service::${func}`
    }

    private buildGetPTB(func: string, args: any[], argTypes: MoveType[]) {
        return SuiClient.getPTB(
            this.getTarget(func),
            [this.tokenAddress],
            [this.tokenDetails.investorInfo, ...args],
            [MoveType.object, ...argTypes],
        )
    }

    private _buildSetPTB(func: string, args: any[], argTypes?: any[], ptb?: Transaction) {
        args = [
            this.tokenDetails.investorInfo,
            this.tokenDetails.auth,
            ...args,
            Config.vars.VERSION,
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

    private buildSetPTB(
        signer: string,
        func: string,
        args: any[],
        argTypes?: any[],
        ptb?: Transaction
    ) {
        const _ptb = this._buildSetPTB(func, args, argTypes, ptb)
        return SuiClient.getMoveCallBytesFromPTB(_ptb, signer)
    }

    // ==== View Functions ====

    async getInvestorDetails(investorId: string): Promise<InvestorDetails> {
        const investor = await SuiClient.getObject(this.tokenDetails.investorInfo)
        const fields = (investor.data?.content as any)?.fields

        const investorsTableId = fields.investors.id
        const { object: investorObject } = await SuiClient.client.core.getDynamicObjectField({
            parentId: investorsTableId,
            name: {
                type: '0x1::string::String',
                bcs: bcs.string().serialize(investorId).toBytes(),
            },
            include: { json: true },
        })

        if (!investorObject) {
            throw `Investor ${investorId} does not exist.`
        }

        let investorFields = (investorObject as any).json
        const country = investorFields.country
        const totalBalance = investorFields.total_balance
        const wallets = investorFields.wallets

        let attributes: Attribute[] = []
        const attributesSize = investorFields.attributes.size
        if (parseInt(attributesSize) > 0) {
            const attributesTableId = investorFields.attributes.id
            const attributesResult = await SuiClient.client.listDynamicFields({
                parentId: attributesTableId,
            })

            const attributeObjectCalls = attributesResult.dynamicFields.map((f: any) =>
                SuiClient.getObject(f.fieldId)
            )
            const attributeObjects = await Promise.all(attributeObjectCalls)

            attributes = attributeObjects.map((a: any): Attribute => {
                const fields = (a.data?.content as any)?.fields
                const name = toAttributeType(fields.name)
                const expiration: string = fields.value.expiration || 0
                const status = toAttributeStatus(fields.value.value)

                return {
                    name,
                    status,
                    expiry: parseInt(expiration),
                }
            })
        }

        return {
            id: investorId,
            country,
            attributes,
            totalBalance,
            wallets,
        }
    }

    async isInvestor(investorId: string, sender: string) {
        const ptb = this.buildGetPTB('is_investor', [investorId], [MoveType.string])
        return SuiClient.devInspectBool(ptb, sender)
    }

    async getInvestorIdByWallet(wallet: string, sender: string) {
        const ptb = this.buildGetPTB('get_investor_id_by_wallet', [wallet], [MoveType.address])
        return SuiClient.devInspectString(ptb, sender)
    }

    async isWallet(wallet: string, sender: string) {
        const ptb = this.buildGetPTB('is_wallet', [wallet], [MoveType.address])
        return SuiClient.devInspectBool(ptb, sender)
    }

    async isSpecialWallet(wallet: string, sender: string) {
        const ptb = this.buildGetPTB('is_special_wallet', [wallet], [MoveType.address])
        return SuiClient.devInspectBool(ptb, sender)
    }

    async getSpecialWalletType(wallet: string, sender: string) {
        const ptb = this.buildGetPTB('get_special_wallet_type', [wallet], [MoveType.address])
        return SuiClient.devInspectU64(ptb, sender)
    }

    async investorWalletBalanceTotal(investorId: string, sender: string) {
        const ptb = this.buildGetPTB('investor_wallet_balance_total', [investorId], [MoveType.string])
        return SuiClient.devInspectU64(ptb, sender)
    }

    async investorWalletBalance(walletAddress: string, sender: string) {
        const ptb = this.buildGetPTB('investor_wallet_balance', [walletAddress], [MoveType.address])
        return SuiClient.devInspectU64(ptb, sender)
    }

    async isAccreditedInvestorById(investorId: string, sender: string) {
        const ptb = this.buildGetPTB('is_accredited_investor_by_id', [investorId], [MoveType.string])
        return SuiClient.devInspectBool(ptb, sender)
    }

    async isAccreditedInvestor(wallet: string, sender: string) {
        const ptb = this.buildGetPTB('is_accredited_investor', [wallet], [MoveType.address])
        return SuiClient.devInspectBool(ptb, sender)
    }

    async isQualifiedInvestorById(investorId: string, sender: string) {
        const ptb = this.buildGetPTB('is_qualified_investor_by_id', [investorId], [MoveType.string])
        return SuiClient.devInspectBool(ptb, sender)
    }

    async isQualifiedInvestor(wallet: string, sender: string) {
        const ptb = this.buildGetPTB('is_qualified_investor', [wallet], [MoveType.address])
        return SuiClient.devInspectBool(ptb, sender)
    }

    async getCountryCompliance(country: string, sender: string) {
        const ptb = this.buildGetPTB('get_country_compliance', [country], [MoveType.string])
        return SuiClient.devInspectU64(ptb, sender)
    }

    async getCountry(investorId: string, sender: string) {
        const ptb = this.buildGetPTB('get_country', [investorId], [MoveType.string])
        return SuiClient.devInspectString(ptb, sender)
    }

    async getAttributeValue(investorId: string, attributeId: AttributeType, sender: string) {
        const ptb = this.buildGetPTB('get_attribute_value', [investorId, attributeId], [MoveType.string, MoveType.u64])
        return Number(await SuiClient.devInspectU64(ptb, sender))
    }

    async getAttributeExpiration(investorId: string, attributeId: AttributeType, sender: string) {
        const ptb = this.buildGetPTB('get_attribute_expiration', [investorId, attributeId], [MoveType.string, MoveType.u64])
        return SuiClient.devInspectU64(ptb, sender)
    }

    async getTotalInvestorsCount(sender: string) {
        const ptb = SuiClient.getPTB(
            this.getTarget('get_total_investors_count'),
            [this.tokenAddress],
            [this.tokenDetails.investorInfo],
            [],
            sender
        )
        return SuiClient.devInspectU64(ptb, sender)
    }

    async getAccreditedInvestorCount(sender: string) {
        const ptb = SuiClient.getPTB(
            this.getTarget('get_accredited_investor_count'),
            [this.tokenAddress],
            [this.tokenDetails.investorInfo],
            [],
            sender
        )
        return SuiClient.devInspectU64(ptb, sender)
    }

    async getUsInvestorCount(sender: string) {
        const ptb = SuiClient.getPTB(
            this.getTarget('get_us_investor_count'),
            [this.tokenAddress],
            [this.tokenDetails.investorInfo],
            [],
            sender
        )
        return SuiClient.devInspectU64(ptb, sender)
    }

    async getUsAccreditedInvestorCount(sender: string) {
        const ptb = SuiClient.getPTB(
            this.getTarget('get_us_accredited_investor_count'),
            [this.tokenAddress],
            [this.tokenDetails.investorInfo],
            [],
            sender
        )
        return SuiClient.devInspectU64(ptb, sender)
    }

    async getJpInvestorCount(sender: string) {
        const ptb = SuiClient.getPTB(
            this.getTarget('get_jp_investor_count'),
            [this.tokenAddress],
            [this.tokenDetails.investorInfo],
            [],
            sender
        )
        return SuiClient.devInspectU64(ptb, sender)
    }

    async getEuRetailInvestorCount(toCountry: string, sender: string): Promise<bigint | null> {
        const ptb = this.buildGetPTB('get_eu_retail_investor_count', [toCountry], [MoveType.string])
        return SuiClient.devInspectOptionU64(ptb, sender)
    }

    // ==== Investor Count Setters ====

    async setTotalInvestorsCount(count: number, signer: string) {
        return this.buildSetPTB(signer, 'set_total_investors_count', [count])
    }

    async setUsInvestorsCount(count: number, signer: string) {
        return this.buildSetPTB(signer, 'set_us_investors_count', [count])
    }

    async setUsAccreditedInvestorsCount(count: number, signer: string) {
        return this.buildSetPTB(signer, 'set_us_accredited_investors_count', [count])
    }

    async setAccreditedInvestorsCount(count: number, signer: string) {
        return this.buildSetPTB(signer, 'set_accredited_investors_count', [count])
    }

    async setJpInvestorsCount(count: number, signer: string) {
        return this.buildSetPTB(signer, 'set_jp_investors_count', [count])
    }

    // ==== Setters ====

    registerInvestorPTB(investorId: string, ptb?: Transaction) {
        ptb ??= new Transaction()
        return this._buildSetPTB('register_investor', [investorId], [], ptb)
    }

    async registerInvestor(investorId: string, signer: string) {
        const ptb = this.registerInvestorPTB(investorId)
        return SuiClient.getMoveCallBytesFromPTB(ptb, signer)
    }

    registerInvestorIfNotExistsPTB(investorId: string, ptb?: Transaction) {
        ptb ??= new Transaction()
        return this._buildSetPTB('register_investor_if_not_exists', [investorId], [], ptb)
    }

    async registerInvestorIfNotExists(investorId: string, signer: string) {
        const ptb = this.registerInvestorIfNotExistsPTB(investorId)
        return SuiClient.getMoveCallBytesFromPTB(ptb, signer)
    }

    async removeInvestor(investorId: string, signer: string) {
        return this.buildSetPTB(signer, 'remove_investor', [investorId])
    }

    updateInvestorPTB(
        investorId: string,
        country: string,
        wallets: string[],
        attributes: Attribute[],
        ptb?: Transaction
    ) {
        ptb ??= new Transaction()

        const attributeIds = attributes.map((a) => a.name)
        const attributeValues = attributes.map((a) => a.status)
        const attributeExpirations = attributes.map((a) => a.expiry)

        const args = [
            Config.vars.PAS_NAMESPACE,
            investorId,
            country,
            wallets,
            attributeIds,
            attributeValues,
            attributeExpirations,
        ]
        const argTypes = [
            MoveType.object,
            MoveType.object,
            MoveType.object,
            MoveType.string,
            MoveType.string,
            MoveType.vec_address,
            MoveType.vec_u64,
            MoveType.vec_u64,
            MoveType.vec_u64,
            MoveType.object,
        ]
        return this._buildSetPTB('update_investor', args, argTypes, ptb)
    }

    async updateInvestor(
        investorId: string,
        country: string,
        wallets: string[],
        attributes: Attribute[],
        signer: string
    ) {
        const ptb = this.updateInvestorPTB(investorId, country, wallets, attributes)
        return SuiClient.getMoveCallBytesFromPTB(ptb, signer)
    }

    addWalletPTB(investorId: string, walletAddr: string, ptb?: Transaction) {
        ptb ??= new Transaction()
        return this._buildSetPTB(
            'add_wallet',
            [Config.vars.PAS_NAMESPACE, investorId, walletAddr],
            [],
            ptb
        )
    }

    async addWallet(investorId: string, walletAddr: string, signer: string) {
        const ptb = this.addWalletPTB(investorId, walletAddr)
        return SuiClient.getMoveCallBytesFromPTB(ptb, signer)
    }

    async removeWallet(investorId: string, walletAddr: string, signer: string) {
        return this.buildSetPTB(signer, 'remove_wallet', [investorId, walletAddr])
    }

    async setCountry(investorId: string, country: string, signer: string) {
        return this.buildSetPTB(signer, 'set_country', [investorId, country])
    }

    async setAttribute(
        investorId: string,
        attributeId: AttributeType,
        attributeValue: AttributeStatus,
        attributeExpiration: number,
        signer: string
    ) {
        return this.buildSetPTB(signer, 'set_attribute', [
            investorId,
            attributeId,
            attributeValue,
            attributeExpiration,
        ])
    }
}
