import {ADMIN_KEYPAIR, PublishSingleton} from "../easysui";

export async function deployPas() {
    // Publish ptb first (pas depends on it)
    await PublishSingleton.publishPackage(ADMIN_KEYPAIR!, '../move/pas/packages/ptb')
    const resp = await PublishSingleton.publishPackage(ADMIN_KEYPAIR!, '../move/pas/packages/pas')

    const packageId = PublishSingleton.findPublishedPackageId(resp)
    const upgradeCap = PublishSingleton.findUpgradeCapId(resp)
    const pasNamespace = PublishSingleton.findObjectIdByType(`${packageId}::namespace::Namespace`, true, resp)

    return {
        PAS_PACKAGE_ID: packageId,
        PAS_UPGRADE_CAP_ID: upgradeCap,
        PAS_NAMESPACE: pasNamespace,
    }
}
