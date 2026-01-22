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
            // suiClientGen(packageId)
            PublishSingleton.instance = new PublishSingleton(publishResp)
        }
    }

    private static getInstance(): PublishSingleton {
        if (!PublishSingleton.instance) {
            throw new Error('Use `async PublishSingleton.publish()` first')
        }
        return PublishSingleton.instance
    }

    public static publishResponse(): SuiTransactionBlockResponse {
        return this.getInstance().publishResp
    }

    public static get packageId(): string {
        return this.findPublishedPackageId(this.publishResponse())
    }

    public static findObjectIdByType(type: string, fail: boolean = true, resp?: SuiTransactionBlockResponse): string {
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
        const publishCmd = isEphemeralChain ? `test-publish --build-env testnet` : 'publish'

        let buildCommand = `sui client ${publishCmd} ${packagePath}`

        if (network === 'localnet' || network === 'devnet') {
            buildCommand += ' --with-unpublished-dependencies'
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

    static async getPublishBytes(signer?: string, packagePath?: string): Promise<string> {
        signer ??= ADMIN_KEYPAIR!.toSuiAddress()
        const _packagePath = this.getPackagePath(packagePath)
        const cmd = this.getPublishCmd(_packagePath, signer, true)
        return execSync(cmd, { encoding: 'utf-8' }).trim()
    }

    static async publishPackage(
        signer: Keypair,
        packagePath: string
    ): Promise<SuiTransactionBlockResponse> {
        const cmd = this.getPublishCmd(packagePath, signer.toSuiAddress())
        const res = execSync(cmd, { encoding: 'utf-8' })
        const match = res.match(/\{[\s\S]*\}/);
        if (!match) {
            throw new Error(`No JSON found in the publish command output: ${res}`);
        }
        return JSON.parse(match[0])
    }

    static findPublishedPackageId(
        resp: SuiTransactionBlockResponse
    ): string {
        const packageChng = resp.objectChanges?.find(
            (chng): chng is SuiObjectChangePublished => chng.type === 'published'
        )

        if (!packageChng) {
            throw new Error('Expected to find package published')
        }

        return packageChng.packageId
    }

    static findObjectChangeCreatedByType(
        resp: SuiTransactionBlockResponse,
        type: string
    ): SuiObjectChangeCreated | undefined {
        return resp.objectChanges?.find(
            (chng): chng is SuiObjectChangeCreated =>
                chng.type === 'created' && chng.objectType === type
        )
    }
}
