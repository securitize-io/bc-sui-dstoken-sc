import {ADMIN_KEYPAIR, SuiClient} from "../../easysui";
import {Config} from "../utils/config";
import {getTokenDetails} from "../token";
import {Transaction, TransactionResult} from "@mysten/sui/transactions";
import {newPTBDetails, PTBDetails} from "../domains";

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

    private getRuleTarget(func: string) {
        return `${Config.vars.PACKAGE_ID}::${this.ruleModule}::${func}`
    }

    protected newRule(ptb: Transaction, args: any[], ptbDetails: PTBDetails) {
        return ptb.moveCall({
            target: this.getRuleTarget('new'),
            typeArguments: [
                this.tokenAddress
            ],
            arguments: [
                ptbDetails.tokenDetails?.auth || ptb.object(this.tokenDetails.auth),
                ...args,
                ptb.object(Config.vars.VERSION)
            ],
        })
    }

    private get ruleTypeArg() {
        return `${Config.vars.PACKAGE_ID}::${this.ruleModule}::${this.ruleType}`
    }

    private buildGetPTB(func: string, args: any[] = [], ptbDetails: PTBDetails) {
        return SuiClient.getPTB(
            this.getComplianceTarget(func),
            [this.tokenAddress, this.ruleTypeArg],
            [
                ptbDetails.tokenDetails?.complianceConfig || this.tokenDetails.complianceConfig,
                ...args
            ],
        )
    }

    private buildSetPTB(signer: string, func: string, args: any[] = []) {
        return SuiClient.getMoveCallBytes({
            signer,
            target: this.getComplianceTarget(func),
            typeArgs: [this.tokenAddress, this.ruleTypeArg],
            args: [
                this.tokenDetails.complianceConfig,
                this.tokenDetails.auth,
                ...args,
                Config.vars.VERSION
            ],
        })
    }

    // ==== View Functions ====

    async exists(sender?: string, ptbDetails?: PTBDetails): Promise<boolean> {
        sender ??= ADMIN_KEYPAIR!.toSuiAddress()
        ptbDetails ??= newPTBDetails()
        const ptb = this.buildGetPTB('has_rule', [], ptbDetails)
        const result = await SuiClient.devInspectBool(ptb, sender)
        return result ?? false
    }

    private getRule(ptbDetails: PTBDetails) {
        const ptb = ptbDetails.ptb
        return ptb.moveCall({
            target: this.getComplianceTarget('get_rule'),
            typeArguments: [this.tokenAddress, this.ruleTypeArg],
            arguments: [
                ptbDetails.tokenDetails?.complianceConfig || ptb.object(this.tokenDetails.complianceConfig),
                ptbDetails.tokenDetails?.auth || ptb.object(this.tokenDetails.auth),
                ptb.object(Config.vars.VERSION),
            ]
        })
    }

    private returnRule(rule: TransactionResult, ptbDetails: PTBDetails) {
        const ptb = ptbDetails.ptb
        return ptb.moveCall({
            target: this.getComplianceTarget('return_rule'),
            typeArguments: [this.tokenAddress, this.ruleTypeArg],
            arguments: [
                ptbDetails.tokenDetails?.complianceConfig || ptb.object(this.tokenDetails.complianceConfig),
                ptbDetails.tokenDetails?.auth || ptb.object(this.tokenDetails.auth),
                rule,
                ptb.object(Config.vars.VERSION),
            ]
        })
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

    protected setRule(func: string, args: any[], ptbDetails: PTBDetails) {
        const ptb = ptbDetails.ptb

        const rule = this.getRule(ptbDetails);
        ptb.moveCall({
            target: this.getRuleTarget(func),
            typeArguments: [this.tokenAddress],
            arguments: [
                ptbDetails.tokenDetails?.auth || ptb.object(this.tokenDetails.auth),
                rule,
                ...args,
                ptb.object(Config.vars.VERSION),
            ]
        })
        this.returnRule(rule, ptbDetails)

        return ptb
    }
}
