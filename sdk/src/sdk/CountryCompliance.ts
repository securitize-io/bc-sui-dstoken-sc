import {SuiClient} from "../easysui";
import {Config} from "./utils/config";
import {getTokenDetails} from "./token";
import {newPTBDetails, PTBDetails} from "./domains/PTBDetails";
import {fromRegionId, toRegionId} from "./domains";
import {ComplianceStatus} from "./domains/CountryComplianceStatus";

export class CountryCompliance {
    private readonly tokenAddress: string;
    private readonly tokenDetails: any;

    constructor(tokenAddress: string) {
        this.tokenAddress = tokenAddress;
        this.tokenDetails = getTokenDetails(tokenAddress);
    }

    private getComplianceTarget(func: string) {
        return `${Config.vars.PACKAGE_ID}::compliance_service::${func}`
    }

    // ==== View Functions ====

    async get(country: string, sender: string): Promise<ComplianceStatus> {
        const ptb = SuiClient.getPTB(
            this.getComplianceTarget('get_country_compliance'),
            [this.tokenAddress],
            [this.tokenDetails.investorInfo, country],
        )
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

        ptb.moveCall({
            target: this.getComplianceTarget('set_country_compliance'),
            typeArguments: [this.tokenAddress],
            arguments: [
                ptbDetails.tokenDetails?.investorInfo || ptb.object(this.tokenDetails.investorInfo),
                ptb.pure.string(country),
                ptb.pure.u64(toRegionId(complianceRegion)),
                ptbDetails.tokenDetails?.auth || ptb.object(this.tokenDetails.auth),
                ptb.object(Config.vars.VERSION),
            ],
        })

        return ptb
    }

    async set(
        signer: string,
        country: string,
        complianceRegion: ComplianceStatus,
    ) {
        const ptb = this.setCountryCompliancePTB(country, complianceRegion)
        return SuiClient.getMoveCallBytesFromPTB(ptb, signer)
    }
}
