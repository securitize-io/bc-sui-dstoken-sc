import { SuiGrpcClient } from '@mysten/sui/grpc'
import { toBase64, fromBase64, fromHex } from '@mysten/sui/utils'
import { Config } from '../config/config'
import { Transaction } from '@mysten/sui/transactions'
import { Keypair } from '@mysten/sui/cryptography'
import { bcs } from '@mysten/sui/bcs'
import { analyze_cost } from './cost_analyzer'
import { FORMAT_TYPES, hexToBase64, isHex, toFormatType } from './byte_utils'

export enum MoveType {
    u8 = 1,
    u16,
    u32,
    u64,
    u128,
    u256,
    bool,
    string,
    string_opt,
    object,
    address,
    address_opt,
    vec_address,
    vec_u64,
}

/** Include options for gRPC transaction responses */
const txInclude = {
    effects: true,
    objectTypes: true,
    balanceChanges: true,
} as const

export class SuiClient {
    private static instance: SuiClient | null = null
    private client: SuiGrpcClient
    private constructor() {
        const network = Config.vars.NETWORK
        if (!Config.vars.GRPC_URL) {
            throw new Error('GRPC_URL is not set. Add it to your .env file.')
        }
        this.client = new SuiGrpcClient({
            network,
            baseUrl: Config.vars.GRPC_URL,
        })
    }

    private static getInstance(): SuiClient {
        if (!SuiClient.instance) {
            this.instance = new SuiClient()
        }
        return this.instance!
    }

    public static get client(): SuiGrpcClient {
        return this.getInstance().client
    }


    /**
     * Waits for transaction confirmation and returns the result.
     * Handles both gRPC response shape ({ $kind, Transaction }) and
     * JSON-RPC response shape (flat SuiTransactionBlockResponse).
     */
    private static async waitForTransaction(ptb: Transaction, result: any) {
        // gRPC response shape
        if (result.$kind === 'FailedTransaction') {
            throw new Error(JSON.stringify(result.FailedTransaction))
        }
        const txResult = result.$kind ? result.Transaction : result

        // Check for failure
        const status = txResult.status ?? txResult.effects?.status
        if (status?.status === 'failure' || status?.success === false) {
            throw new Error(JSON.stringify(txResult))
        }

        await SuiClient.client.waitForTransaction({
            digest: txResult.digest,
            include: txInclude,
        })

        analyze_cost(ptb, txResult)
        return txResult
    }

    public static async signAndExecute(ptb: Transaction, signer: Keypair) {
        const result = await SuiClient.client.signAndExecuteTransaction({
            transaction: ptb,
            signer,
            include: txInclude,
        })
        return SuiClient.waitForTransaction(ptb, result)
    }

    // When `type` is omitted, inference is coarse: any `number` becomes u64 and any
    // `0x…`-prefixed string becomes an object ref. Callers passing a number meant for
    // u8/u16/u32 or an address-shaped string meant for pure.address must set `type`
    // explicitly to avoid silent mis-encoding.
    public static toMoveArg(ptb: Transaction, value: any, type?: MoveType) {
        if (typeof value === 'object' && !Array.isArray(value)) {
            return value
        }

        if (!type) {
            if (typeof value === 'string') {
                if (value.startsWith('0x')) {
                    type = MoveType.object
                } else {
                    type = MoveType.string
                }
            } else if (typeof value === 'boolean') {
                type = MoveType.bool
            } else if (typeof value === 'number' || typeof value === 'bigint') {
                type = MoveType.u64
            }
        }

        const factory = {
            [MoveType.u8]: (v: any) => ptb.pure.u8(v),
            [MoveType.u16]: (v: any) => ptb.pure.u16(v),
            [MoveType.u32]: (v: any) => ptb.pure.u32(v),
            [MoveType.u64]: (v: any) => ptb.pure.u64(v),
            [MoveType.u128]: (v: any) => ptb.pure.u128(v),
            [MoveType.u256]: (v: any) => ptb.pure.u256(v),
            [MoveType.bool]: (v: any) => ptb.pure.bool(v),
            [MoveType.string]: (v: any) => ptb.pure.string(v),
            [MoveType.string_opt]: (v: any) => ptb.pure.option('string', v),
            [MoveType.object]: (v: any) => ptb.object(v),
            [MoveType.address]: (v: any) => ptb.pure.address(v),
            [MoveType.address_opt]: (v: any) => ptb.pure.option('address', v),
            [MoveType.vec_address]: (v: any) => ptb.pure.vector('address', v),
            [MoveType.vec_u64]: (v: any) => ptb.pure.vector('u64', v),
        }

        return factory[type!](value)
    }

