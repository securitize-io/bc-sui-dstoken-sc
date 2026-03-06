import {Config as BaseConfig, BaseConfigVars, ExtraVarsMap} from '../../easysui'

interface ConfigVars extends BaseConfigVars {
    SETUP_REGISTRY: string,
    VERSION: string,
    PAS_PACKAGE_ID: string,
    PTB_PACKAGE_ID: string,
    PAS_NAMESPACE: string,
    TEMP_PATH: string,
    SECURITIZE_TESTNET_ENV: string,
}

export class Config extends BaseConfig<ConfigVars> {
    static override get vars(): ConfigVars {
        const baseVars = super.vars

        return {
            ...baseVars,
            SETUP_REGISTRY: process.env.SETUP_REGISTRY || '',
            VERSION: process.env.VERSION || '',
            PAS_PACKAGE_ID: process.env.PAS_PACKAGE_ID!,
            PTB_PACKAGE_ID: process.env.PTB_PACKAGE_ID || '',
            PAS_NAMESPACE: process.env.PAS_NAMESPACE || '',
            TEMP_PATH: process.env.TEMP_PATH || './temp_tokens',
            SECURITIZE_TESTNET_ENV: process.env.SECURITIZE_TESTNET_ENV || '',
        }
    }

    static override get extraVars(): ExtraVarsMap {
        return {
            SETUP_REGISTRY: "{packageId}::setup::SetupRegistry",
            VERSION: "{packageId}::version::Version",
        }
    }
}