import {SuiClient} from "../easysui";
import {Config} from "./utils/config";
import {getTokenDetails} from "./token";
import {AbilityType, newPTBDetails, PTBDetails, RoleTypes} from "./domains";
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

    private buildSetBytes(ptb: Transaction, signer: string) {
        return SuiClient.getMoveCallBytesFromPTB(ptb, signer)
    }

    /**
     * Helper function to build role PTB calls
     * Handles both deployment (using ptbDetails.tokenDetails) and post-deployment (using derived IDs)
     */
    private buildRolePTB(func: string, owner: string, ptbDetails?: PTBDetails) {
        ptbDetails ??= newPTBDetails()
        const ptb = ptbDetails.ptb
        ptb.moveCall({
            target: this.getTarget(func),
            typeArguments: [this.tokenAddress],
            arguments: [
                ptbDetails.tokenDetails?.auth || ptb.object(this.tokenDetails.auth),
                ptb.pure.address(owner),
                ptb.object(Config.vars.VERSION),
            ],
        })
        return ptb
    }

    // ==== View Functions ====

    async getRole(owner: string): Promise<RoleTypes> {
        const ptb = this.buildGetPTB('get_role', [owner])
        const chainRoleRaw = await SuiClient.devInspectString(ptb, owner)
        let chainRole = chainRoleRaw.split("::").pop()
        chainRole = chainRole ? chainRole : "none"

        const MAPPING: Record<string, string> = {
            none: "none",
            None: "none",
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
        const ptbDetails = this.updateRolePTB(owner, role, undefined, currentRole)
        return this.buildSetBytes(ptbDetails.ptb, signer)
    }

    updateRolePTB(owner: string, role: RoleTypes, ptbDetails?: PTBDetails, currentRole: RoleTypes = 'none') {
        ptbDetails ??= newPTBDetails()
        const errorMessage = "No direct role-to-role change"

        if (currentRole === role || currentRole === "master") {
            throw new Error(errorMessage)
        }

        const REMOVE_MAPPING: Record<string, (owner: string, ptbDetails: PTBDetails) => void> = {
            issuer: this.removeIssuerPTB,
            exchange: this.removeExchangePTB,
            transfer_agent: this.removeTransferAgentPTB,
        }

        const ADD_MAPPING: Record<string, (owner: string, ptbDetails: PTBDetails) => void> = {
            master: this.setServiceOwnerPTB,
            issuer: this.setIssuerPTB,
            exchange: this.setExchangePTB,
            transfer_agent: this.setTransferAgentPTB,
        }

        if (currentRole in REMOVE_MAPPING) {
            REMOVE_MAPPING[currentRole](owner, ptbDetails)
        }

        if (role in ADD_MAPPING) {
            ADD_MAPPING[role](owner, ptbDetails)
        }

        return ptbDetails
    }

    // ==== Transfer Agent ====

    setTransferAgentPTB = (owner: string, ptbDetails?: PTBDetails) =>
        this.buildRolePTB('set_transfer_agent', owner, ptbDetails)

    async setTransferAgent(owner: string, signer: string) {
        return this.buildSetBytes(this.setTransferAgentPTB(owner), signer)
    }

    removeTransferAgentPTB = (owner: string, ptbDetails?: PTBDetails) =>
        this.buildRolePTB('remove_transfer_agent', owner, ptbDetails)

    async removeTransferAgent(owner: string, signer: string) {
        return this.buildSetBytes(this.removeTransferAgentPTB(owner), signer)
    }

    // ==== Issuer ====

    setIssuerPTB = (owner: string, ptbDetails?: PTBDetails) =>
        this.buildRolePTB('set_issuer', owner, ptbDetails)

    async setIssuer(owner: string, signer: string) {
        return this.buildSetBytes(this.setIssuerPTB(owner), signer)
    }

    removeIssuerPTB = (owner: string, ptbDetails?: PTBDetails) =>
        this.buildRolePTB('remove_issuer', owner, ptbDetails)

    async removeIssuer(owner: string, signer: string) {
        return this.buildSetBytes(this.removeIssuerPTB(owner), signer)
    }

    // ==== Service Owner (Master) ====

    setServiceOwnerPTB = (owner: string, ptbDetails?: PTBDetails) =>
        this.buildRolePTB('set_service_owner', owner, ptbDetails)

    async setServiceOwner(owner: string, signer: string) {
        return this.buildSetBytes(this.setServiceOwnerPTB(owner), signer)
    }

    // ==== Exchange ====

    setExchangePTB = (owner: string, ptbDetails?: PTBDetails) =>
        this.buildRolePTB('set_exchange', owner, ptbDetails)

    async setExchange(owner: string, signer: string) {
        return this.buildSetBytes(this.setExchangePTB(owner), signer)
    }

    removeExchangePTB = (owner: string, ptbDetails?: PTBDetails) =>
        this.buildRolePTB('remove_exchange', owner, ptbDetails)

    async removeExchange(owner: string, signer: string) {
        return this.buildSetBytes(this.removeExchangePTB(owner), signer)
    }

    // ==== Ability Management Functions ====

    private getRoleTypePath(role: RoleTypes): string {
        const ROLE_TYPE_MAP: Record<RoleTypes, string> = {
            none: `${Config.vars.PACKAGE_ID}::trust_service::None`,
            master: `${Config.vars.PACKAGE_ID}::trust_service::Master`,
            issuer: `${Config.vars.PACKAGE_ID}::trust_service::Issuer`,
            exchange: `${Config.vars.PACKAGE_ID}::trust_service::Exchange`,
            transfer_agent: `${Config.vars.PACKAGE_ID}::trust_service::TransferAgent`,
        }
        return ROLE_TYPE_MAP[role]
    }

    private getAbilityTypePath(ability: AbilityType): string {
        return `${Config.vars.PACKAGE_ID}::abilities::${ability}`
    }

    /**
     * Add an ability to a role. Only Master can call this.
     */
    addRoleAbilityPTB(role: RoleTypes, ability: AbilityType, ptbDetails?: PTBDetails): Transaction {
        ptbDetails ??= newPTBDetails()
        const ptb = ptbDetails.ptb
        const roleType = this.getRoleTypePath(role)
        const abilityType = this.getAbilityTypePath(ability)

        ptb.moveCall({
            target: this.getTarget('add_role_ability'),
            typeArguments: [this.tokenAddress, roleType, abilityType],
            arguments: [
                ptbDetails.tokenDetails?.auth || ptb.object(this.tokenDetails.auth),
                ptb.object(Config.vars.VERSION),
            ],
        })
        return ptb
    }

    async addRoleAbility(role: RoleTypes, ability: AbilityType, signer: string) {
        return this.buildSetBytes(this.addRoleAbilityPTB(role, ability), signer)
    }

    /**
     * Remove an ability from a role. Only Master can call this.
     */
    removeRoleAbilityPTB(role: RoleTypes, ability: AbilityType, ptbDetails?: PTBDetails): Transaction {
        ptbDetails ??= newPTBDetails()
        const ptb = ptbDetails.ptb
        const roleType = this.getRoleTypePath(role)
        const abilityType = this.getAbilityTypePath(ability)

        ptb.moveCall({
            target: this.getTarget('remove_role_ability'),
            typeArguments: [this.tokenAddress, roleType, abilityType],
            arguments: [
                ptbDetails.tokenDetails?.auth || ptb.object(this.tokenDetails.auth),
                ptb.object(Config.vars.VERSION),
            ],
        })
        return ptb
    }

    async removeRoleAbility(role: RoleTypes, ability: AbilityType, signer: string) {
        return this.buildSetBytes(this.removeRoleAbilityPTB(role, ability), signer)
    }
}
