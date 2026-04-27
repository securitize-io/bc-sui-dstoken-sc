import { SuiClient } from '../easysui'
import { Keypair } from '@mysten/sui/cryptography'
import { Config } from './utils/config'
import { DeploymentRequest, PTBDetails } from './domains'
import { Transaction } from '@mysten/sui/transactions'
import { normalizeSuiObjectId } from '@mysten/sui/utils'
import { Rules } from './rules'
import { Roles } from './roles'
import { Wallets } from './wallets'
import { CountryCompliance } from './CountryCompliance'
import { getTokenTemplateBytecode, patchTokenTemplate } from './tokenTemplate'
import { PublishSingleton } from '../easysui'
import { COIN_REGISTRY } from '../easysui/config/config'
import { DSToken } from './DSToken'

type DeployedToken = {
    packageId: string
    upgradeCapId: string
    moduleName: string
    structName: string
    /** If create_ds_token was already called, pass the existing cap IDs to skip re-calling it */
    existingCaps?: {
        metadataCapId: string
        treasuryCapId: string
    }
}

// ==== Step 1: Deploy Token Package ====

/**
 * Builds the transaction bytes for publishing the token package.
 * Returns the bytes and the patched module/struct names.
 */
export async function buildDeployTokenBytes(tokenSymbol: string, signer: string) {
    const { bytecode, moduleName, structName } = patchTokenTemplate(
        getTokenTemplateBytecode(),
        tokenSymbol
    )

    const ptb = new Transaction()
    const [upgradeCap] = ptb.publish({
        modules: [Array.from(bytecode)],
        dependencies: [
            normalizeSuiObjectId('0x1'),
            normalizeSuiObjectId('0x2'),
        ],
    })
    ptb.transferObjects([upgradeCap], signer)

    const bytes = await SuiClient.getMoveCallBytesFromPTB(ptb, signer)
    return { bytes, moduleName, structName }
}

/**
 * Extracts the deployed token info from a publish transaction result.
 */
export function parseDeployTokenResult(publishResp: any, moduleName: string, structName: string): DeployedToken {
    return {
        packageId: PublishSingleton.findPublishedPackageId(publishResp),
        upgradeCapId: PublishSingleton.findUpgradeCapId(publishResp),
        moduleName,
        structName,
    }
}

// ==== Step 2: Setup Token ====

/**
 * Builds the setup transaction bytes for a deployed token.
 * This includes: create_ds_token, setup, roles, rules, compliance, template command, finalize.
 */
