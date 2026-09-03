import path from 'path'
import fs from 'fs'
import dotenv from 'dotenv'
import { Keypair } from '@mysten/sui/cryptography'
import { getKeypair } from '../utils/keypair'
import { Network } from './static'
import {SUI_CLOCK_OBJECT_ID, normalizeSuiAddress} from "@mysten/sui/utils";
dotenv.config({ path: path.resolve(process.cwd(), '.env'), quiet: true })

export const DENY_LIST_ID = '0x403'
export const CLOCK_ID = SUI_CLOCK_OBJECT_ID
export const COIN_REGISTRY = normalizeSuiAddress('0xc')

// Base configuration that the SDK provides
export interface BaseConfigVars {
    NETWORK: Network
    GRPC_URL: string
    GRPC_AUTH_TOKEN?: string
    PACKAGE_PATH: string
    PACKAGE_ID: string
    UPGRADE_CAP_ID: string
}

// Default ConfigVars is just the base, but projects can extend it
export type ConfigVars = BaseConfigVars

export const ADMIN_KEYPAIR: Keypair | undefined = process.env.ADMIN_PRIVATE_KEY ? getKeypair(process.env.ADMIN_PRIVATE_KEY) : undefined
export const ADMIN_ADDRESS: string = process.env.ADMIN_ADDRESS || ADMIN_KEYPAIR?.toSuiAddress() || ''

/**
 * Map of config keys to Move type patterns for finding object IDs during deployment
 * The type pattern can use {packageId} placeholder which will be replaced with the deployed package ID
 *
 * Example: { SETUP_AUTH: "{packageId}::setup::SetupAuth" }
 * Example: { TOKEN_TREASURY_CAP: "{packageId}::treasury::Treasury<{packageId}::token::TOKEN>" }
 */
export type ExtraVarsMap = Record<string, string>

// Generic Config class that can be extended with custom types
export class Config<TConfigVars extends BaseConfigVars = ConfigVars> {
    private static instance: Config | null = null
    protected static _cachedVars: BaseConfigVars | null = null

    private static getInstance(): Config {
        if (!Config.instance) {
            this.instance = new Config()
        }
        return this.instance!
    }

    static invalidateCache(): void {
        this._cachedVars = null
    }

    get env(): Network {
        let env = process.env.NETWORK
        if (!['mainnet', 'testnet', 'devnet', 'localnet'].includes(env || '')) {
            env = 'localnet'
        }
        return env as Network
    }

    /**
     * Override this getter in your custom Config class to define extra variables
     * that should be populated during deployment by finding objects by their Move types
     */
    static get extraVars(): ExtraVarsMap {
        return {}
    }

    static get vars(): BaseConfigVars {
        if (this._cachedVars) {
            return this._cachedVars
        }

        const instance = this.getInstance()
        const NETWORK = instance.env

        // Load env file once on first access
        dotenv.config({ path: path.resolve(process.cwd(), `.env.${NETWORK}`), override: true, quiet: true })

        const envVars = {
            NETWORK,
            GRPC_URL: process.env.GRPC_URL || '',
            GRPC_AUTH_TOKEN: process.env.GRPC_AUTH_TOKEN || undefined,
            PACKAGE_PATH: process.env.PACKAGE_PATH || '',
            PACKAGE_ID: process.env.PACKAGE_ID || '',
            UPGRADE_CAP_ID: process.env.UPGRADE_CAP_ID || '',
        }

        this._cachedVars = envVars
        return this._cachedVars
    }

    static write<T extends BaseConfigVars>(config: T, envSuffix?: string): string {
        const instance = this.getInstance()
        const env = envSuffix ?? instance.env
        const envFile = path.join(process.cwd(), `.env${env ? `.${env}` : ''}`)

        const envVariables = Object.entries(config)
            .filter(([_, value]) => value)
            .map(([key, value]) => `${key}=${value}`)
            .join('\n')

        fs.writeFileSync(envFile, envVariables, 'utf8')
        return envFile
    }
}
