import { ADMIN_KEYPAIR, SuiClient } from '../easysui'
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
}

async function deployToken(tokenSymbol: string): Promise<DeployedToken> {
    // Patch the placeholder identifiers in the pre-compiled token_template
    // bytecode so each deploy publishes a unique module + struct.
    const { bytecode, moduleName, structName } = patchTokenTemplate(
        getTokenTemplateBytecode(),
        tokenSymbol
    )

    const tx = new Transaction()
    const [upgradeCap] = tx.publish({
        modules: [Array.from(bytecode)],
        dependencies: [
            normalizeSuiObjectId('0x1'),
            normalizeSuiObjectId('0x2'),
        ],
    })
    tx.transferObjects([upgradeCap], ADMIN_KEYPAIR!.toSuiAddress())

    const publishResp = await SuiClient.signAndExecute(tx, ADMIN_KEYPAIR!)

    return {
        packageId: PublishSingleton.findPublishedPackageId(publishResp),
        upgradeCapId: PublishSingleton.findUpgradeCapId(publishResp),
        moduleName,
        structName,
    }
}

export async function createDSToken(request: DeploymentRequest) {
    const tokenDescription = request.tokenDescription
    const tokenSymbol = tokenDescription.symbol

    try {
        if (request.lockManagerType !== 'investor') {
            throw new Error(`not_implemented: lock manager type ${request.lockManagerType}`)
        }

        if (!['regulated', 'whitelisted'].includes(request.complianceType)) {
            throw new Error(`not_implemented: compliance type ${request.complianceType}`)
        }

        // Deploy the token contract
        const { packageId, upgradeCapId, moduleName, structName } =
            await deployToken(tokenSymbol)

        let ptb = new Transaction()
        const tokenPackage = `${packageId}::${moduleName}`
        const tokenAddressId = `${tokenPackage}::${structName}`

        const [metadataCap, treasuryCap] = ptb.moveCall({
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
            await new Rules(tokenAddressId).updatePTB(request.complianceRules, ptbDetails)
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
        if (request.owners && request.owners.tokenOwner !== ADMIN_KEYPAIR!.toSuiAddress()) {
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

        const result = await SuiClient.signAndExecute(ptb, ADMIN_KEYPAIR!)

        const currencyObj: any = result.objectChanges?.find((o: any) =>
            o.objectType.startsWith('0x2::coin_registry::Currency<')
        )
        const tokenAddress = currencyObj.objectType
            .replaceAll('0x2::coin_registry::Currency<', '')
            .slice(0, -1)

        return {
            id: tokenAddress,
        }
    } catch (e: any) {
        throw handleError(e, tokenSymbol)
    }
}

function handleError(e: any, tokenSymbol: string) {
    const abortError = e?.cause?.effects.abortError
    const error = abortError?.error_code || -1

    let message = `Token ${tokenSymbol} failed to deploy with error: ${e}`

    if (
        abortError?.module_id.endsWith('coin_registry') &&
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
