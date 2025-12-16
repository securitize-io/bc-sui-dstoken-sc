import {Config as BaseConfig, BaseConfigVars, ExtraVarsMap} from '../../easysui'

interface ConfigVars extends BaseConfigVars {
    SETUP_REGISTRY: string,
    VERSION: string,
    RWA_PACKAGE_ID: string,
    RWA_REGISTRY: string,

}

export class Config extends BaseConfig<ConfigVars> {
    static override get vars(): ConfigVars {
        const baseVars = super.vars

        return {
            ...baseVars,
            SETUP_REGISTRY: process.env.SETUP_REGISTRY || '',
            VERSION: process.env.VERSION || '',
            RWA_PACKAGE_ID: process.env.PACKAGE_ID!, // TODO: change this to process.env.RWA_PACKAGE_ID
            RWA_REGISTRY: process.env.RWA_REGISTRY || '',
        }
    }

    static override get extraVars(): ExtraVarsMap {
        return {
            SETUP_REGISTRY: "{packageId}::setup::SetupRegistry",
            VERSION: "{packageId}::version::Version",
            RWA_REGISTRY: "{packageId}::registry::RwaRegistry",
        }
    }
}