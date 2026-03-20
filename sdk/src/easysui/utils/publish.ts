import fs from 'fs'
import {
    SuiObjectChangeCreated,
    SuiObjectChangePublished,
    SuiTransactionBlockResponse,
} from '@mysten/sui/client'
import { Keypair } from '@mysten/sui/cryptography'
import { ADMIN_KEYPAIR, Config } from '../config/config'

import { execSync } from 'child_process'

export class PublishSingleton {
    private static instance: PublishSingleton | null = null

    private constructor(private readonly publishResp: SuiTransactionBlockResponse) {}

    private static getPackagePath(packagePath?: string): string {
        packagePath ??= Config.vars.PACKAGE_PATH

        if (!packagePath) {
            throw new Error(
                'You must set the `PACKAGE_PATH` environment variable to your Move.toml path.'
            )
        }

        return packagePath
    }

    public static async publish(signer?: Keypair, packagePath?: string) {
        signer ??= ADMIN_KEYPAIR!
        const _packagePath = this.getPackagePath(packagePath)

        if (!PublishSingleton.instance) {
            const publishResp = await PublishSingleton.publishPackage(signer, _packagePath)
            this.findPublishedPackageId(publishResp)
            PublishSingleton.instance = new PublishSingleton(publishResp)
        }
    }

    private static getInstance(): PublishSingleton {
        if (!PublishSingleton.instance) {
            throw new Error('Use `async PublishSingleton.publish()` first')
        }
        return PublishSingleton.instance
    }

    /** Returns the main (last) publish response */
    public static publishResponse(): SuiTransactionBlockResponse {
        return this.getInstance().publishResp
    }

    public static get packageId(): string {
        return this.findPublishedPackageId(this.publishResponse())
    }

    public static findObjectIdByType(
        type: string,
        fail: boolean = true,
        resp?: SuiTransactionBlockResponse
    ): string {
        resp ??= this.publishResponse()
        const obj = this.findObjectChangeCreatedByType(resp, type)
        if (fail && !obj) {
            throw new Error(`Expected to find ${type} shared object created.`)
        }
        return obj?.objectId || ''
    }

    public static findUpgradeCapId(resp: SuiTransactionBlockResponse): string {
        return this.findObjectIdByType('0x2::package::UpgradeCap', true, resp)
    }

    public static get upgradeCapId(): string {
        return this.findUpgradeCapId(this.publishResponse())
    }

    public static get usdcTreasuryCap(): string {
        return this.findObjectIdByType(
            `${this.packageId}::treasury::Treasury<${this.packageId}::usdc::USDC>`,
            false
        )
    }

    /**
     * Returns the Move environment to use for the -e flag.
     * For testnet, this comes from SECURITIZE_TESTNET_ENV.
     * Returns undefined for mainnet or if no specific env is configured.
     */
    private static getMoveEnv(): string | undefined {
        const network = Config.vars.NETWORK
        if (network !== 'testnet') {
            return undefined
        }

        const securitizeEnv = process.env.SECURITIZE_TESTNET_ENV
        if (securitizeEnv && ['testnet_alpha', 'testnet_beta', 'testnet_gamma'].includes(securitizeEnv)) {
            return securitizeEnv
        }

        return undefined // Plain testnet, no -e flag
    }

    private static getPublishCmd(packagePath: string, sender: string, inBytes: boolean = false) {
        const network = Config.vars.NETWORK

        if (!fs.existsSync(packagePath)) {
            throw new Error(`Package doesn't exist under: ${packagePath}`)
        }

        if (fs.existsSync(`${packagePath}/Move.lock`)) {
            fs.unlinkSync(`${packagePath}/Move.lock`)
        }
        fs.rmSync(`${packagePath}/build`, { recursive: true, force: true })

        const isEphemeralChain = network !== 'mainnet' && network !== 'testnet'
        const moveEnv = this.getMoveEnv()

        let publishCmd: string
        if (isEphemeralChain) {
            publishCmd = `test-publish --build-env testnet --pubfile-path ${this.pubFile}`
        } else if (moveEnv && !packagePath.includes("temp_tokens") && !packagePath.includes("mainnet_tokens")) {
            // No --pubfile-path for testnet and mainnet - PAS/PTB resolve from Published.toml in repo
            publishCmd = `publish -e ${moveEnv}`
        } else {
            publishCmd = 'publish'
        }

        let buildCommand = `sui client ${publishCmd} ${packagePath}`

        if (isEphemeralChain) {
            buildCommand += ' --publish-unpublished-deps'
        }

        buildCommand += inBytes ? ` --serialize-unsigned-transaction --sender ${sender}` : ' --json'

        return buildCommand
    }

