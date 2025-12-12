import {SuiClient} from "../easysui";
import {Config} from "./utils/config";
import {getTokenDetails} from "./token";

export class Wallets {
    private readonly tokenAddress: string;
    private readonly tokenDetails: any;

    constructor(tokenAddress: string) {
        this.tokenAddress = tokenAddress;
        this.tokenDetails = getTokenDetails(tokenAddress);
    }

    private getTarget(func: string) {
        return `${Config.vars.PACKAGE_ID}::wallet_manager::${func}`
    }

    private buildGetPTB(func: string, args: any[]) {
        return SuiClient.getPTB(
            this.getTarget(func),
            [this.tokenAddress],
            [this.tokenDetails.investorInfo, ...args],
        )
    }

    private buildSetPTB(signer: string, func: string, args: any[], argTypes?: any[]) {
        return SuiClient.getMoveCallBytes({
            signer,
            target: this.getTarget(func),
            typeArgs: [this.tokenAddress],
            args: [
                this.tokenDetails.investorInfo,
                this.tokenDetails.auth,
                ...args,
                Config.vars.VERSION
            ],
            argTypes
        })
    }

    // ==== View Functions ====

    /// Returns whether the given wallet is a platform wallet
    async isPlatformWallet(wallet: string, sender: string) {
        const ptb = this.buildGetPTB('is_platform_wallet', [wallet])
        return SuiClient.devInspectBool(ptb, sender)
    }

    /// Returns whether the given wallet is an issuer wallet
    async isIssuerWallet(wallet: string, sender: string) {
        const ptb = this.buildGetPTB('is_issuer_wallet', [wallet])
        return SuiClient.devInspectBool(ptb, sender)
    }

    // ==== Setter Functions ====

    /// Adds a wallet address as an issuer wallet
    async addIssuerWallet(wallet: string, signer: string) {
        return this.buildSetPTB(signer, 'add_issuer_wallet', [wallet])
    }

    /// Adds a wallet address as a platform wallet
    async addPlatformWallet(wallet: string, signer: string) {
        return this.buildSetPTB(signer, 'add_platform_wallet', [wallet])
    }

    /// Removes a special wallet from the registry
    async removeSpecialWallet(wallet: string, signer: string) {
        return this.buildSetPTB(signer, 'remove_special_wallet', [wallet])
    }
}
