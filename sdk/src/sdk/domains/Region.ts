import {ComplianceStatus} from "./CountryComplianceStatus";

export enum Regions {
    NONE = 0,
    US = 1,
    EU = 2,
    FORBIDDEN = 4,
    JP = 8,
}

export function toRegionId(region: ComplianceStatus) {
    return {
        'none': Regions.NONE,
        'us': Regions.US,
        'eu': Regions.EU,
        'forbidden': Regions.FORBIDDEN,
        'jp': Regions.JP,
    }[region]
}
