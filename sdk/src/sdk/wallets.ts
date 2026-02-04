import {SuiClient} from "../easysui";
import {Config} from "./utils/config";
import {getTokenDetails} from "./token";
import {newPTBDetails, PTBDetails} from "./domains";
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

    private buildSetBytes(ptb: Transaction, signer: string) {
        return SuiClient.getMoveCallBytesFromPTB(ptb, signer)
    }

    /**
     * Helper function to build wallet PTB calls with PAS_NAMESPACE
     * Handles both deployment (using ptbDetails.tokenDetails) and post-deployment (using derived IDs)
     */
    private buildWalletPTB(func: string, wallet: string, ptbDetails?: PTBDetails) {
        ptbDetails ??= newPTBDetails()
        const ptb = ptbDetails.ptb
        return this.buildWalletPTBSimple(func, wallet, ptbDetails, [ptb.object(Config.vars.PAS_NAMESPACE)])
    }

    /**
     * Helper function to build wallet PTB calls without PAS_NAMESPACE
     */
    private buildWalletPTBSimple(func: string, wallet: string, ptbDetails?: PTBDetails, args: any[] = []) {
        ptbDetails ??= newPTBDetails()
        const ptb = ptbDetails.ptb
        ptb.moveCall({
            target: this.getTarget(func),
            typeArguments: [this.tokenAddress],
            arguments: [
                ptbDetails.tokenDetails?.investorInfo || ptb.object(this.tokenDetails.investorInfo),
                ptbDetails.tokenDetails?.auth || ptb.object(this.tokenDetails.auth),
                ...args,
                ptb.pure.address(wallet),
                ptb.object(Config.vars.VERSION),
            ],
        })
        return ptb
    }

    // ==== View Functions ====

    async isPlatformWallet(wallet: string, sender: string) {
        const ptb = this.buildGetPTB('is_platform_wallet', [wallet])
        return SuiClient.devInspectBool(ptb, sender)
    }

    async isIssuerWallet(wallet: string, sender: string) {
        const ptb = this.buildGetPTB('is_issuer_wallet', [wallet])
        return SuiClient.devInspectBool(ptb, sender)
    }

    // ==== Setter Functions ====

    addIssuerWalletPTB = (wallet: string, ptbDetails?: PTBDetails) =>
        this.buildWalletPTB('add_issuer_wallet', wallet, ptbDetails)

    async addIssuerWallet(wallet: string, signer: string) {
        return this.buildSetBytes(this.addIssuerWalletPTB(wallet), signer)
    }

    addPlatformWalletPTB = (wallet: string, ptbDetails?: PTBDetails) =>
        this.buildWalletPTB('add_platform_wallet', wallet, ptbDetails)

    async addPlatformWallet(wallet: string, signer: string) {
        return this.buildSetBytes(this.addPlatformWalletPTB(wallet), signer)
    }

    removeSpecialWalletPTB = (wallet: string, ptbDetails?: PTBDetails) =>
        this.buildWalletPTBSimple('remove_special_wallet', wallet, ptbDetails)

    async removeSpecialWallet(wallet: string, signer: string) {
        return this.buildSetBytes(this.removeSpecialWalletPTB(wallet), signer)
    }
}
