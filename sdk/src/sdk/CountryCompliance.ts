import {SuiClient} from "../easysui";
import {Config} from "./utils/config";
import {getTokenDetails} from "./token";
import {
    newPTBDetails,
    PTBDetails,
    fromRegionId,
    toRegionId,
    ComplianceStatus,
} from "./domains";
import {Transaction} from "@mysten/sui/transactions";
import * as complianceService from "../generated/securitize/compliance_service";

export class CountryCompliance {
    private readonly tokenAddress: string;
    private readonly tokenDetails: any;

    constructor(tokenAddress: string) {
        this.tokenAddress = tokenAddress;
        this.tokenDetails = getTokenDetails(tokenAddress);
    }

    // ==== View Functions ====

    /** Returns the compliance status for a country (none, us, eu, forbidden, jp). */
    async get(country: string, sender: string): Promise<ComplianceStatus> {
        const ptb = new Transaction()
        complianceService.getCountryCompliance({
            package: this.pkg,
            arguments: { registry: this.tokenDetails.investorInfo, country },
            typeArguments: this.typeArgs,
        })(ptb)
        const result = await SuiClient.devInspectU64(ptb, sender)
        return fromRegionId(Number(result))
    }

    // ==== Setter Functions ====

    setCountryCompliancePTB(
        country: string,
        complianceRegion: ComplianceStatus,
        ptbDetails?: PTBDetails,
    ) {
        ptbDetails ??= newPTBDetails()
        const ptb = ptbDetails.ptb

        complianceService.setCountryCompliance({
            package: this.pkg,
            arguments: {
                registry: ptbDetails.tokenDetails?.investorInfo || this.tokenDetails.investorInfo,
                country,
                complianceRegion: toRegionId(complianceRegion),
                auth: ptbDetails.tokenDetails?.auth || this.tokenDetails.auth,
                version: Config.vars.VERSION,
            },
            typeArguments: this.typeArgs,
        })(ptb)

        return ptb
    }

    /** Sets the compliance region for a country (e.g., 'us', 'eu', 'forbidden'). */
    async set(
        signer: string,
        country: string,
        complianceRegion: ComplianceStatus,
    ) {
        const ptb = this.setCountryCompliancePTB(country, complianceRegion)
        return SuiClient.getMoveCallBytesFromPTB(ptb, signer)
    }

    // ==== Private Helpers ====

    private get pkg() { return Config.vars.PACKAGE_ID }
    private get typeArgs(): [string] { return [this.tokenAddress] }
}
