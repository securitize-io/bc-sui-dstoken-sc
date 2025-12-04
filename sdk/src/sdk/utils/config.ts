import {Config as BaseConfig, BaseConfigVars, ExtraVarsMap} from '@easysui/sdk'

interface ConfigVars extends BaseConfigVars {
    SETUP_AUTH: string
}

export class Config extends BaseConfig<ConfigVars> {
    static override get vars(): ConfigVars {
        const baseVars = super.vars

        return {
            ...baseVars,
            SETUP_AUTH: process.env.SETUP_AUTH || '',
        }
    }

    static override get extraVars(): ExtraVarsMap {
        return {
            SETUP_AUTH: "{packageId}::setup::SetupAuth"
        }
    }
}