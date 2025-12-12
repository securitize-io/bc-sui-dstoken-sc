import {MoveType, SuiClient} from "../easysui";
import {Config} from "./utils/config";
import {getTokenDetails} from "./token";

export class Investors {
    private readonly tokenAddress: string;
    private readonly tokenDetails: any;

    constructor(tokenAddress: string) {
        this.tokenAddress = tokenAddress;
        this.tokenDetails = getTokenDetails(tokenAddress);
    }

    private getTarget(func: string) {
        return `${Config.vars.PACKAGE_ID}::registry_service::${func}`
    }

    private getPTB(func: string, args: any[]) {
        return SuiClient.getPTB(
            this.getTarget(func),
            [this.tokenAddress],
            [this.tokenDetails.investorInfo, ...args],
        )
    }

    // ==== View Functions ====

    async isInvestor(investorId: string, sender: string) {
        const ptb = this.getPTB('is_investor', [investorId])
        return SuiClient.devInspectBool(ptb, sender)
    }

    async getInvestorIdByWallet(wallet: string, sender: string) {
        const ptb = this.getPTB('get_investor_id_by_wallet', [wallet])
        return SuiClient.devInspectString(ptb, sender)
    }

    async isWallet(wallet: string, sender: string) {
        const ptb = this.getPTB('is_wallet', [wallet])
        return SuiClient.devInspectBool(ptb, sender)
    }

    async isSpecialWallet(wallet: string, sender: string) {
        const ptb = this.getPTB('is_special_wallet', [wallet])
        return SuiClient.devInspectBool(ptb, sender)
    }

    async getSpecialWalletType(wallet: string, sender: string) {
        const ptb = this.getPTB('get_special_wallet_type', [wallet])
        return SuiClient.devInspectU64(ptb, sender)
    }

    async investorWalletBalanceTotal(investorId: string, sender: string) {
        const ptb = this.getPTB('investor_wallet_balance_total', [investorId])
        return SuiClient.devInspectU64(ptb, sender)
    }

    async isAccreditedInvestorById(investorId: string, sender: string) {
        const ptb = this.getPTB('is_accredited_investor_by_id', [investorId])
        return SuiClient.devInspectBool(ptb, sender)
    }

    async isAccreditedInvestor(wallet: string, sender: string) {
        const ptb = this.getPTB('is_accredited_investor', [wallet])
        return SuiClient.devInspectBool(ptb, sender)
    }

    async isQualifiedInvestorById(investorId: string, sender: string) {
        const ptb = this.getPTB('is_qualified_investor_by_id', [investorId])
        return SuiClient.devInspectBool(ptb, sender)
    }

    async isQualifiedInvestor(wallet: string, sender: string) {
        const ptb = this.getPTB('is_qualified_investor', [wallet])
        return SuiClient.devInspectBool(ptb, sender)
    }

    async getCountryCompliance(country: string, sender: string) {
        const ptb = this.getPTB('get_country_compliance', [country])
        return SuiClient.devInspectU64(ptb, sender)
    }

    async getCountry(investorId: string, sender: string) {
        const ptb = this.getPTB('get_country', [investorId])
        return SuiClient.devInspectString(ptb, sender)
    }

    async getAttributeValue(investorId: string, attributeId: number, sender: string) {
        const ptb = this.getPTB('get_attribute_value', [investorId, attributeId])
        return SuiClient.devInspectU64(ptb, sender)
    }

    async getAttributeExpiration(investorId: string, attributeId: number, sender: string) {
        const ptb = this.getPTB('get_attribute_expiration', [investorId, attributeId])
        return SuiClient.devInspectU64(ptb, sender)
    }

    async getTotalInvestorsCount(sender: string) {
        const ptb = SuiClient.getPTB(this.getTarget('get_total_investors_count'), [this.tokenAddress], [this.tokenDetails.investorInfo], [], sender)
        return SuiClient.devInspectU64(ptb, sender)
    }

    async getAccreditedInvestorCount(sender: string) {
        const ptb = SuiClient.getPTB(this.getTarget('get_accredited_investor_count'), [this.tokenAddress], [this.tokenDetails.investorInfo], [], sender)
        return SuiClient.devInspectU64(ptb, sender)
    }

    async getUsInvestorCount(sender: string) {
        const ptb = SuiClient.getPTB(this.getTarget('get_us_investor_count'), [this.tokenAddress], [this.tokenDetails.investorInfo], [], sender)
        return SuiClient.devInspectU64(ptb, sender)
    }

    async getUsAccreditedInvestorCount(sender: string) {
        const ptb = SuiClient.getPTB(this.getTarget('get_us_accredited_investor_count'), [this.tokenAddress], [this.tokenDetails.investorInfo], [], sender)
        return SuiClient.devInspectU64(ptb, sender)
    }

    async getJpInvestorCount(sender: string) {
        const ptb = SuiClient.getPTB(this.getTarget('get_jp_investor_count'), [this.tokenAddress], [this.tokenDetails.investorInfo], [], sender)
        return SuiClient.devInspectU64(ptb, sender)
    }

    async getEuRetailInvestorCount(toCountry: string, sender: string) {
        const ptb = this.getPTB('get_eu_retail_investor_count', [toCountry])
        return SuiClient.devInspectU64(ptb, sender)
    }

    // ==== Setters ====

    async registerInvestor(investorId: string, signer: string) {
        return SuiClient.getMoveCallBytes({
            signer,
            target: this.getTarget('register_investor'),
            typeArgs: [this.tokenAddress],
            args: [
                this.tokenDetails.investorInfo,
                this.tokenDetails.auth,
                investorId,
                Config.vars.VERSION
            ],
        })
    }

    async removeInvestor(investorId: string, signer: string) {
        return SuiClient.getMoveCallBytes({
            signer,
            target: this.getTarget('remove_investor'),
            typeArgs: [this.tokenAddress],
            args: [
                this.tokenDetails.investorInfo,
                this.tokenDetails.auth,
                investorId,
                Config.vars.VERSION
            ],
        })
    }

    async updateInvestor(
        investorId: string,
        country: string,
        wallets: string[],
        attributeIds: number[],
        attributeValues: number[],
        attributeExpirations: number[],
        signer: string,
    ) {
        return SuiClient.getMoveCallBytes({
            signer,
            target: this.getTarget('update_investor'),
            typeArgs: [this.tokenAddress],
            args: [
                this.tokenDetails.investorInfo,
                this.tokenDetails.auth,
                investorId,
                country,
                wallets,
                attributeIds,
                attributeValues,
                attributeExpirations,
                Config.vars.VERSION
            ],
            argTypes: [
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
        })
    }

    async removeWallet(
        investorId: string,
        wallet: string,
        signer: string
    ) {
        return SuiClient.getMoveCallBytes({
            signer,
            target: this.getTarget('remove_wallet'),
            typeArgs: [this.tokenAddress],
            args: [
                this.tokenDetails.investorInfo,
                this.tokenDetails.auth,
                investorId,
                wallet,
                Config.vars.VERSION
            ],
        })
    }

    async setAttribute(
        investorId: string,
        attributeId: number,
        attributeValue: number,
        attributeExpiration: number,
        signer: string,
    ) {
        return SuiClient.getMoveCallBytes({
            signer,
            target: this.getTarget('set_attribute'),
            typeArgs: [this.tokenAddress],
            args: [
                this.tokenDetails.investorInfo,
                this.tokenDetails.auth,
                investorId,
                attributeId,
                attributeValue,
                attributeExpiration,
                Config.vars.VERSION
            ],
        })
    }
}
