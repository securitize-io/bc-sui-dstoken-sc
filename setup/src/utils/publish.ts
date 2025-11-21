import { Transaction } from "@mysten/sui/transactions";
import { readFileSync, writeFileSync } from "fs";
import { execSync } from "child_process";
import { Network, signAndExecute } from "./execute";

export const ACTIVE_NETWORK = (process.env.NETWORK as Network) || "localnet";
export const SUI_BIN = `sui`;

export const publishPackage = async ({
  packagePath,
  publisherAddress,
  propName,
  network = "localnet",
}: {
  packagePath: string;
  publisherAddress: string;
  propName: string;
  network: Network;
}) => {

  const txb = new Transaction();

  const { modules, dependencies } = JSON.parse(
    execSync(
      `${SUI_BIN} move build --dump-bytecode-as-base64 --with-unpublished-dependencies --path ${packagePath}`,
      {
        encoding: "utf-8",
      }
    )
  );

  const cap = txb.publish({
    modules,
    dependencies,
  });

  // Transfer the upgrade capability to the sender so they can upgrade the package later if they want.
  txb.transferObjects([cap], publisherAddress);
  txb.setGasBudget(500_000_000);
  const results = await signAndExecute(txb, network, publisherAddress);
  // @ts-ignore-next-line
  const packageId = results.objectChanges?.find(
    (x) => x.type === "published"
  )?.packageId;

  const setupAuth = results.objectChanges?.find(
    (x) =>
      x.type === "created" &&
      x.objectType.includes("setup::SetupAuth")
  );

  // Update .env file
  for (const [key, val] of [
    [propName, packageId],
    // @ts-ignore-next-line
    ["SETUP_AUTH", setupAuth?.objectId],
  ]) {
    try {
      const envContent = readFileSync(".env", "utf8");
      const lines = envContent.split("\n");
      const keyExists = lines.some((line) => line.startsWith(`${key}=`));

      if (keyExists) {
        // Replace existing key-value pair
        const updatedLines = lines.map((line) =>
          line.startsWith(`${key}=`) ? `${key}=${val}` : line
        );
        writeFileSync(".env", updatedLines.join("\n"), "utf8");
      } else {
        // Append new key-value pair
        writeFileSync(".env", `${envContent}\n${key}=${val}`, "utf8");
      }
    } catch (error) {
      // If file doesn't exist, create it with the new key-value pair
      writeFileSync(".env", `${key}=${val}`, "utf8");
    }
  }
};
