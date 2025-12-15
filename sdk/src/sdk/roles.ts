import {SuiClient} from "../easysui";
import {Config} from "./utils/config";
import {getTokenDetails} from "./token";
import {RoleTypes} from "./domains/Role";
import {Transaction} from "@mysten/sui/transactions";

export class Roles {
    private readonly tokenAddress: string;
    private readonly tokenDetails: any;

    constructor(tokenAddress: string) {
        this.tokenAddress = tokenAddress;
        this.tokenDetails = getTokenDetails(tokenAddress);
    }

    private getTarget(func: string) {
        return `${Config.vars.PACKAGE_ID}::trust_service::${func}`
    }

    private buildGetPTB(func: string, args: any[]) {
        return SuiClient.getPTB(
            this.getTarget(func),
            [this.tokenAddress],
            [this.tokenDetails.auth, ...args],
        )
    }

    private buildSetPTB(func: string, args: any[], ptb?: Transaction) {
        return SuiClient.getPTB(
            this.getTarget(func),
            [this.tokenAddress],
            [
                this.tokenDetails.auth,
                ...args,
                Config.vars.VERSION
            ],
            [],
            undefined,
            false,
            ptb
        )
    }

    private buildSetBytes(ptb: Transaction, signer: string) {
        return SuiClient.getMoveCallBytesFromPTB(ptb, signer)
    }

    // ==== View Functions ====

    async getRole(owner: string): Promise<RoleTypes> {
        const ptb = this.buildGetPTB('get_role', [owner])
        const chainRoleRaw = await SuiClient.devInspectString(ptb, owner)
        let chainRole = chainRoleRaw.split("::").pop()
        chainRole = chainRole ? chainRole : "none"

        const MAPPING: Record<string, string> = {
            none: "none",
            Master: "master",
            Issuer: "issuer",
            Exchange: "exchange",
            TransferAgent: "transfer_agent",
        }

        return MAPPING[chainRole] as RoleTypes
    }

    // ==== Role Management Functions ====

    async updateRole(owner: string, role: RoleTypes, signer: string) {
        const currentRole = await this.getRole(owner)
        let ptb = this.updateRolePTB(owner, role, undefined, currentRole)
        return this.buildSetBytes(ptb, signer)
    }

    updateRolePTB(owner: string, role: RoleTypes, ptb?: Transaction, currentRole: RoleTypes = 'none') {
        const errorMessage = "No direct role-to-role change"

        if (currentRole === role || currentRole === "master") {
            throw new Error(errorMessage)
        }

        const REMOVE_MAPPING: Record<string, (owner: string, ptb?: Transaction) => Transaction> = {
            issuer: this.removeIssuerPTB,
            exchange: this.removeExchangePTB,
            transfer_agent: this.removeTransferAgentPTB,
        }

        const ADD_MAPPING: Record<string, (owner: string, ptb?: Transaction) => Transaction> = {
            master: this.setServiceOwnerPTB,
            issuer: this.setIssuerPTB,
            exchange: this.setExchangePTB,
            transfer_agent: this.setTransferAgentPTB,
        }

        ptb ??= new Transaction()

        if (currentRole in REMOVE_MAPPING) {
            ptb = REMOVE_MAPPING[currentRole](owner, ptb)
        }

        if (role in ADD_MAPPING) {
            ptb = ADD_MAPPING[role](owner, ptb)
        }

        if (!ptb) {
            throw new Error(errorMessage)
        }
        return ptb;
    }

    setTransferAgentPTB = (owner: string, ptb?: Transaction)  => this.buildSetPTB('set_transfer_agent', [owner], ptb)
    async setTransferAgent(owner: string, signer: string) {
        const ptb = this.setTransferAgentPTB(owner);
        return this.buildSetBytes(ptb, signer)
    }

    removeTransferAgentPTB = (owner: string, ptb?: Transaction)  => this.buildSetPTB('remove_transfer_agent', [owner], ptb)
    async removeTransferAgent(owner: string, signer: string) {
        const ptb = this.removeTransferAgentPTB(owner);
        return this.buildSetBytes(ptb, signer)
    }

    setIssuerPTB = (owner: string, ptb?: Transaction) => this.buildSetPTB('set_issuer', [owner], ptb)
    async setIssuer(owner: string, signer: string) {
        const ptb = this.setIssuerPTB(owner);
        return this.buildSetBytes(ptb, signer)
    }

    removeIssuerPTB = (owner: string, ptb?: Transaction) => this.buildSetPTB('remove_issuer', [owner], ptb)
    async removeIssuer(owner: string, signer: string) {
        const ptb = this.removeIssuerPTB(owner);
        return this.buildSetBytes(ptb, signer)
    }

    setServiceOwnerPTB = (owner: string, ptb?: Transaction)  => this.buildSetPTB('set_service_owner', [owner], ptb)
    async setServiceOwner(owner: string, signer: string) {
        const ptb = this.setServiceOwnerPTB(owner);
        return this.buildSetBytes(ptb, signer)
    }

    removeExchangePTB = (owner: string, ptb?: Transaction) => this.buildSetPTB('remove_exchange', [owner], ptb)
    async removeExchange(owner: string, signer: string) {
        const ptb = this.removeExchangePTB(owner);
        return this.buildSetBytes(ptb, signer)
    }

    setExchangePTB = (owner: string, ptb?: Transaction) => this.buildSetPTB('set_exchange', [owner], ptb)
    async setExchange(owner: string, signer: string) {
        const ptb = this.setExchangePTB(owner);
        return this.buildSetBytes(ptb, signer)
    }
}