    public static async moveCall({
        signer,
        target,
        typeArgs = [],
        args = [],
        argTypes = [],
        ptb,
        withTransfer = false,
    }: {
        signer: Keypair
        target: string
        typeArgs?: string[]
        args?: any[]
        argTypes?: MoveType[]
        ptb?: Transaction
        withTransfer?: boolean
    }) {
        ptb = this.getPTB(
            target,
            typeArgs,
            args,
            argTypes,
            signer.toSuiAddress(),
            withTransfer,
            ptb
        )

        return SuiClient.signAndExecute(ptb, signer)
    }

    public static async getMoveCallBytes({
        signer,
        target,
        typeArgs = [],
        args = [],
        argTypes = [],
        ptb,
        withTransfer = false,
        gasOwner,
        format = FORMAT_TYPES.hex,
    }: {
        signer: string
        target: string
        typeArgs?: string[]
        args?: any[]
        argTypes?: MoveType[]
        ptb?: Transaction
        withTransfer?: boolean
        gasOwner?: string
        format?: FORMAT_TYPES
    }) {
        ptb = this.getPTB(target, typeArgs, args, argTypes, signer, withTransfer, ptb)
        return await this.getMoveCallBytesFromPTB(ptb, signer, gasOwner, format)
    }

    public static async getMoveCallBytesFromPTB(
        ptb: Transaction,
        signer: string,
        gasOwner?: string,
        format: FORMAT_TYPES = FORMAT_TYPES.hex
    ) {
        ptb.setSender(signer)
        gasOwner ??= signer
        ptb.setGasOwner(gasOwner || signer)
        const bytes = await ptb.build({ client: SuiClient.client, onlyTransactionKind: false })
        return toFormatType(format, bytes)
    }

    public static toBytes(bytes: Uint8Array | string) {
        if (typeof bytes === 'string') {
            return isHex(bytes) ? fromHex(bytes) : fromBase64(bytes)
        }
        return bytes
    }

    public static async getSignature(signatureOrKeypair: string | Keypair, bytes: Uint8Array) {
        if (typeof signatureOrKeypair !== 'string') {
            const signature = await signatureOrKeypair.signTransaction(bytes)
            return signature.signature
        }

        return isHex(signatureOrKeypair) ? hexToBase64(signatureOrKeypair) : signatureOrKeypair
    }

    public static async executeMoveCallBytes(
        bytes: Uint8Array | string,
        senderSignature: string | Keypair,
        gasOwnerSignature?: string | Keypair
    ) {
        const transactionBlock = this.toBytes(bytes)
        senderSignature = await this.getSignature(senderSignature, transactionBlock)

        const signature = [senderSignature]
        if (gasOwnerSignature) {
            gasOwnerSignature = await this.getSignature(gasOwnerSignature, transactionBlock)
            signature.push(gasOwnerSignature)
        }

        let result: any
        try {
            result = await SuiClient.client.executeTransaction({
                transaction: transactionBlock,
                signatures: signature,
                include: txInclude,
            })
        } catch (e: any) {
            console.error('[executeMoveCallBytes FAILED]', e?.message?.slice(0, 150) || e)
            throw e
        }
        const ptb = Transaction.from(toBase64(transactionBlock))
        return SuiClient.waitForTransaction(ptb, result)
    }

    public static getPTB(
        target: string,
        typeArgs: string[] = [],
        args: any[] = [],
        argTypes: MoveType[] = [],
        signer?: string,
        withTransfer: boolean = false,
        ptb?: Transaction
    ) {
        ptb = ptb || new Transaction()
        const obj = ptb.moveCall({
            target,
            typeArguments: typeArgs,
            arguments: args.map((arg, i) => SuiClient.toMoveArg(ptb, arg, argTypes[i])),
        })

        if (withTransfer && signer) {
            ptb.transferObjects([obj], signer)
        }
        return ptb
    }