    static get pubFile() {
        return`Pub.${Config.vars.NETWORK}.toml`
    }

    static cleanPubFile() {
        if (fs.existsSync(this.pubFile)) {
            fs.unlinkSync(this.pubFile)
        }
    }

    static async getPublishBytes(signer?: string, packagePath?: string): Promise<string> {
        signer ??= ADMIN_KEYPAIR!.toSuiAddress()
        const _packagePath = this.getPackagePath(packagePath)
        const cmd = this.getPublishCmd(_packagePath, signer, true)
        try {
            return execSync(cmd, {
                encoding: 'utf-8',
                stdio: ['pipe', 'pipe', 'pipe'],
                maxBuffer: 50 * 1024 * 1024,
            }).trim()
        } catch (e: any) {
            const stderr = e.stderr?.toString().trim() || ''
            const stdout = e.stdout?.toString().trim() || ''
            const output = [stderr, stdout].filter(Boolean).join('\n') || e.message
            throw new Error(`Publish bytes command failed:\n${output}`)
        }
    }

    static async publishPackage(
        signer: Keypair,
        packagePath: string
    ): Promise<SuiTransactionBlockResponse> {
        const cmd = this.getPublishCmd(packagePath, signer.toSuiAddress())
        let res: string
        try {
            res = execSync(cmd, {
                encoding: 'utf-8',
                stdio: ['pipe', 'pipe', 'pipe'],
                maxBuffer: 50 * 1024 * 1024,
            })
        } catch (e: any) {
            const stderr = e.stderr?.toString().trim() || ''
            const stdout = e.stdout?.toString().trim() || ''
            const output = [stderr, stdout].filter(Boolean).join('\n') || e.message
            throw new Error(`Publish command failed:\n${output}`)
        }
        const match = res.match(/\{[\s\S]*\}/)
        if (!match) {
            throw new Error(`No JSON found in the publish command output: ${res}`)
        }
        const resp = JSON.parse(match[0])
        return resp
    }

    static findPublishedPackageId(resp: SuiTransactionBlockResponse): string {
        const packageChng = resp.objectChanges?.find(
            (chng): chng is SuiObjectChangePublished => chng.type === 'published'
        )

        if (packageChng) {
            return packageChng.packageId
        }

        // Fallback: check changed_objects array for package with CREATED idOperation
        const changedObjects = (resp as any).changed_objects as
            | Array<{ objectId: string; objectType: string; idOperation: string }>
            | undefined

        const createdPackage = changedObjects?.find(
            (obj) => obj.objectType === 'package' && obj.idOperation === 'CREATED'
        )

        if (createdPackage) {
            return createdPackage.objectId
        }

        throw new Error('Expected to find package published')
    }

    static findObjectChangeCreatedByType(
        resp: SuiTransactionBlockResponse,
        type: string
    ): SuiObjectChangeCreated | undefined {
        // Try standard objectChanges format first
        const found = resp.objectChanges?.find(
            (chng): chng is SuiObjectChangeCreated =>
                chng.type === 'created' && chng.objectType === type
        )

        if (found) {
            return found
        }

        // Fallback: check changed_objects array
        const changedObjects = (resp as any).changed_objects as
            | Array<{ objectId: string; objectType: string; idOperation: string }>
            | undefined

        const createdObj = changedObjects?.find(
            (obj) => obj.idOperation === 'CREATED' && this.typeMatches(obj.objectType, type)
        )

        if (createdObj) {
            // Return a compatible shape
            return {
                type: 'created',
                objectType: createdObj.objectType,
                objectId: createdObj.objectId,
                owner: {} as any,
                digest: '',
                version: '',
            } as SuiObjectChangeCreated
        }

        return undefined
    }

    private static typeMatches(fullType: string, shortType: string): boolean {
        // Normalize short addresses (0x2) to full addresses (0x000...0002)
        const normalizeType = (t: string) =>
            t.replace(/0x([0-9a-fA-F]{1,63})::/g, (_, addr) => {
                return `0x${addr.padStart(64, '0')}::`
            })

        return normalizeType(fullType) === normalizeType(shortType)
    }
}
