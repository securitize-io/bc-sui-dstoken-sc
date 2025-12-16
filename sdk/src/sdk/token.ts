import {Config} from "./utils/config";
import {deriveObjectId} from "../easysui";
import {COIN_REGISTRY} from "../easysui/config/config";
import {SUI_FRAMEWORK_ADDRESS} from "@mysten/sui/utils";

export interface TokenDetails {
    investorInfo: string
    auth: string
    complianceConfig: string
    rwaRule: string
    treasury: string
    currency: string
}

export interface TokenDetailsObj {
    investorInfo: { NestedResult: [number, number] },
    auth: { NestedResult: [number, number] },
    complianceConfig: { NestedResult: [number, number] }
}

export function getDerivedObjectId(
    parentId: string,
    module: string,
    key: string,
    tokenAddress: string,
    packageId?: string
) {
    packageId ??= Config.vars.PACKAGE_ID
    return deriveObjectId(parentId, module, key, packageId, tokenAddress)
}

export function getTokenDetails(tokenAddress: string): TokenDetails {
    const parentId = Config.vars.SETUP_REGISTRY;
    const investorInfo = getDerivedObjectId(parentId, "registry_service", "RegistryServiceKey", tokenAddress)
    const auth = getDerivedObjectId(parentId, "trust_service", "TrustServiceKey", tokenAddress)
    const complianceConfig = getDerivedObjectId(parentId, "compliance_service", "ComplianceServiceKey", tokenAddress)
    const rwaRule = getDerivedObjectId(parentId, "rule", "RwaRuleKey", tokenAddress, Config.vars.RWA_PACKAGE_ID)
    const treasury = getDerivedObjectId(parentId, "ds_token", "DsTokenKey", tokenAddress)
    const currency = getDerivedObjectId(COIN_REGISTRY, "coin_registry", "CurrencyKey", tokenAddress, SUI_FRAMEWORK_ADDRESS)

    return {
        investorInfo,
        auth,
        complianceConfig,
        rwaRule,
        treasury,
        currency,
    }
}