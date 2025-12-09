import { Coin } from '@easysui/sdk'
import { Keypair } from '@mysten/sui/cryptography'
import {Config} from "./utils/config";

export class Voloro extends Coin {
    public static get coinType(): string {
        return Config.vars.PACKAGE_ID + '::drachma::DRACHMA'
    }

    public static async mint(amount: bigint, minter: Keypair, treasuryId: string) {
        // const treasuryId = '0xe113d4948d863e8c4fcb9fdcbb8d632d8661d46dbc8f82b6d93cd0e8798c7226'
        await Voloro._mint(treasuryId, amount, minter)
    }
}
