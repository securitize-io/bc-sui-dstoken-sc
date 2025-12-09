import {Config as BaseConfig, BaseConfigVars, ExtraVarsMap} from '@easysui/sdk'

interface ConfigVars extends BaseConfigVars {
    SETUP_AUTH: string,
    VERSION: string,
    RWA_REGISTRY: string,

}

export class Config extends BaseConfig<ConfigVars> {
    static override get vars(): ConfigVars {
        const baseVars = super.vars

        return {
            ...baseVars,
            SETUP_AUTH: process.env.SETUP_AUTH || '',
            VERSION: process.env.VERSION || '',
            RWA_REGISTRY: process.env.RWA_REGISTRY || '',
        }
    }

    static override get extraVars(): ExtraVarsMap {
        return {
            SETUP_AUTH: "{packageId}::setup::SetupAuth",
            VERSION: "{packageId}::version::Version",
            RWA_REGISTRY: "{packageId}::registry::RwaRegistry",
        }
    }
}