import {normalizeSuiAddress} from '@mysten/sui/utils'
import {ADMIN_KEYPAIR, SuiClient} from '../easysui'
import {Config} from "./utils/config";
import {DeploymentRequest} from "./domains";
import {Transaction} from "@mysten/sui/transactions";
import {Rules} from "./rules";
import {Roles} from "./roles";
import {PTBDetails} from "./domains/PTBDetails";

export async function createDSToken(request: DeploymentRequest) {
    //TODO: deploy token contract first

    if (request.lockManagerType !== 'investor') {
        throw new Error(`not_implemented: lock manager type ${request.lockManagerType}`)
    }

    if (!['regulated', 'whitelisted'].includes(request.complianceType)) {
        throw new Error(`not_implemented: compliance type ${request.complianceType}`)
    }

    let ptb = new Transaction()
    const tokenDescription = request.tokenDescription
    const tokenSymbol = tokenDescription.symbol
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
            ptb.object(Config.vars.RWA_REGISTRY),
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
        ptb = roles.setServiceOwnerPTB(request.owners.tokenOwner, ptb)
        ptb = roles.setTransferAgentPTB(request.owners.walletRegistrarOwner, ptb)
        // TODO: Transfer upgrade cap to request.owners.tokenOwner
    }

    request.roles.forEach((r) => {
        ptb = roles.updateRolePTB(r.address, r.role, ptb)
    })

    if (request.complianceRules) {
        ptb = new Rules(tokenAddressId).updatePTB(request.complianceRules, ptbDetails)
    }

    // TODO: Create a country compliance class for setting and getting
    // if (request.countriesComplianceStatuses) {
    //     request.countriesComplianceStatuses.forEach((c) => {
    //         ptb = TBD.setCountryCompliance(c.countryName, toRegionId(c.complianceStatus), ptb)
    //     })
    // }

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
}
