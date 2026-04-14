import {SuiClient} from "../easysui";
import {Config} from "./utils/config";
import {getTokenDetails, TokenDetails} from "./token";
import {newPTBDetails, PTBDetails} from "./domains";
import {Transaction} from "@mysten/sui/transactions";
import * as walletManager from "../generated/securitize/wallet_manager";

export class Wallets {
    private readonly tokenAddress: string;
    private readonly tokenDetails: TokenDetails;

    constructor(tokenAddress: string) {
        this.tokenAddress = tokenAddress;
        this.tokenDetails = getTokenDetails(tokenAddress);
    }

    // ==== View Functions ====

    /** Returns whether a wallet is registered as a platform wallet. */
    async isPlatformWallet(wallet: string, sender: string) {
        return SuiClient.devInspectBool(this.buildView(walletManager.isPlatformWallet, { wallet }), sender)
    }

    async isIssuerWallet(wallet: string, sender: string) {
        return SuiClient.devInspectBool(this.buildView(walletManager.isIssuerWallet, { wallet }), sender)
    }

    // ==== Issuer Wallet Management ====

    addIssuerWalletPTB = (wallet: string, ptbDetails?: PTBDetails) => {
        ptbDetails ??= newPTBDetails()
        const ptb = ptbDetails.ptb
        walletManager.addIssuerWallet({
            package: this.pkg,
            arguments: {
                investorInfo: ptbDetails.tokenDetails?.investorInfo || this.tokenDetails.investorInfo,
                auth: ptbDetails.tokenDetails?.auth || this.tokenDetails.auth,
                namespace: Config.vars.PAS_NAMESPACE,
                wallet,
                version: Config.vars.VERSION,
            },
            typeArguments: this.typeArgs,
        })(ptb)
        return ptb
    }

    /** Registers a wallet as an issuer wallet with a PAS account. */
    async addIssuerWallet(wallet: string, signer: string) {
        return SuiClient.getMoveCallBytesFromPTB(this.addIssuerWalletPTB(wallet), signer)
    }

    // ==== Platform Wallet Management ====

    addPlatformWalletPTB = (wallet: string, ptbDetails?: PTBDetails) => {
        ptbDetails ??= newPTBDetails()
        const ptb = ptbDetails.ptb
        walletManager.addPlatformWallet({
            package: this.pkg,
            arguments: {
                investorInfo: ptbDetails.tokenDetails?.investorInfo || this.tokenDetails.investorInfo,
                auth: ptbDetails.tokenDetails?.auth || this.tokenDetails.auth,
                namespace: Config.vars.PAS_NAMESPACE,
                wallet,
                version: Config.vars.VERSION,
            },
            typeArguments: this.typeArgs,
        })(ptb)
        return ptb
    }

    /** Registers a wallet as a platform wallet (exempt from most compliance rules). */
    async addPlatformWallet(wallet: string, signer: string) {
        return SuiClient.getMoveCallBytesFromPTB(this.addPlatformWalletPTB(wallet), signer)
    }

    // ==== Remove Special Wallet ====

    removeSpecialWalletPTB = (wallet: string, ptbDetails?: PTBDetails) => {
        ptbDetails ??= newPTBDetails()
        const ptb = ptbDetails.ptb
        walletManager.removeSpecialWallet({
            package: this.pkg,
            arguments: {
                investorInfo: ptbDetails.tokenDetails?.investorInfo || this.tokenDetails.investorInfo,
                auth: ptbDetails.tokenDetails?.auth || this.tokenDetails.auth,
                wallet,
                version: Config.vars.VERSION,
            },
            typeArguments: this.typeArgs,
        })(ptb)
        return ptb
    }

    /** Removes a special wallet (issuer or platform) designation. */
    async removeSpecialWallet(wallet: string, signer: string) {
        return SuiClient.getMoveCallBytesFromPTB(this.removeSpecialWalletPTB(wallet), signer)
    }

    // ==== Private Helpers ====

    private get pkg() { return Config.vars.PACKAGE_ID }
    private get typeArgs(): [string] { return [this.tokenAddress] }

    private buildView(fn: Function, extraArgs: Record<string, any> = {}): Transaction {
        const ptb = new Transaction()
        fn({ package: this.pkg, arguments: { investorInfo: this.tokenDetails.investorInfo, ...extraArgs }, typeArguments: this.typeArgs })(ptb)
        return ptb
    }
}
