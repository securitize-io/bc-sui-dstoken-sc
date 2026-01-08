import {Attribute} from "./Attributes";

export interface InvestorDetails {
    id: string,
    country: string,
    attributes: Attribute[],
    totalBalance: string,
    wallets: string[]
}