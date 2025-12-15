import {SuiClient} from "../../easysui";
import {Config} from "../utils/config";
import {getTokenDetails} from "../token";
import {Transaction, TransactionResult} from "@mysten/sui/transactions";
import {PTBDetails} from "../domains/PTBDetails";

export class Rule {
    private readonly tokenAddress: string;
    private readonly ruleType: string;
    private readonly ruleModule: string;
    private readonly tokenDetails: any;

    constructor(tokenAddress: string, ruleType: string, ruleModule: string) {
        this.tokenAddress = tokenAddress;
        this.tokenDetails = getTokenDetails(tokenAddress);
        this.ruleType = ruleType
        this.ruleModule = ruleModule
    }

    private getComplianceTarget(func: string) {
        return `${Config.vars.PACKAGE_ID}::compliance_service::${func}`
    }

    private getTargetNew() {
        return `${Config.vars.PACKAGE_ID}::${this.ruleModule}::new`
    }

    protected newRule(ptb: Transaction, args: any[]) {
        return ptb.moveCall({
            target: this.getTargetNew(),
            arguments: [
                ...args,
                ptb.object(Config.vars.VERSION)
            ],
        })
    }

    private buildGetPTB(func: string, args: any[] = []) {
        const ruleTypeArg = `${Config.vars.PACKAGE_ID}::${this.ruleModule}::${this.ruleType}`
        return SuiClient.getPTB(
            this.getComplianceTarget(func),
            [this.tokenAddress, ruleTypeArg],
            [this.tokenDetails.complianceConfig, ...args],
        )
    }

    private buildSetPTB(signer: string, func: string, args: any[] = []) {
        const ruleTypeArg = `${Config.vars.PACKAGE_ID}::${this.ruleModule}::${this.ruleType}`

        return SuiClient.getMoveCallBytes({
            signer,
            target: this.getComplianceTarget(func),
            typeArgs: [this.tokenAddress, ruleTypeArg],
            args: [
                this.tokenDetails.complianceConfig,
                this.tokenDetails.auth,
                ...args,
                Config.vars.VERSION
            ],
        })
    }

    // ==== View Functions ====

    async exists(sender: string): Promise<boolean> {
        const ptb = this.buildGetPTB('has_rule')
        const result = await SuiClient.devInspectBool(ptb, sender)
        return result ?? false
    }

    // ==== Rule Management Functions ====

    protected _registerPTB(rule: TransactionResult, ptbDetails: PTBDetails) {
        const ptb = ptbDetails.ptb

        ptb.moveCall({
            target: this.getComplianceTarget('register_rule'),
            typeArguments: [
                this.tokenAddress,
                `${Config.vars.PACKAGE_ID}::${this.ruleModule}::${this.ruleType}`
            ],
            arguments: [
                ptbDetails.tokenDetails?.complianceConfig || ptb.object(this.tokenDetails.complianceConfig),
                ptbDetails.tokenDetails?.auth || ptb.object(this.tokenDetails.auth),
                rule,
                ptb.object(Config.vars.VERSION),
            ],
        })

        return ptb
    }

    async unregister(signer: string) {
        return this.buildSetPTB(signer, 'unregister_rule')
    }
}
