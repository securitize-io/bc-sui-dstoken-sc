import {Transaction} from "@mysten/sui/transactions";
import {SuiClient} from "../easysui";
import {Keypair} from "@mysten/sui/cryptography";

export abstract class Bulk {
    private readonly maxSize: number;

    protected constructor(maxSize: number) {
        this.maxSize = maxSize
    }

    /**
     * Builds transaction bytes for a bulk operation.
     *
     * @param items - Array of items to process
     * @param signer - The signer address (string)
     * @param buildOperation - Function that adds operations to the PTB for each item
     * @returns The transaction bytes for all the items
     */
    protected async bulkCall<T>(
        items: T[],
        signer: string,
        buildOperation: (item: T, ptb: Transaction) => void,
    ): Promise<string> {
        if (items.length > this.maxSize) {
            throw new Error(`You can only perform ${this.maxSize} transactions.`)
        }

        const ptb = new Transaction();
        items.forEach(item => buildOperation(item, ptb))
        return SuiClient.getMoveCallBytesFromPTB(ptb, signer)
    }

    /**
     * Builds transaction bytes for each chunk of a bulk operation.
     * Returns an array of transaction bytes, one per chunk.
     *
     * @param items - Array of items to process
     * @param signer - The signer address (string)
     * @param buildOperation - Function that adds operations to the PTB for each item
     * @returns Array of transaction bytes, one per chunk
     */
    protected async bulkBytes<T>(
        items: T[],
        signer: string,
        buildOperation: (item: T, ptb: Transaction) => void,
    ): Promise<string[]> {
        const chunks = this.chunkArray(items)
        const results: string[] = []

        for (const chunk of chunks) {
            const bytes = await this.bulkCall(chunk, signer, buildOperation)
            results.push(bytes)
        }

        return results
    }

    /**
     * Executes bulk operations using a Keypair (signs and submits each chunk).
     *
     * @param items - Array of items to process
     * @param signer - The signer Keypair
     * @param buildOperation - Function that adds operations to the PTB for each item
     */
    protected async bulkExecution<T>(
        items: T[],
        signer: Keypair,
        buildOperation: (item: T, ptb: Transaction) => void,
    ) {
        const chunks = this.chunkArray(items)

        for (const chunk of chunks) {
            const bytes = await this.bulkCall(chunk, signer.toSuiAddress(), buildOperation)
            await SuiClient.executeMoveCallBytes(bytes, signer)
        }
    }

    // ==== Private Helpers ====

    private chunkArray<T>(arr: T[]): T[][] {
        const result: T[][] = []
        for (let i = 0; i < arr.length; i += this.maxSize) {
            result.push(arr.slice(i, i + this.maxSize))
        }
        return result
    }
}
