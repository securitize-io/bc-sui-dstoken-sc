import { Transaction } from "@mysten/sui/transactions";
import {
  ADMIN_ADDRESS,
  ACTIVE_NETWORK,
  SETUP_AUTH,
} from "../config";
import { devInspect, getClient, signAndExecute } from "../utils/execute";
import { bcs } from "@mysten/bcs";
import { SuiClient } from "@mysten/sui/client";

/**
 * Integration tests for Ds token module.
 */
describe("Ds token", () => {
  // ----------- Global setup -----------
  beforeAll(async () => {
    const setupTx = new Transaction();
    // Call the Setup function of Bolera token to spin up all the components
    setupTx.moveCall({
      target: `${process.env.PACKAGE_ID}::bolera::create_ds_token`,
      arguments: [setupTx.object(SETUP_AUTH), setupTx.object("0xc")]
    })
   
    let result = await signAndExecute(setupTx, ACTIVE_NETWORK, ADMIN_ADDRESS);
    expect(result.effects?.status.status).toBe("success");
  });

  // -------------- Test --------------
  it("Simple flow", async () => {
    const client = getClient(ACTIVE_NETWORK);

  });

});

