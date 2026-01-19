import {Investors} from "./investors";
import {Investor} from "./domains";
import {Transaction} from "@mysten/sui/transactions";
import {DSToken} from "./DSToken";
import {SuiClient} from "../easysui";

export class CombinedIssuance {
    private investors: Investors
    private dsToken: DSToken

    constructor(tokenAddress: string) {
        this.investors = new Investors(tokenAddress)
        this.dsToken = new DSToken(tokenAddress)
    }

    registerPTB(investor: Investor, ptb?: Transaction) {
        ptb ??= new Transaction()

        this.investors.registerInvestorPTB(investor.id, ptb)
        this.investors.updateInvestorPTB(
            investor.id,
            investor.country,
            [investor.wallet],
            investor.attributes || [],
            ptb
        )
        const lock = investor.lock;
        this.dsToken.issueNoVaultPTB(
            investor.wallet,
            BigInt(investor.value),
            lock?.value ? [BigInt(lock?.value)] : [],
            lock?.releaseTime ? [lock?.releaseTime] : [],
            investor.issuanceTime,
            ptb
        )

        return ptb
    }

    async register(investor: Investor, signer: string) {
        const ptb = this.registerPTB(investor)
        return SuiClient.getMoveCallBytesFromPTB(ptb, signer)
    }
}
