import {Investor} from "./domains";
import {Bulk} from "./Bulk";
import {Transaction} from "@mysten/sui/transactions";
import {Keypair} from "@mysten/sui/cryptography";
import {CombinedIssuance} from "./CombinedIssuance";

export class CombinedIssuanceBulk extends Bulk {
    private combinedIssuance: CombinedIssuance

    constructor(tokenAddress: string) {
        super(100)
        this.combinedIssuance = new CombinedIssuance(tokenAddress)
    }

    async register(investors: Investor[], signer: string) {
        return this.bulkCall(investors, signer, this.getBuildOperation())
    }

    async registerExecution(investors: Investor[], signer: Keypair) {
        return this.bulkExecution(investors, signer, this.getBuildOperation())
    }

    private getBuildOperation() {
        return (investor: Investor, ptb: Transaction) => this.combinedIssuance.registerPTB(investor, ptb)
    }
}