    public static async public_transfer(objects: string[], from: Keypair, to: string) {
        const tx = new Transaction()
        tx.transferObjects(objects, to)
        return await SuiClient.signAndExecute(tx, from)
    }

    public static async devInspect(ptb: Transaction, sender: string) {
        ptb.setSenderIfNotSet(sender)
        try {
            const result = await SuiClient.client.simulateTransaction({
                transaction: ptb,
                checksEnabled: false,
                include: { commandResults: true },
            })
            return result
        } catch (e: any) {
            console.error('[devInspect FAILED]', e?.message?.slice(0, 150) || e)
            throw e
        }
    }

    public static async devInspectRaw(ptb: Transaction, sender: string) {
        const result = await this.devInspect(ptb, sender)
        return result.commandResults?.[0]?.returnValues?.[0]?.bcs
    }

    public static async devInspectBool(ptb: Transaction, sender: string) {
        const result = await this.devInspectRaw(ptb, sender)
        return result && result[0] === 1
    }

    public static async devInspectU64(ptb: Transaction, sender: string) {
        const value = await this.devInspectRaw(ptb, sender)
        if (!value) {
            throw new Error(
                'devInspectU64 received empty result - the Move function may have aborted'
            )
        }
        return BigInt(bcs.u64().parse(new Uint8Array(value)))
    }

    public static async devInspectOptionU64(
        ptb: Transaction,
        sender: string
    ): Promise<bigint | null> {
        const value = await this.devInspectRaw(ptb, sender)
        if (!value) return null
        const parsed = bcs.option(bcs.u64()).parse(new Uint8Array(value))
        return parsed === null ? null : BigInt(parsed)
    }

    public static async devInspectAddress(ptb: Transaction, sender: string) {
        const value = await this.devInspectRaw(ptb, sender)
        if (!value) {
            return undefined
        }
        const bytes = Uint8Array.from(value)
        return '0x' + Buffer.from(bytes).toString('hex')
    }

    public static async devInspectString(ptb: Transaction, sender: string) {
        const value = await this.devInspectRaw(ptb, sender)
        if (!value) {
            return ''
        }
        return bcs.string().parse(new Uint8Array(value!))
    }

    public static async getObject(id: string) {
        const { object } = await SuiClient.client.getObject({
            objectId: id,
            include: { json: true },
        })
        // gRPC JSON returns flat Move struct content (no nested { fields: ... } wrappers).
        // We put the raw JSON directly into content.fields so downstream code accesses it
        // via (res.data?.content as any)?.fields.X — then accesses nested structs directly
        // as X.Y instead of X.fields.Y.
        return {
            data: {
                objectId: object.objectId,
                type: object.type,
                version: object.version,
                digest: object.digest,
                content: object.json != null ? { fields: object.json } : undefined,
            },
        }
    }

    /**
     * Reads a value from a Table/Bag dynamic field (not dynamic_object_field).
     * Table uses dynamic_field internally, so getDynamicObjectField (which wraps
     * the type as Wrapper<T>) derives the wrong field ID. Instead, we use
     * getDynamicField to get the fieldId, then getObject with JSON to read
     * the field content, and return the `value` portion.
     */
    public static async getDynamicFieldValue(
        parentId: string,
        nameType: string,
        nameBcs: Uint8Array,
    ): Promise<any> {
        const { dynamicField } = await SuiClient.client.core.getDynamicField({
            parentId,
            name: { type: nameType, bcs: nameBcs },
        })
        const { object } = await SuiClient.client.getObject({
            objectId: dynamicField.fieldId,
            include: { json: true },
        })
        return (object as any).json?.value
    }

    public static async getObjectsByType(owner: string, type: string) {
        const ids: string[] = []
        let cursor: string | null | undefined = undefined
        let hasNextPage = true
        while (hasNextPage) {
            const res: any = await SuiClient.client.listOwnedObjects({
                owner,
                type,
                cursor: cursor ?? undefined,
            })
            for (const o of res.objects as any[]) {
                if (o?.objectId) ids.push(o.objectId)
            }
            hasNextPage = res.hasNextPage
            cursor = res.cursor
        }
        return ids
    }
}
