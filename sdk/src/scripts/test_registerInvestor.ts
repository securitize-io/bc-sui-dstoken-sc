import {registerInvestor} from "../sdk/investors";
import {ADMIN_KEYPAIR, Config} from "../easysui";

export async function test() {
    const tokenAddress = Config.vars.PACKAGE_ID + "::voloro::VOLORO"
    const res = await registerInvestor(ADMIN_KEYPAIR!.toSuiAddress(), tokenAddress, "test")
    console.log(res);
}

test().then(console.log)