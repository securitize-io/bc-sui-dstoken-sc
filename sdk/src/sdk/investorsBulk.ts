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

    async register(investors: Investor[], signer: string) {
        return this.bulkCall(investors, signer, this.getBuildOperation())
    }

    async registerExecution(investors: Investor[], signer: Keypair) {
        return this.bulkExecution(investors, signer, this.getBuildOperation())
    }

    private getBuildOperation() {
        return (investor: Investor, ptb: Transaction) => {
            this.investors.registerInvestorPTB(investor.id, ptb);
            this.investors.addWalletPTB(investor.id, investor.wallet, ptb);
        };
    }
}
