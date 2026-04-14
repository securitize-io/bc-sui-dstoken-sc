import {Investors} from "./investors";
import {Investor} from "./domains";
import {Bulk} from "./Bulk";
import {Transaction} from "@mysten/sui/transactions";
import {Keypair} from "@mysten/sui/cryptography";

export class InvestorsBulk extends Bulk {
    private investors: Investors;

    constructor(tokenAddress: string) {
        super(165)
        this.investors = new Investors(tokenAddress)
    }

    // ==== Register ====

    async register(investors: Investor[], signer: string) {
        return this.bulkCall(investors, signer, this.getBuildOperation())
    }

    async registerBulkBytes(investors: Investor[], signer: string) {
        return this.bulkBytes(investors, signer, this.getBuildOperation())
    }

    async registerExecution(investors: Investor[], signer: Keypair) {
        return this.bulkExecution(investors, signer, this.getBuildOperation())
    }

    // ==== Private Helpers ====

    private getBuildOperation() {
        return (investor: Investor, ptb: Transaction) => {
            this.investors.registerInvestorIfNotExistsPTB(investor.id, ptb);
            this.investors.addWalletPTB(investor.id, investor.wallet, ptb);
        };
    }
}
