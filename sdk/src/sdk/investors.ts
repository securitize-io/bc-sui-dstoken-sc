import { SuiClient } from '../easysui'
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
import * as registryService from '../generated/securitize/registry_service'

export class Investors {
    private readonly tokenAddress: string
    private readonly tokenDetails: any

    constructor(tokenAddress: string) {
        this.tokenAddress = tokenAddress
        this.tokenDetails = getTokenDetails(tokenAddress)
    }

    // ==== View Functions ====

    /** Returns full investor details including country, wallets, attributes, and total balance. */
    async getInvestorDetails(investorId: string): Promise<InvestorDetails> {
        const investor = await SuiClient.getObject(this.tokenDetails.investorInfo)
        const fields = (investor.data?.content as any)?.fields

        const investorsTableId = fields.investors.id
        let investorFields: any
        try {
            investorFields = await SuiClient.getDynamicFieldValue(
                investorsTableId,
                '0x1::string::String',
                bcs.string().serialize(investorId).toBytes(),
            )
        } catch (e: any) {
            const msg = e?.message || ''
            if (msg.includes('not found') || msg.includes('not%20found')) {
                throw new Error(`Investor ${investorId} does not exist.`)
            }
            throw e
        }

        if (!investorFields) {
            throw new Error(`Investor ${investorId} does not exist.`)
        }

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
        return SuiClient.devInspectBool(this.buildView(registryService.isInvestor, { investorId }), sender)
    }

    async getInvestorIdByWallet(wallet: string, sender: string) {
        return SuiClient.devInspectString(this.buildView(registryService.getInvestorIdByWallet, { wallet }), sender)
    }

    async isWallet(wallet: string, sender: string) {
        return SuiClient.devInspectBool(this.buildView(registryService.isWallet, { wallet }), sender)
    }

    async isSpecialWallet(wallet: string, sender: string) {
        return SuiClient.devInspectBool(this.buildView(registryService.isSpecialWallet, { wallet }), sender)
    }

    async getSpecialWalletType(wallet: string, sender: string) {
        return SuiClient.devInspectU64(this.buildView(registryService.getSpecialWalletType, { wallet }), sender)
    }

    async investorWalletBalanceTotal(investorId: string, sender: string) {
        return SuiClient.devInspectU64(this.buildView(registryService.investorWalletBalanceTotal, { investorId }), sender)
    }

    async investorWalletBalance(walletAddress: string, sender: string) {
        return SuiClient.devInspectU64(this.buildView(registryService.investorWalletBalance, { investorInfo: this.tokenDetails.investorInfo, walletAddr: walletAddress }), sender)
    }

    async isAccreditedInvestorById(investorId: string, sender: string) {
        return SuiClient.devInspectBool(this.buildView(registryService.isAccreditedInvestorById, { investorId }), sender)
    }

    async isAccreditedInvestor(wallet: string, sender: string) {
        return SuiClient.devInspectBool(this.buildView(registryService.isAccreditedInvestor, { wallet }), sender)
    }

    async isQualifiedInvestorById(investorId: string, sender: string) {
        return SuiClient.devInspectBool(this.buildView(registryService.isQualifiedInvestorById, { investorId }), sender)
    }

    async isQualifiedInvestor(wallet: string, sender: string) {
        return SuiClient.devInspectBool(this.buildView(registryService.isQualifiedInvestor, { wallet }), sender)
    }

    async getCountryCompliance(country: string, sender: string) {
        return SuiClient.devInspectU64(this.buildView(registryService.getCountryCompliance, { country }), sender)
    }

    async getCountry(investorId: string, sender: string) {
        return SuiClient.devInspectString(this.buildView(registryService.getCountry, { investorId }), sender)
    }

    async getAttributeValue(investorId: string, attributeId: AttributeType, sender: string) {
        return Number(await SuiClient.devInspectU64(this.buildView(registryService.getAttributeValue, { investorId, attributeId }), sender))
    }

    async getAttributeExpiration(investorId: string, attributeId: AttributeType, sender: string) {
        return SuiClient.devInspectU64(this.buildView(registryService.getAttributeExpiration, { investorId, attributeId }), sender)
    }

    async getTotalInvestorsCount(sender: string) {
        return SuiClient.devInspectU64(this.buildView(registryService.getTotalInvestorsCount), sender)
    }

    async getAccreditedInvestorCount(sender: string) {
        return SuiClient.devInspectU64(this.buildView(registryService.getAccreditedInvestorCount), sender)
    }

    async getUsInvestorCount(sender: string) {
        return SuiClient.devInspectU64(this.buildView(registryService.getUsInvestorCount), sender)
    }

    async getUsAccreditedInvestorCount(sender: string) {
        return SuiClient.devInspectU64(this.buildView(registryService.getUsAccreditedInvestorCount), sender)
    }

    async getJpInvestorCount(sender: string) {
        return SuiClient.devInspectU64(this.buildView(registryService.getJpInvestorCount), sender)
    }

    async getEuRetailInvestorCount(toCountry: string, sender: string): Promise<bigint | null> {
        return SuiClient.devInspectOptionU64(this.buildView(registryService.getEuRetailInvestorCount, { toCountry }), sender)
    }

    // ==== Investor Count Setters ====

