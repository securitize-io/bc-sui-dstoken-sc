import {ADMIN_KEYPAIR, PublishSingleton} from "../easysui";
import {Config} from "./utils/config";

export async function deployPas() {
    const resp = await PublishSingleton.publishPackage(ADMIN_KEYPAIR!, '../move/pas')
    const packageId = PublishSingleton.findPublishedPackageId(resp)
    const upgradeCap = PublishSingleton.findUpgradeCapId(resp)
    const pasNamespace = PublishSingleton.findObjectIdByType(`${packageId}::namespace::Namespace`, true, resp)

    const vars = Config.vars
    const newConfig = {
        ...vars,
        PAS_PACKAGE_ID: packageId,
        PAS_UPGRADE_CAP_ID: upgradeCap,
        PAS_NAMESPACE: pasNamespace,
    }

    Config.write(newConfig)
}
