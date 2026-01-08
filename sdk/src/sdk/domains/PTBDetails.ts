import {Transaction} from "@mysten/sui/transactions";
import {TokenDetailsObj} from "../token";

export interface PTBDetails {
    ptb: Transaction,
    tokenDetails?: TokenDetailsObj
}

export function newPTBDetails() {
    return {
        ptb: new Transaction()
    } as PTBDetails
}