import dotenv from 'dotenv'
import { Config as BaseConfig, BaseConfigVars, ExtraVarsMap } from '../../easysui'

interface ConfigVars extends BaseConfigVars {
    SETUP_REGISTRY: string
    VERSION: string
    PAS_PACKAGE_ID: string
    PTB_PACKAGE_ID: string
    PAS_NAMESPACE: string
    SECURITIZE_TESTNET_ENV: string
}

export class Config extends BaseConfig<ConfigVars> {
    protected static override _cachedVars: ConfigVars | null = null

    static override invalidateCache(): void {
        super.invalidateCache()
        this._cachedVars = null
    }

    static override get vars(): ConfigVars {
        if (this._cachedVars) {
            return this._cachedVars
        }

        const network = process.env.NETWORK || 'localnet'
        const securitizeEnv = process.env.SECURITIZE_TESTNET_ENV

        // Load securitize-specific env file if on testnet
        if (network === 'testnet' && securitizeEnv && ['testnet_alpha', 'testnet_beta', 'testnet_gamma'].includes(securitizeEnv)) {
            dotenv.config({ path: `.env.${securitizeEnv}`, override: true })
        }

        const baseVars = super.vars

        this._cachedVars = {
            ...baseVars,
            PACKAGE_ID: process.env.PACKAGE_ID || baseVars.PACKAGE_ID,
            UPGRADE_CAP_ID: process.env.UPGRADE_CAP_ID || baseVars.UPGRADE_CAP_ID,
            SETUP_REGISTRY: process.env.SETUP_REGISTRY || '',
            VERSION: process.env.VERSION || '',
            PAS_PACKAGE_ID: process.env.PAS_PACKAGE_ID!,
            PTB_PACKAGE_ID: process.env.PTB_PACKAGE_ID || '',
            PAS_NAMESPACE: process.env.PAS_NAMESPACE || '',
            SECURITIZE_TESTNET_ENV: process.env.SECURITIZE_TESTNET_ENV || '',
        }
        return this._cachedVars
    }

    static override get extraVars(): ExtraVarsMap {
        return {
            SETUP_REGISTRY: '{packageId}::setup::SetupRegistry',
            VERSION: '{packageId}::version::Version',
        }
    }
}
