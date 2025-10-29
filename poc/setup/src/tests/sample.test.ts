import { Transaction } from "@mysten/sui/transactions";
import { ENV } from "../env";
import { getSigner } from "../helpers/getSigner";
import { suiClient } from "../suiClient";
import { normalizeSuiAddress } from "@mysten/sui/utils";

describe("Sample Test Suite", () => {
  test("Sample test that always passes", async () => {
    expect(true).toBe(true);
  });
})
