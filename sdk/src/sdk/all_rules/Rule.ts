import {ADMIN_ADDRESS, SuiClient} from "../../easysui";
import {Config} from "../utils/config";
import {getTokenDetails, TokenDetails} from "../token";
import {Transaction, TransactionResult} from "@mysten/sui/transactions";
import {newPTBDetails, PTBDetails} from "../domains";

export class Rule {
    protected readonly tokenAddress: string;
    protected readonly tokenDetails: TokenDetails;
    private readonly ruleType: string;
    private readonly ruleModule: string;

    constructor(tokenAddress: string, ruleType: string, ruleModule: string) {
        this.tokenAddress = tokenAddress;
        this.tokenDetails = getTokenDetails(tokenAddress);
        this.ruleType = ruleType
        this.ruleModule = ruleModule
    }

    // ==== View Functions ====

    async exists(sender?: string, _ptbDetails?: PTBDetails): Promise<boolean> {
        sender ??= ADMIN_ADDRESS
        try {
            // Always use a fresh PTB with string object IDs for devInspect.
            // NestedResult references from a deployment PTB can't be used
            // in a separate devInspect transaction.
            const inspectDetails = newPTBDetails()
            const ptb = this.buildGetPTB('has_rule', [], inspectDetails)
            const result = await SuiClient.devInspectBool(ptb, sender)
            return result ?? false
        } catch (e: any) {
            // Object may not exist on-chain yet (e.g. during first deployment)
            const msg = e?.message || ''
            if (msg.includes('not found') || msg.includes('not%20found') || msg.includes('abort')) {
                return false
            }
            throw e
        }
    }

    // ==== Rule Management ====

    async unregister(signer: string) {
        return this.buildSetPTB(signer, 'unregister_rule')
    }

    // ==== Protected Helpers ====

    protected newRule(ptb: Transaction, args: any[], ptbDetails: PTBDetails) {
        return ptb.moveCall({
            target: this.getRuleTarget('new'),
            typeArguments: [this.tokenAddress],
            arguments: [
                ptbDetails.tokenDetails?.auth || ptb.object(this.tokenDetails.auth),
                ...args,
                ptb.object(Config.vars.VERSION)
            ],
        })
    }

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

    // ==== Private Helpers ====

    private get ruleTypeArg() {
        return `${Config.vars.PACKAGE_ID}::${this.ruleModule}::${this.ruleType}`
    }

    private getComplianceTarget(func: string) {
        return `${Config.vars.PACKAGE_ID}::compliance_service::${func}`
    }

    private getRuleTarget(func: string) {
        return `${Config.vars.PACKAGE_ID}::${this.ruleModule}::${func}`
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
}
