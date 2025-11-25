import { ACTIVE_NETWORK } from "../config";

import { ADMIN_ADDRESS } from "../config";
import { publishPackage } from "../utils/publish";

import { cwd } from "process";
import path from "path";

beforeAll(async () => {
  // Publish all packages through bolera contract
  await publishPackage({
    packagePath: path.join(cwd(), "src", "bolera"),
    publisherAddress: ADMIN_ADDRESS,
    propName: "PACKAGE_ID",
    network: ACTIVE_NETWORK,
  });
});

describe("Publish", () => {
  it("should publish all packages", async () => {
    expect(true).toBe(true);
  });
});
