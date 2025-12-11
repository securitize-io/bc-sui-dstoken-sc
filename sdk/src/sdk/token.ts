import {deriveObjectID} from "@mysten/sui/utils";
import {Config} from "./utils/config";
import {bcs} from "@mysten/sui/bcs";

export interface TokenDetails {
    investorInfo: string
    auth: string
}

export function getDerivedObjectId(
    parentId: string,
    module: string,
    key: string,
    tokenAddress: string
) {
    const keyU8 = bcs.struct(key, { dummy_value: bcs.bool() }).serialize({ dummy_value: false }).toBytes();
    return deriveObjectID(parentId, `${Config.vars.PACKAGE_ID}::${module}::${key}<${tokenAddress}>`, keyU8)
}

export function getTokenDetails(tokenAddress: string): TokenDetails {
    const parentId = Config.vars.SETUP_REGISTRY;
    const investorInfo = getDerivedObjectId(parentId, "registry_service", "RegistryServiceKey", tokenAddress)
    const auth = getDerivedObjectId(parentId, "trust_service", "TrustServiceKey", tokenAddress)

    return {
        investorInfo,
        auth
    }
}