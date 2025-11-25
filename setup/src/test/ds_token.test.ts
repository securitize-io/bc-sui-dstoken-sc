import { Transaction } from "@mysten/sui/transactions";
import {
  ADMIN_ADDRESS,
  ACTIVE_NETWORK,
  SETUP_AUTH,
} from "../config";
import { getClient, signAndExecute } from "../utils/execute";
import { ObjectOwner } from "@mysten/sui/client";
import { normalizeSuiAddress } from "@mysten/sui/utils";

interface SuiObjectCreated {
    digest: string;
    objectId: string;
    objectType: string;
    owner: ObjectOwner;
    sender: string;
    type: 'created';
    version: string;
}

/**
 * Integration tests for Ds token module.
 */
describe("Ds token", () => {
  let treasury: string;

  // ----------- Global setup -----------
  beforeAll(async () => {
    const setupTx = new Transaction();
    // Call the Setup function of Bolera token to spin up all the components
    setupTx.moveCall({
      target: `${process.env.PACKAGE_ID}::bolera::create_ds_token`,
      arguments: [setupTx.object(SETUP_AUTH), setupTx.object(normalizeSuiAddress("0xc"))]
    })

    let result = await signAndExecute(setupTx, ACTIVE_NETWORK, ADMIN_ADDRESS);
    treasury = (result.objectChanges?.find((x) => x.type === "created" && x.objectType.includes("ds_token::Treasury")) as SuiObjectCreated).objectId;
    expect(result.effects?.status.status).toBe("success");
  });

  // -------------- Test --------------
  it("Simple flow", async () => {
    console.log("Treasury:", treasury);
  });

});

