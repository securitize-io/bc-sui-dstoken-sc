import {ADMIN_KEYPAIR, SuiClient} from '../easysui'
import {Config} from "./utils/config";
import {DeploymentRequest, PTBDetails} from "./domains";
import {Transaction} from "@mysten/sui/transactions";
import {Rules} from "./rules";
import {Roles} from "./roles";
import {Wallets} from "./wallets";
import {CountryCompliance} from "./CountryCompliance";
import {TOKEN_TEMPLATE, MOVE_TOML} from "./templates";
import {PublishSingleton} from "../easysui";
import fs from 'fs';
import path from 'path';
import {COIN_REGISTRY} from "../easysui/config/config";

async function deployToken(tokenSymbol: string): Promise<string[]> {
    const module = tokenSymbol.toLowerCase()
    const symbol = tokenSymbol.toUpperCase()

    const contract = TOKEN_TEMPLATE
        .replaceAll('{MODULE}', module)
        .replaceAll('{SYMBOL}', symbol)

    // Create a temporary directory for the token package
    const tempDir = path.join(process.cwd(), Config.vars.TEMP_PATH, module)
    const sourcesDir = path.join(tempDir, 'sources')
    fs.rmSync(tempDir, { recursive: true, force: true })

    // Create directories
    fs.mkdirSync(sourcesDir, { recursive: true })

    // Write the Move.toml file
    const moveToml = MOVE_TOML
        .replaceAll('{MODULE}', module)
        .replaceAll('{TESTNET_ENV}', Config.vars.SECURITIZE_TESTNET_ENV)
    fs.writeFileSync(path.join(tempDir, 'Move.toml'), moveToml)

    // Write the contract source file
    fs.writeFileSync(path.join(sourcesDir, `${module}.move`), contract)

    // Publish the package
    const publishResp = await PublishSingleton.publishPackage(ADMIN_KEYPAIR!, tempDir)
    // Clean up temporary directory
    fs.rmSync(tempDir, { recursive: true, force: true })

    // Extract and return the package ID
    const packageId = PublishSingleton.findPublishedPackageId(publishResp)
    const upgradeCap = PublishSingleton.findUpgradeCapId(publishResp)
    return [packageId, upgradeCap]
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
        const [deployedPackageId, upgradeCapId] = await deployToken(tokenSymbol)

        let ptb = new Transaction()
        const tokenPackage = `${deployedPackageId}::${tokenSymbol.toLowerCase()}`
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
                ptb.object(COIN_REGISTRY),
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
                countryCompliance.setCountryCompliancePTB(c.countryName, c.complianceStatus, ptbDetails)
            })
        }

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
