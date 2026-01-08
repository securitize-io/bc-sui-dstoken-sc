import {Config as BaseConfig, BaseConfigVars, ExtraVarsMap} from '../../easysui'

interface ConfigVars extends BaseConfigVars {
    SETUP_REGISTRY: string,
    VERSION: string,
    PAS_PACKAGE_ID: string,
    PAS_NAMESPACE: string,

}

export class Config extends BaseConfig<ConfigVars> {
    static override get vars(): ConfigVars {
        const baseVars = super.vars

        return {
            ...baseVars,
            SETUP_REGISTRY: process.env.SETUP_REGISTRY || '',
            VERSION: process.env.VERSION || '',
            PAS_PACKAGE_ID: process.env.PACKAGE_ID!, // TODO: change this to process.env.PAS_PACKAGE_ID
            PAS_NAMESPACE: process.env.PAS_NAMESPACE || '',
        }
    }

    static override get extraVars(): ExtraVarsMap {
        return {
            SETUP_REGISTRY: "{packageId}::setup::SetupRegistry",
            VERSION: "{packageId}::version::Version",
            PAS_NAMESPACE: "{packageId}::namespace::Namespace",
        }
    }
}