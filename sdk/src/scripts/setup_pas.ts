import { ADMIN_KEYPAIR, SuiClient, MoveType } from '../easysui'
import { Config } from '../sdk/utils/config'

async function setupPas() {
    const pasPackageId = Config.vars.PAS_PACKAGE_ID
    const pasNamespace = Config.vars.PAS_NAMESPACE
    const pasUpgradeCap = process.env.PAS_UPGRADE_CAP

    if (!pasPackageId || !pasNamespace || !pasUpgradeCap) {
        throw new Error('Missing PAS configuration: PAS_PACKAGE_ID, PAS_NAMESPACE, PAS_UPGRADE_CAP')
    }

    if (!ADMIN_KEYPAIR) {
        throw new Error('ADMIN_PRIVATE_KEY not set')
    }

    console.log('Setting up PAS namespace...')
    console.log(`  Package: ${pasPackageId}`)
    console.log(`  Namespace: ${pasNamespace}`)
    console.log(`  UpgradeCap: ${pasUpgradeCap}`)

    await SuiClient.moveCall({
        signer: ADMIN_KEYPAIR,
        target: `${pasPackageId}::namespace::setup`,
        args: [pasNamespace, pasUpgradeCap],
        argTypes: [MoveType.object, MoveType.object],
    })
    console.log('namespace::setup complete')

    await SuiClient.moveCall({
        signer: ADMIN_KEYPAIR,
        target: `${pasPackageId}::templates::setup`,
        args: [pasNamespace],
        argTypes: [MoveType.object],
    })
    console.log('templates::setup complete')

    return 'PAS setup complete'
}

setupPas().then(console.log).catch(console.error)
