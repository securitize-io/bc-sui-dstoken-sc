import fs from 'fs'
import { Keypair } from '@mysten/sui/cryptography'
import { Config } from '../config/config'

import { execSync } from 'child_process'

export class PublishSingleton {
    private static instance: PublishSingleton | null = null

    private constructor(private readonly publishResp: any) {}

    private static getPackagePath(packagePath?: string): string {
        packagePath ??= Config.vars.PACKAGE_PATH

        if (!packagePath) {
            throw new Error(
                'You must set the `PACKAGE_PATH` environment variable to your Move.toml path.'
            )
        }

        return packagePath
    }

    public static async publish(signer: Keypair, packagePath?: string) {
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
    public static publishResponse(): any {
        return this.getInstance().publishResp
    }

    public static get packageId(): string {
        return this.findPublishedPackageId(this.publishResponse())
    }

    public static findObjectIdByType(
        type: string,
        fail: boolean = true,
        resp?: any
    ): string {
        resp ??= this.publishResponse()
        const obj = this.findObjectChangeCreatedByType(resp, type)
        if (fail && !obj) {
            throw new Error(`Expected to find ${type} shared object created.`)
        }
        return obj?.objectId || ''
    }

    public static findUpgradeCapId(resp: any): string {
        return this.findObjectIdByType('0x2::package::UpgradeCap', true, resp)
    }

    public static get upgradeCapId(): string {
        return this.findUpgradeCapId(this.publishResponse())
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
        if (
            securitizeEnv &&
            ['testnet_alpha', 'testnet_beta', 'testnet_gamma'].includes(securitizeEnv)
        ) {
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

        if (isEphemeralChain) {
            this.cleanPubFile()
        }

        let publishCmd: string
        if (isEphemeralChain) {
            publishCmd = `test-publish --build-env testnet --pubfile-path ${this.pubFile}`
        } else if (moveEnv) {
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
        return `Pub.${Config.vars.NETWORK}.toml`
    }

    static cleanPubFile() {
        if (fs.existsSync(this.pubFile)) {
            fs.unlinkSync(this.pubFile)
        }
    }

    static async getPublishBytes(signer: string, packagePath?: string): Promise<string> {
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
        packagePath: string,
    ): Promise<any> {
        const cmd = this.getPublishCmd(packagePath, signer.toSuiAddress(), false)
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

    static findPublishedPackageId(resp: any): string {
        // JSON-RPC format (sui client publish --json)
        const packageChng = resp.objectChanges?.find(
            (chng: any) => chng.type === 'published'
        )
        if (packageChng) {
            return packageChng.packageId
        }

        // gRPC format: changedObjects in effects + objectTypes map
        const changedObjects = resp.effects?.changedObjects ?? resp.changed_objects
        const objectTypes: Record<string, string> = resp.objectTypes ?? {}

        if (changedObjects) {
            const createdPackage = changedObjects.find(
                (obj: any) => {
                    const type = obj.objectType || objectTypes[obj.objectId] || ''
                    return (obj.idOperation === 'Created' || obj.idOperation === 'CREATED') &&
                        type === 'package'
                }
            )
            if (createdPackage) {
                return createdPackage.objectId
            }
        }

        throw new Error('Expected to find package published')
    }

    static findObjectChangeCreatedByType(
        resp: any,
        type: string
    ): any | undefined {
        // JSON-RPC format
        const found = resp.objectChanges?.find(
            (chng: any) =>
                chng.type === 'created' && chng.objectType === type
        )
        if (found) {
            return found
        }

        // gRPC format: changedObjects in effects + objectTypes map
        const changedObjects = resp.effects?.changedObjects ?? resp.changed_objects
        const objectTypes: Record<string, string> = resp.objectTypes ?? {}

        if (changedObjects) {
            const createdObj = changedObjects.find(
                (obj: any) => {
                    const objType = obj.objectType || objectTypes[obj.objectId] || ''
                    return (obj.idOperation === 'Created' || obj.idOperation === 'CREATED') &&
                        this.typeMatches(objType, type)
                }
            )
            if (createdObj) {
                return {
                    type: 'created',
                    objectType: createdObj.objectType || objectTypes[createdObj.objectId],
                    objectId: createdObj.objectId,
                }
            }
        }

        return undefined
    }

    static typeMatches(fullType: string, shortType: string): boolean {
        // Normalize short addresses (0x2) to full addresses (0x000...0002)
        const normalizeType = (t: string) =>
            t.replace(/0x([0-9a-fA-F]{1,63})::/g, (_, addr) => {
                return `0x${addr.padStart(64, '0')}::`
            })

        return normalizeType(fullType) === normalizeType(shortType)
    }
}
