import { Investors } from './investors'
import { Investor } from './domains'
import { Bulk } from './Bulk'
import { Transaction } from '@mysten/sui/transactions'
import { Keypair } from '@mysten/sui/cryptography'

export class InvestorsBulk extends Bulk {
    private investors: Investors

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
            this.investors.registerInvestorIfNotExistsPTB(investor.id, ptb)
            this.investors.updateInvestorPTB(
                investor.id,
                investor.country,
                investor.wallet ? [investor.wallet] : [],
                investor.attributes || [],
                ptb
            )
            // this.investors.addWalletPTB(investor.id, investor.wallet, ptb)
        }
    }

    // ==== View Functions ====

    // remove the view functions and use the investors class directly

    async getTotalInvestorsCount(signer: string) {
        return this.investors.getTotalInvestorsCount(signer)
    }

    async getInvestorDetails(investorId: string) {
        return this.investors.getInvestorDetails(investorId)
    }

    async isInvestor(investorId: string, signer: string) {
        return this.investors.isInvestor(investorId, signer)
    }
}