    async setTotalInvestorsCount(count: number, signer: string) {
        return SuiClient.getMoveCallBytesFromPTB(this.buildMutation(registryService.setTotalInvestorsCount, { count }), signer)
    }

    async setUsInvestorsCount(count: number, signer: string) {
        return SuiClient.getMoveCallBytesFromPTB(this.buildMutation(registryService.setUsInvestorsCount, { count }), signer)
    }

    async setUsAccreditedInvestorsCount(count: number, signer: string) {
        return SuiClient.getMoveCallBytesFromPTB(this.buildMutation(registryService.setUsAccreditedInvestorsCount, { count }), signer)
    }

    async setAccreditedInvestorsCount(count: number, signer: string) {
        return SuiClient.getMoveCallBytesFromPTB(this.buildMutation(registryService.setAccreditedInvestorsCount, { count }), signer)
    }

    async setJpInvestorsCount(count: number, signer: string) {
        return SuiClient.getMoveCallBytesFromPTB(this.buildMutation(registryService.setJpInvestorsCount, { count }), signer)
    }

    // ==== Investor CRUD ====

    registerInvestorPTB(investorId: string, ptb?: Transaction) {
        return this.buildMutation(registryService.registerInvestor, { investorId }, ptb)
    }

    /** Registers a new investor. Aborts if investor already exists. */
    async registerInvestor(investorId: string, signer: string) {
        return SuiClient.getMoveCallBytesFromPTB(this.registerInvestorPTB(investorId), signer)
    }

    registerInvestorIfNotExistsPTB(investorId: string, ptb?: Transaction) {
        return this.buildMutation(registryService.registerInvestorIfNotExists, { investorId }, ptb)
    }

    /** Registers an investor if not already registered. No-op if investor exists. */
    async registerInvestorIfNotExists(investorId: string, signer: string) {
        return SuiClient.getMoveCallBytesFromPTB(this.registerInvestorIfNotExistsPTB(investorId), signer)
    }

    /** Removes an investor and all associated data. */
    async removeInvestor(investorId: string, signer: string) {
        return SuiClient.getMoveCallBytesFromPTB(this.buildMutation(registryService.removeInvestor, { investorId }), signer)
    }

    updateInvestorPTB(
        investorId: string,
        country: string,
        wallets: string[],
        attributes: Attribute[],
        ptb?: Transaction
    ) {
        const attributeIds = attributes.map((a) => a.name)
        const attributeValues = attributes.map((a) => a.status)
        const attributeExpirations = attributes.map((a) => a.expiry)

        return this.buildMutation(registryService.updateInvestor, {
            namespace: Config.vars.PAS_NAMESPACE,
            investorId,
            country,
            wallets,
            attributeIds,
            attributeValues,
            attributeExpirations,
        }, ptb)
    }

    /** Updates investor country, wallets, and attributes in a single transaction. */
    async updateInvestor(
        investorId: string,
        country: string,
        wallets: string[],
        attributes: Attribute[],
        signer: string
    ) {
        return SuiClient.getMoveCallBytesFromPTB(this.updateInvestorPTB(investorId, country, wallets, attributes), signer)
    }

    // ==== Wallet Management ====

    addWalletPTB(investorId: string, walletAddr: string, ptb?: Transaction) {
        return this.buildMutation(registryService.addWallet, {
            namespace: Config.vars.PAS_NAMESPACE,
            investorId,
            walletAddr,
        }, ptb)
    }

    /** Adds a wallet to an investor and creates the associated PAS account. */
    async addWallet(investorId: string, walletAddr: string, signer: string) {
        return SuiClient.getMoveCallBytesFromPTB(this.addWalletPTB(investorId, walletAddr), signer)
    }

    async removeWallet(investorId: string, walletAddr: string, signer: string) {
        return SuiClient.getMoveCallBytesFromPTB(this.buildMutation(registryService.removeWallet, { investorId, walletAddr }), signer)
    }

    // ==== Investor Attributes ====

    async setCountry(investorId: string, country: string, signer: string) {
        return SuiClient.getMoveCallBytesFromPTB(this.buildMutation(registryService.setCountry, { investorId, country }), signer)
    }

    async setAttribute(
        investorId: string,
        attributeId: AttributeType,
        attributeValue: AttributeStatus,
        attributeExpiration: number,
        signer: string
    ) {
        return SuiClient.getMoveCallBytesFromPTB(this.buildMutation(registryService.setAttribute, {
            investorId,
            attributeId,
            attributeValue,
            attributeExpiration,
        }), signer)
    }

    // ==== Private Helpers ====

    private get pkg() { return Config.vars.PACKAGE_ID }
    private get typeArgs(): [string] { return [this.tokenAddress] }

    private buildView(fn: Function, extraArgs: Record<string, any> = {}): Transaction {
        const ptb = new Transaction()
        fn({ package: this.pkg, arguments: { investorInfo: this.tokenDetails.investorInfo, ...extraArgs }, typeArguments: this.typeArgs })(ptb)
        return ptb
    }

    private buildMutation(fn: Function, extraArgs: Record<string, any>, ptb?: Transaction): Transaction {
        ptb ??= new Transaction()
        fn({ package: this.pkg, arguments: { investorInfo: this.tokenDetails.investorInfo, auth: this.tokenDetails.auth, ...extraArgs, version: Config.vars.VERSION }, typeArguments: this.typeArgs })(ptb)
        return ptb
    }
}
