import {DSToken} from "./DSToken";
import {TokenIssue} from "./domains";
import {Bulk} from "./Bulk";
import {Transaction} from "@mysten/sui/transactions";
import {Keypair} from "@mysten/sui/cryptography";

export class DSTokenBulk extends Bulk {
    private dsToken: DSToken;

    constructor(tokenAddress: string) {
        super(141);
        this.dsToken = new DSToken(tokenAddress);
    }

    async issueBulk(tokenIssues: TokenIssue[], signer: string) {
        return this.bulkCall(tokenIssues, signer, this.getIssuePTBs())
    }

    async issueExecution(tokenIssues: TokenIssue[], signer: Keypair) {
        return this.bulkExecution(tokenIssues, signer, this.getIssuePTBs())
    }

    private getIssuePTBs() {
        return (tokenIssue: TokenIssue, ptb: Transaction) => {
            this.dsToken.issuePTB(tokenIssue.to, BigInt(tokenIssue.value), [], [], ptb);
        };
    }

    async burnBulk(tokenIssues: TokenIssue[], signer: string) {
        return this.bulkCall(tokenIssues, signer, this.getBurnTBs())
    }

    async burnExecution(tokenIssues: TokenIssue[], signer: Keypair) {
        return this.bulkExecution(tokenIssues, signer, this.getBurnTBs())
    }

    private getBurnTBs() {
        return (tokenIssue: TokenIssue, ptb: Transaction) => {
            this.dsToken.burnPTB(tokenIssue.to, BigInt(tokenIssue.value), "", ptb);
        };
    }
}
