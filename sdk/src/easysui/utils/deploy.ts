import {BaseConfigVars, Config} from '../config/config'
import {PublishSingleton} from './publish'
import {Keypair} from '@mysten/sui/cryptography'

export async function deploy<
    TConfig extends typeof Config = typeof Config,
    TConfigVars extends BaseConfigVars = BaseConfigVars
>(
    ConfigClass: TConfig = Config as TConfig,
    packagePath?: string,
    signer?: Keypair,  // Required for publishing; optional when testnet/mainnet skips publish
): Promise<string> {
    const vars = ConfigClass.vars as TConfigVars
    if (!signer) {
        throw new Error('signer is required for publishing')
    }
    await PublishSingleton.publish(signer, packagePath)

    const newConfig = {
        ...vars,
        PACKAGE_ID: PublishSingleton.packageId,
        UPGRADE_CAP_ID: PublishSingleton.upgradeCapId,
    } as TConfigVars

    // Process extra vars from Config.extraVars
    const extraVars = ConfigClass.extraVars
    if (extraVars && Object.keys(extraVars).length > 0) {
        for (const [key, typePattern] of Object.entries(extraVars)) {
            const type = typePattern.replace('{packageId}', PublishSingleton.packageId)
            // @ts-ignore - dynamically adding properties to config
            newConfig[key] = PublishSingleton.findObjectIdByType(type, true)
        }
    }

    // Use SECURITIZE_TESTNET_ENV for testnet deployments if specified
    const envSuffix = vars.NETWORK === 'testnet' ? process.env.SECURITIZE_TESTNET_ENV : undefined
    ConfigClass.write(newConfig, envSuffix)
    ConfigClass.invalidateCache()

    const envFileName = envSuffix ?? vars.NETWORK
    return `Move contracts deployed successfully on ${vars.NETWORK} contract details have been stored in .env.${envFileName}`
}

export async function getDeployBytes(signer: string) {
    return await PublishSingleton.getPublishBytes(signer)
}
