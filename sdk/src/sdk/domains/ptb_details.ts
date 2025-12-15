import {Transaction} from "@mysten/sui/transactions";
import {TokenDetailsObj} from "../token";

export interface PTBDetails {
    ptb: Transaction,
    tokenDetails: TokenDetailsObj
}