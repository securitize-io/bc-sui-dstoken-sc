import {SuiClient} from "../easysui";
import {Config} from "./utils/config";
import {getTokenDetails, TokenDetails} from "./token";
import {AbilityType, newPTBDetails, PTBDetails, RoleTypes} from "./domains";
import {Transaction} from "@mysten/sui/transactions";
import {normalizeSuiAddress} from "@mysten/sui/utils";
import * as trustService from "../generated/securitize/trust_service";

export class Roles {
    private readonly tokenAddress: string;
    private readonly tokenDetails: TokenDetails;

    constructor(tokenAddress: string) {
        this.tokenAddress = tokenAddress;
        this.tokenDetails = getTokenDetails(tokenAddress);
    }

    // ==== View Functions ====

    /** Returns the role assigned to an address (master, issuer, exchange, transfer_agent, or none). */
    async getRole(owner: string): Promise<RoleTypes> {
        const ptb = new Transaction()
        trustService.getRole({
            package: this.pkg,
            arguments: { self: this.tokenDetails.auth, owner },
            typeArguments: this.typeArgs,
        })(ptb)
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

    // ==== Role Management ====

    updateRolePTB(owner: string, role: RoleTypes, ptbDetails?: PTBDetails, currentRole: RoleTypes = 'none') {
        ptbDetails ??= newPTBDetails()

        if (role === 'master') {
            throw new Error('updateRolePTB does not support promoting to master — use setServiceOwner')
        }

        if (currentRole === role || currentRole === "master") {
            throw new Error("No direct role-to-role change")
        }

        const REMOVE_MAPPING: Record<string, (owner: string, ptbDetails: PTBDetails) => void> = {
            issuer: this.removeIssuerPTB,
            exchange: this.removeExchangePTB,
            transfer_agent: this.removeTransferAgentPTB,
        }

        if (currentRole in REMOVE_MAPPING) {
            REMOVE_MAPPING[currentRole](owner, ptbDetails)
        }

        const ADD_MAPPING: Record<string, (owner: string, ptbDetails: PTBDetails) => void> = {
            issuer: this.setIssuerPTB,
            exchange: this.setExchangePTB,
            transfer_agent: this.setTransferAgentPTB,
        }
        if (role in ADD_MAPPING) {
            ADD_MAPPING[role](owner, ptbDetails)
        }

        return ptbDetails
    }

    /** Assigns a role to an address. Removes the previous role first if one exists. */
    async updateRole(owner: string, role: RoleTypes, signer: string) {
        const currentRole = await this.getRole(owner)
        const ptbDetails = this.updateRolePTB(owner, role, undefined, currentRole)
        return this.buildSetBytes(ptbDetails.ptb, signer)
    }

    // ==== Service Owner (Master) ====

    setServiceOwnerPTB = (owner: string, ptbDetails?: PTBDetails, upgradeCapId?: string) => {
        const ptb = this.buildRolePTB('setServiceOwner', owner, ptbDetails)
        if (upgradeCapId) {
            ptb.transferObjects([ptb.object(upgradeCapId)], owner)
        }
        return ptb
    }

    async setServiceOwner(owner: string, signer: string) {
        const upgradeCapId = await this.findUpgradeCapId(signer)
        if (!upgradeCapId) {
            throw new Error(
                `UpgradeCap not found for package ${this.tokenAddress.split('::')[0]} owned by ${signer}`
            )
        }
        return this.buildSetBytes(this.setServiceOwnerPTB(owner, undefined, upgradeCapId), signer)
    }

    // ==== Issuer ====

    setIssuerPTB = (owner: string, ptbDetails?: PTBDetails) =>
        this.buildRolePTB('setIssuer', owner, ptbDetails)

    async setIssuer(owner: string, signer: string) {
        return this.buildSetBytes(this.setIssuerPTB(owner), signer)
    }

    removeIssuerPTB = (owner: string, ptbDetails?: PTBDetails) =>
        this.buildRolePTB('removeIssuer', owner, ptbDetails)

    async removeIssuer(owner: string, signer: string) {
        return this.buildSetBytes(this.removeIssuerPTB(owner), signer)
    }

    // ==== Transfer Agent ====

    setTransferAgentPTB = (owner: string, ptbDetails?: PTBDetails) =>
        this.buildRolePTB('setTransferAgent', owner, ptbDetails)

    async setTransferAgent(owner: string, signer: string) {
        return this.buildSetBytes(this.setTransferAgentPTB(owner), signer)
    }

    removeTransferAgentPTB = (owner: string, ptbDetails?: PTBDetails) =>
        this.buildRolePTB('removeTransferAgent', owner, ptbDetails)

    async removeTransferAgent(owner: string, signer: string) {
        return this.buildSetBytes(this.removeTransferAgentPTB(owner), signer)
    }

    // ==== Exchange ====

    setExchangePTB = (owner: string, ptbDetails?: PTBDetails) =>
        this.buildRolePTB('setExchange', owner, ptbDetails)

    async setExchange(owner: string, signer: string) {
        return this.buildSetBytes(this.setExchangePTB(owner), signer)
    }

    removeExchangePTB = (owner: string, ptbDetails?: PTBDetails) =>
        this.buildRolePTB('removeExchange', owner, ptbDetails)

    async removeExchange(owner: string, signer: string) {
        return this.buildSetBytes(this.removeExchangePTB(owner), signer)
    }

    // ==== Ability Management ====

    addRoleAbilityPTB(role: RoleTypes, ability: AbilityType, ptbDetails?: PTBDetails): Transaction {
        ptbDetails ??= newPTBDetails()
        const ptb = ptbDetails.ptb
        trustService.addRoleAbility({
            package: this.pkg,
            arguments: {
                self: ptbDetails.tokenDetails?.auth || this.tokenDetails.auth,
                version: Config.vars.VERSION,
            },
            typeArguments: [this.tokenAddress, this.getRoleTypePath(role), this.getAbilityTypePath(ability)],
        })(ptb)
        return ptb
    }

    /** Grants an ability to a role. Only Master can call this. */
    async addRoleAbility(role: RoleTypes, ability: AbilityType, signer: string) {
        return this.buildSetBytes(this.addRoleAbilityPTB(role, ability), signer)
    }

    removeRoleAbilityPTB(role: RoleTypes, ability: AbilityType, ptbDetails?: PTBDetails): Transaction {
        ptbDetails ??= newPTBDetails()
        const ptb = ptbDetails.ptb
        trustService.removeRoleAbility({
            package: this.pkg,
            arguments: {
                self: ptbDetails.tokenDetails?.auth || this.tokenDetails.auth,
                version: Config.vars.VERSION,
            },
            typeArguments: [this.tokenAddress, this.getRoleTypePath(role), this.getAbilityTypePath(ability)],
        })(ptb)
        return ptb
    }

    /** Removes an ability from a role. Only Master can call this. */
    async removeRoleAbility(role: RoleTypes, ability: AbilityType, signer: string) {
        return this.buildSetBytes(this.removeRoleAbilityPTB(role, ability), signer)
    }

    // ==== Private Helpers ====

    private get pkg() {
        return Config.vars.PACKAGE_ID
    }

    private get typeArgs(): [string] {
        return [this.tokenAddress]
    }

    private buildSetBytes(ptb: Transaction, signer: string) {
        return SuiClient.getMoveCallBytesFromPTB(ptb, signer)
    }

    private buildRolePTB(func: keyof typeof trustService, owner: string, ptbDetails?: PTBDetails) {
        ptbDetails ??= newPTBDetails()
        const ptb = ptbDetails.ptb;
        (trustService[func] as Function)({
            package: this.pkg,
            arguments: {
                self: ptbDetails.tokenDetails?.auth || this.tokenDetails.auth,
                owner,
                version: Config.vars.VERSION,
            },
            typeArguments: this.typeArgs,
        })(ptb)
        return ptb
    }

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

    // Auto-discovery matches the original publish package ID against UpgradeCap.package.
    // After a token-package upgrade, `commit_upgrade` overwrites that field with the new
    // package ID, so this returns undefined for upgraded token packages — callers must
    // then pass `upgradeCapId` explicitly to `setServiceOwnerPTB`. Token packages are not
    // expected to be upgraded in practice.
    private async findUpgradeCapId(owner: string): Promise<string | undefined> {
        const tokenPackageId = normalizeSuiAddress(this.tokenAddress.split('::')[0])
        let cursor: string | null | undefined = undefined
        let hasNextPage = true

        while (hasNextPage) {
            const response: any = await SuiClient.client.listOwnedObjects({
                owner,
                type: '0x2::package::UpgradeCap',
                include: { json: true },
                cursor: cursor ?? undefined,
            })
            const match = response.objects.find((o: any) => {
                return normalizeSuiAddress(o.json?.package) === tokenPackageId
            })
            if (match) {
                return match.objectId
            }
            hasNextPage = response.hasNextPage
            cursor = response.cursor
        }

        return undefined
    }
}
