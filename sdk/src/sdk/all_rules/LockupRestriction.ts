import { Rule } from './Rule'
import { SuiClient } from '../../easysui'
import { newPTBDetails, PTBDetails } from '../domains'
import { Config } from '../utils/config'
import { Transaction } from '@mysten/sui/transactions'
import { bcs } from '@mysten/sui/bcs'

export class LockupRestriction extends Rule {
    constructor(tokenAddress: string) {
        super(tokenAddress, 'LockupRestriction', 'lockup_restriction')
    }

    // ==== View Functions ====

    async computeTransferableTokens(
        investorId: string,
        timestampMs: number,
        sender: string
    ): Promise<bigint> {
        const ptb = new Transaction()
        const timestampMsArg = ptb.pure.u64(timestampMs)
        const investorIdArg = ptb.pure.string(investorId)
        const investorInfo = ptb.object(this.tokenDetails.investorInfo)
        const complianceConfig = ptb.object(this.tokenDetails.complianceConfig)
        const ruleTypeArg = `${Config.vars.PACKAGE_ID}::lockup_restriction::LockupRestriction`

        const country = ptb.moveCall({
            target: `${Config.vars.PACKAGE_ID}::registry_service::get_country`,
            typeArguments: [this.tokenAddress],
            arguments: [investorInfo, investorIdArg],
        })

        const region = ptb.moveCall({
            target: `${Config.vars.PACKAGE_ID}::registry_service::get_country_compliance`,
            typeArguments: [this.tokenAddress],
            arguments: [investorInfo, country],
        })

        const balance = ptb.moveCall({
            target: `${Config.vars.PACKAGE_ID}::registry_service::investor_wallet_balance_total`,
            typeArguments: [this.tokenAddress],
            arguments: [investorInfo, investorIdArg],
        })

        const transferableBalance = ptb.moveCall({
            target: `${Config.vars.PACKAGE_ID}::lock_manager::compute_transferable`,
            typeArguments: [this.tokenAddress],
            arguments: [investorInfo, investorIdArg, balance, timestampMsArg],
        })

        const rule = ptb.moveCall({
            target: `${Config.vars.PACKAGE_ID}::compliance_service::borrow_rule`,
            typeArguments: [this.tokenAddress, ruleTypeArg],
            arguments: [complianceConfig],
        })

        const issuances = ptb.moveCall({
            target: `${Config.vars.PACKAGE_ID}::registry_service::get_investor_issuances`,
            typeArguments: [this.tokenAddress],
            arguments: [investorInfo, investorIdArg],
        })

        ptb.moveCall({
            target: `${Config.vars.PACKAGE_ID}::lockup_restriction::compute_transferable_tokens`,
            arguments: [rule, issuances, region, transferableBalance, timestampMsArg],
        })

        const result = await SuiClient.devInspect(ptb, sender)

        const commandCount = result.commandResults?.length ?? 0
        const value = result.commandResults?.[commandCount - 1]?.returnValues?.[0]?.bcs
        if (!value) {
            throw new Error('computeTransferableTokens received empty result')
        }
        return BigInt(bcs.u64().parse(new Uint8Array(value)))
    }

    // ==== Registration ====

    registerPTB(
        usLockPeriodMs?: number,
        nonUsLockPeriodMs?: number,
        ptbDetails?: PTBDetails
    ) {
        ptbDetails ??= newPTBDetails()
        const ptb = ptbDetails.ptb

        const rule = this.newRule(
            ptb,
            [ptb.pure.u64(usLockPeriodMs || 0), ptb.pure.u64(nonUsLockPeriodMs || 0)],
            ptbDetails
        )

        return this._registerPTB(rule, ptbDetails)
    }

    async register(signer: string, usLockPeriodMs?: number, nonUsLockPeriodMs?: number) {
        const ptb = this.registerPTB(usLockPeriodMs, nonUsLockPeriodMs)
        return SuiClient.getMoveCallBytesFromPTB(ptb, signer)
    }

    // ==== Setters ====

    setUsLockPeriodPTB(periodMs?: number, ptbDetails?: PTBDetails) {
        if (periodMs === undefined) {
            return
        }
        ptbDetails ??= newPTBDetails()
        return this.setRule('set_us_lock_period', [ptbDetails.ptb.pure.u64(periodMs)], ptbDetails)
    }

    setUsLockPeriod(periodMs: number, signer: string) {
        const ptb = this.setUsLockPeriodPTB(periodMs)!
        return SuiClient.getMoveCallBytesFromPTB(ptb, signer)
    }

    setNonUsLockPeriodPTB(periodMs?: number, ptbDetails?: PTBDetails) {
        if (periodMs === undefined) {
            return
        }
        ptbDetails ??= newPTBDetails()
        return this.setRule(
            'set_non_us_lock_period',
            [ptbDetails.ptb.pure.u64(periodMs)],
            ptbDetails
        )
    }

    setNonUsLockPeriod(periodMs: number, signer: string) {
        const ptb = this.setNonUsLockPeriodPTB(periodMs)!
        return SuiClient.getMoveCallBytesFromPTB(ptb, signer)
    }
}