export async function buildSetupTokenBytes(
    request: DeploymentRequest,
    deployed: DeployedToken,
    signer: string,
) {
    if (request.lockManagerType !== 'investor') {
        throw new Error(`not_implemented: lock manager type ${request.lockManagerType}`)
    }

    if (!['regulated', 'whitelisted'].includes(request.complianceType)) {
        throw new Error(`not_implemented: compliance type ${request.complianceType}`)
    }

    const tokenDescription = request.tokenDescription
    const tokenSymbol = tokenDescription.symbol
    const { packageId, upgradeCapId, moduleName, structName } = deployed

    let ptb = new Transaction()
    const tokenPackage = `${packageId}::${moduleName}`
    const tokenAddressId = `${tokenPackage}::${structName}`

    let metadataCap, treasuryCap
    if (deployed.existingCaps) {
        // create_ds_token was already called — use the existing on-chain cap objects
        metadataCap = ptb.object(deployed.existingCaps.metadataCapId)
        treasuryCap = ptb.object(deployed.existingCaps.treasuryCapId)
    } else {
        [metadataCap, treasuryCap] = ptb.moveCall({
            target: `${tokenPackage}::create_ds_token`,
            arguments: [
                ptb.pure.string(tokenDescription.name),
                ptb.pure.string(tokenSymbol),
                ptb.pure.string(tokenDescription.iconUri),
                ptb.pure.string(tokenDescription.description),
                ptb.pure.u8(tokenDescription.decimals),
                ptb.object(COIN_REGISTRY),
            ],
        })
    }

    const [auth, treasury, investorInfo, complianceConfig, setupFinalize] = ptb.moveCall({
        target: `${Config.vars.PACKAGE_ID}::setup::setup`,
        typeArguments: [tokenAddressId],
        arguments: [
            ptb.object(Config.vars.SETUP_REGISTRY),
            ptb.object(Config.vars.PAS_NAMESPACE),
            treasuryCap,
            metadataCap,
            ptb.object(Config.vars.VERSION),
        ],
    })

    const ptbDetails: PTBDetails = {
        ptb,
        tokenDetails: {
            investorInfo,
            auth,
            complianceConfig,
        },
    }

    const roles = new Roles(tokenAddressId)

    // Set roles BEFORE transferring service ownership (signer needs Master role)
    if (request.owners) {
        roles.setTransferAgentPTB(request.owners.walletRegistrarOwner, ptbDetails)

        if (request.owners.redemptionAddress) {
            const wallets = new Wallets(tokenAddressId)
            wallets.addPlatformWalletPTB(request.owners.redemptionAddress, ptbDetails)
        }
    }

    request.roles.forEach((r) => {
        roles.updateRolePTB(r.address, r.role, ptbDetails)
    })

    if (request.complianceRules) {
        await new Rules(tokenAddressId).updatePTB(request.complianceRules, ptbDetails, true, signer)
    }

    if (request.countriesComplianceStatuses) {
        const countryCompliance = new CountryCompliance(tokenAddressId)
        request.countriesComplianceStatuses.forEach((c) => {
            countryCompliance.setCountryCompliancePTB(
                c.countryName,
                c.complianceStatus,
                ptbDetails
            )
        })
    }

    // Set the transfer approval witness command in templates for <T>
    const dsToken = new DSToken(tokenAddressId)
    dsToken.setTransferTemplateCommandPTB(ptbDetails)

    // Transfer service ownership + upgrade cap LAST (after all other role operations)
    // This must be last because it transfers Master role away from signer
    if (request.owners && request.owners.tokenOwner !== signer) {
        roles.setServiceOwnerPTB(request.owners.tokenOwner, ptbDetails, upgradeCapId)
    }

    ptb.moveCall({
        target: `${Config.vars.PACKAGE_ID}::setup::finalize_setup`,
        typeArguments: [tokenAddressId],
        arguments: [
            setupFinalize,
            auth,
            treasury,
            investorInfo,
            complianceConfig,
            ptb.object(Config.vars.VERSION),
        ],
    })

    const bytes = await SuiClient.getMoveCallBytesFromPTB(ptb, signer)
    return { bytes, tokenAddressId }
}

/**
 * Extracts the token address from a setup transaction result.
 */
export function parseSetupTokenResult(result: any): string {
    const objectTypes: Record<string, string> = result.objectTypes ?? {}
    const currencyEntry = Object.entries(objectTypes).find(([_, type]) =>
        type.includes('::coin_registry::Currency<')
    )
    if (!currencyEntry) {
        throw new Error('Currency object not found in transaction result')
    }
    return currencyEntry[1]
        .replace(/^.*::coin_registry::Currency</, '')
        .slice(0, -1)
}

// ==== Convenience: Full deploy with Keypair (for tests / internal use) ====

/** Deploys a new DS token end-to-end: publishes the token package, then sets up roles, rules, compliance, and templates. */
export async function createDSToken(request: DeploymentRequest, signer: Keypair) {
    const tokenSymbol = request.tokenDescription.symbol

    try {
        // Step 1: Deploy token package
        const signerAddress = signer.toSuiAddress()
        const { bytes: deployBytes, moduleName, structName } = await buildDeployTokenBytes(tokenSymbol, signerAddress)
        const publishResp = await SuiClient.executeMoveCallBytes(deployBytes, signer)
        const deployed = parseDeployTokenResult(publishResp, moduleName, structName)

        // Step 2: Build and execute setup
        const { bytes } = await buildSetupTokenBytes(request, deployed, signerAddress)
        const result = await SuiClient.executeMoveCallBytes(bytes, signer)

        return {
            id: parseSetupTokenResult(result),
        }
    } catch (e: any) {
        const err = handleError(e, tokenSymbol)
        throw new Error(err.message, { cause: e })
    }
}

function handleError(e: any, tokenSymbol: string) {
    const abortError = e?.cause?.effects?.abortError
    const error = abortError?.error_code || -1

    let message = `Token ${tokenSymbol} failed to deploy with error: ${e}`

    if (
        abortError?.module_id?.endsWith('coin_registry') &&
        abortError?.function === 'new_currency' &&
        abortError?.error_code === 2
    ) {
        message = `Token with symbol ${tokenSymbol} already exists.`
    }

    return {
        message,
        error,
        subcode: error,
    }
}
