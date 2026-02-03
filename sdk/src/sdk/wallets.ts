import {SuiClient} from "../easysui";
import {Config} from "./utils/config";
import {getTokenDetails} from "./token";
import {Transaction} from "@mysten/sui/transactions";

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

    private buildSetPTB(func: string, args: any[], ptb?: Transaction) {
        return SuiClient.getPTB(
            this.getTarget(func),
            [this.tokenAddress],
            [
                this.tokenDetails.investorInfo,
                this.tokenDetails.auth,
                ...args,
                Config.vars.VERSION
            ],
            [],
            undefined,
            false,
            ptb
        )
    }

    private buildSetBytes(ptb: Transaction, signer: string) {
        return SuiClient.getMoveCallBytesFromPTB(ptb, signer)
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

    /// Adds a wallet address as an issuer wallet (PTB version)
    addIssuerWalletPTB = (wallet: string, ptb?: Transaction) => this.buildSetPTB('add_issuer_wallet', [Config.vars.PAS_NAMESPACE, wallet], ptb)

    /// Adds a wallet address as an issuer wallet
    async addIssuerWallet(wallet: string, signer: string) {
        const ptb = this.addIssuerWalletPTB(wallet)
        return this.buildSetBytes(ptb, signer)
    }

    /// Adds a wallet address as a platform wallet (PTB version)
    addPlatformWalletPTB = (wallet: string, ptb?: Transaction) => this.buildSetPTB('add_platform_wallet', [Config.vars.PAS_NAMESPACE, wallet], ptb)

    /// Adds a wallet address as a platform wallet
    async addPlatformWallet(wallet: string, signer: string) {
        const ptb = this.addPlatformWalletPTB(wallet)
        return this.buildSetBytes(ptb, signer)
    }

    /// Removes a special wallet from the registry (PTB version)
    removeSpecialWalletPTB = (wallet: string, ptb?: Transaction) => this.buildSetPTB('remove_special_wallet', [wallet], ptb)

    /// Removes a special wallet from the registry
    async removeSpecialWallet(wallet: string, signer: string) {
        const ptb = this.removeSpecialWalletPTB(wallet)
        return this.buildSetBytes(ptb, signer)
    }
}
