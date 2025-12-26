import {Transaction} from "@mysten/sui/transactions";
import {SuiClient} from "../easysui";
import {Keypair} from "@mysten/sui/cryptography";

export abstract class Bulk {
    private readonly maxSize: number;

    protected constructor(maxSize: number) {
        this.maxSize = maxSize
    }

    /**
     * Gets the txBytes a bulk PTB
     *
     * @param items - Array of items to process
     * @param signer - The signer address
     * @param buildOperation - Function that adds operations to the PTB for each item
     * @returns The transaction bytes for all the items
     */
    protected async bulkCall<T>(
        items: T[],
        signer: string,
        buildOperation: (item: T, ptb: Transaction) => void,
    ): Promise<string> {
        if (items.length > this.maxSize) {
            throw `You can only perform ${this.maxSize} transactions.`
        }

        const ptb = new Transaction();
        items.forEach(item => buildOperation(item, ptb))
        return SuiClient.getMoveCallBytesFromPTB(ptb, signer)
    }

    private chunkArray<T>(arr: T[]): T[][] {
        const result: T[][] = []
        for (let i = 0; i < arr.length; i += this.maxSize) {
            result.push(arr.slice(i, i + this.maxSize))
        }
        return result
    }

    /**
     * Executes the operations into one chunk at a time.
     *
     * @param items - Array of items to process
     * @param signer - The signer address
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
}
