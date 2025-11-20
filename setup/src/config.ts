import { config } from "dotenv";
import path from "path";
import { readFileSync } from "fs";
import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";

config({ path: path.resolve(process.cwd(), ".env"), override: true });

export const DIR = process.cwd();
export const FULLNODE_URL = process.env.FULLNODE_URL!;
export const ADMIN_PRIVATE_KEY = process.env.ADMIN_PRIVATE_KEY!;
export const ACTIVE_NETWORK = (process.env.NETWORK || "localnet") as
  | "mainnet"
  | "testnet"
  | "devnet"
  | "localnet";

// Create admin keypair and get address
const adminKeypair = Ed25519Keypair.fromSecretKey(ADMIN_PRIVATE_KEY);
export const ADMIN_ADDRESS = adminKeypair.getPublicKey().toSuiAddress();

const getEnvValue = (key: string): string => {
  try {
    const envContent = readFileSync(".env", "utf8");
    const lines = envContent.split("\n");
    const line = lines.find((line) => line.startsWith(`${key}=`));
    if (!line) throw new Error(`Environment variable ${key} not found`);
    return line.split("=")[1];
  } catch (error) {
    throw new Error(`Failed to read environment variable ${key}: ${error}`);
  }
};

export const PACKAGE_ID = process.env.PACKAGE_ID!;
export const SETUP_AUTH = process.env.SETUP_AUTH!;  