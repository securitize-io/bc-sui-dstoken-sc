import {normalizeSuiAddress} from '@mysten/sui/utils'
import {ADMIN_KEYPAIR, SuiClient} from '../easysui'
import {Config} from "./utils/config";
import {DeploymentRequest} from "./domains";
import {Transaction} from "@mysten/sui/transactions";
import {Rules} from "./rules";
import {Roles} from "./roles";
import {PTBDetails} from "./domains/PTBDetails";
import {CountryCompliance} from "./CountryCompliance";

export async function createDSToken(request: DeploymentRequest) {
    const tokenDescription = request.tokenDescription
    const tokenSymbol = tokenDescription.symbol
    //TODO: deploy token contract first

    try {
        if (request.lockManagerType !== 'investor') {
            throw new Error(`not_implemented: lock manager type ${request.lockManagerType}`)
        }

        if (!['regulated', 'whitelisted'].includes(request.complianceType)) {
            throw new Error(`not_implemented: compliance type ${request.complianceType}`)
        }

        let ptb = new Transaction()
        const tokenPackage = `${Config.vars.PACKAGE_ID}::${tokenSymbol.toLowerCase()}`
        const tokenAddressId = `${tokenPackage}::${tokenSymbol.toUpperCase()}`

        const [
            auth,
            treasury,
            investorInfo,
            complianceConfig,
            setupFinalize
        ] = ptb.moveCall({
            target: `${tokenPackage}::create_ds_token`,
            arguments: [
                ptb.pure.string(tokenDescription.name),
                ptb.pure.string(tokenSymbol),
                ptb.pure.string(tokenDescription.iconUri),
                ptb.pure.string(tokenDescription.description),
                ptb.pure.u8(tokenDescription.decimals),
                ptb.object(Config.vars.SETUP_REGISTRY),
                ptb.object(Config.vars.PAS_NAMESPACE),
                ptb.object(normalizeSuiAddress('0xc')),
                ptb.object(Config.vars.VERSION),
            ],
        })

        const ptbDetails: PTBDetails = {
            ptb,
            tokenDetails: {
                investorInfo,
                auth,
                complianceConfig
            }
        }

        const roles = new Roles(tokenAddressId)

        if (request.owners) {
            roles.setServiceOwnerPTB(request.owners.tokenOwner, ptb)
            roles.setTransferAgentPTB(request.owners.walletRegistrarOwner, ptb)
            // TODO: Transfer upgrade cap to request.owners.tokenOwner
        }

        request.roles.forEach((r) => {
            roles.updateRolePTB(r.address, r.role, ptb)
        })

        if (request.complianceRules) {
            await new Rules(tokenAddressId).updatePTB(request.complianceRules, ptbDetails)
        }

        if (request.countriesComplianceStatuses) {
            const countryCompliance = new CountryCompliance(tokenAddressId)
            request.countriesComplianceStatuses.forEach((c) => {
                countryCompliance.setCountryCompliancePTB(c.countryName, c.complianceStatus, ptbDetails)
            })
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
                ptb.object(Config.vars.VERSION)
            ]
        })

        const result = await SuiClient.signAndExecute(ptb, ADMIN_KEYPAIR!)

        const currencyObj: any = result.objectChanges?.find((o: any) => o.objectType.startsWith("0x2::coin_registry::Currency<"))
        const tokenAddress = currencyObj.objectType.replaceAll("0x2::coin_registry::Currency<", "").slice(0, -1)

        return {
            id: tokenAddress,
        }
    } catch (e: any) {
        throw handleError(e, tokenSymbol)
    }
}

function handleError(e: any, tokenSymbol: string) {
    const abortError = e?.cause?.effects.abortError;
    const error = abortError?.error_code || -1

    let message = `Token ${tokenSymbol} failed to deploy with error: ${e}`

    if (
        abortError?.module_id.endsWith("coin_registry") &&
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
