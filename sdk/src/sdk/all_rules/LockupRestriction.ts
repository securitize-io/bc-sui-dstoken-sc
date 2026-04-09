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

        // 1. get_country
        const country = ptb.moveCall({
            target: `${Config.vars.PACKAGE_ID}::registry_service::get_country`,
            typeArguments: [this.tokenAddress],
            arguments: [investorInfo, investorIdArg],
        })

        // 2. get_country_compliance → region
        const region = ptb.moveCall({
            target: `${Config.vars.PACKAGE_ID}::registry_service::get_country_compliance`,
            typeArguments: [this.tokenAddress],
            arguments: [investorInfo, country],
        })

        // 3. investor_wallet_balance_total → raw balance
        const balance = ptb.moveCall({
            target: `${Config.vars.PACKAGE_ID}::registry_service::investor_wallet_balance_total`,
            typeArguments: [this.tokenAddress],
            arguments: [investorInfo, investorIdArg],
        })

        // 4. lock_manager::compute_transferable → transferable balance (after full locks + lock records)
        const transferableBalance = ptb.moveCall({
            target: `${Config.vars.PACKAGE_ID}::lock_manager::compute_transferable`,
            typeArguments: [this.tokenAddress],
            arguments: [investorInfo, investorIdArg, balance, timestampMsArg],
        })

        // 5. borrow_rule<T, LockupRestriction> → rule reference
        const rule = ptb.moveCall({
            target: `${Config.vars.PACKAGE_ID}::compliance_service::borrow_rule`,
            typeArguments: [this.tokenAddress, ruleTypeArg],
            arguments: [complianceConfig],
        })

        // 6. get_investor_issuances → issuances reference
        const issuances = ptb.moveCall({
            target: `${Config.vars.PACKAGE_ID}::registry_service::get_investor_issuances`,
            typeArguments: [this.tokenAddress],
            arguments: [investorInfo, investorIdArg],
        })

        // 7. compute_transferable_tokens(rule, issuances, region, transferable_balance, timestamp_ms) → u64
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

    registerPTB(
        us_lock_period_ms?: number,
        non_us_lock_period_ms?: number,
        ptbDetails?: PTBDetails
    ) {
        ptbDetails ??= newPTBDetails()
        const ptb = ptbDetails.ptb

        const rule = this.newRule(
            ptb,
            [ptb.pure.u64(us_lock_period_ms || 0), ptb.pure.u64(non_us_lock_period_ms || 0)],
            ptbDetails
        )

        return this._registerPTB(rule, ptbDetails)
    }

    async register(signer: string, us_lock_period_ms?: number, non_us_lock_period_ms?: number) {
        const ptb = this.registerPTB(us_lock_period_ms, non_us_lock_period_ms)
        return SuiClient.getMoveCallBytesFromPTB(ptb, signer)
    }

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
