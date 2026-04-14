import {DSToken} from "./DSToken";
import {TokenIssue} from "./domains";
import {Bulk} from "./Bulk";
import {Transaction} from "@mysten/sui/transactions";
import {Keypair} from "@mysten/sui/cryptography";
import {BulkTokenBurn, BulkTokenIssue} from "./domains/TokenIssue";

export class DSTokenBulk extends Bulk {
    private dsToken: DSToken;

    constructor(tokenAddress: string) {
        super(141);
        this.dsToken = new DSToken(tokenAddress);
    }

    // ==== Issue ====

    async issueBulk(bulkTokenIssue: BulkTokenIssue) {
        return this.bulkCall(bulkTokenIssue.wallets, bulkTokenIssue.identity, this.getIssuePTBs(bulkTokenIssue.issuanceTime))
    }

    async issueBulkBytes(bulkTokenIssue: BulkTokenIssue, signer: string) {
        return this.bulkBytes(bulkTokenIssue.wallets, signer, this.getIssuePTBs(bulkTokenIssue.issuanceTime))
    }

    async issueExecution(bulkTokenIssue: BulkTokenIssue, signer: Keypair) {
        return this.bulkExecution(bulkTokenIssue.wallets, signer, this.getIssuePTBs(bulkTokenIssue.issuanceTime))
    }

    // ==== Burn ====

    async burnBulk(bulkTokenBurn: BulkTokenBurn) {
        return this.bulkCall(bulkTokenBurn.wallets, bulkTokenBurn.identity, this.getBurnPTBs())
    }

    async burnBulkBytes(bulkTokenBurn: BulkTokenBurn, signer: string) {
        return this.bulkBytes(bulkTokenBurn.wallets, signer, this.getBurnPTBs())
    }

    async burnExecution(bulkTokenBurn: BulkTokenBurn, signer: Keypair) {
        return this.bulkExecution(bulkTokenBurn.wallets, signer, this.getBurnPTBs())
    }

    // ==== Private Helpers ====

    private getIssuePTBs(issuanceTimeMS?: number) {
        issuanceTimeMS ??= new Date().getTime()
        return (tokenIssue: TokenIssue, ptb: Transaction) => {
            this.dsToken.issuePTB(tokenIssue.to, tokenIssue.value, tokenIssue.reasonCode, tokenIssue.reasonString, [], [], issuanceTimeMS, ptb);
        };
    }

    private getBurnPTBs() {
        return (tokenIssue: TokenIssue, ptb: Transaction) => {
            this.dsToken.burnPTB(tokenIssue.to, tokenIssue.value, "", ptb);
        };
    }
}
