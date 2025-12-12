import {MoveType, SuiClient} from "../easysui";
import {Config} from "./utils/config";
import {getTokenDetails} from "./token";
import {Transaction} from "@mysten/sui/transactions";

// COMMON

function getTarget(func: string) {
    return `${Config.vars.PACKAGE_ID}::registry_service::${func}`
}

// GETTERS

export async function isInvestor(sender: string, tokenAddress: string, investorId: string,) {
    const tokenDetails = getTokenDetails(tokenAddress)
    const ptb = SuiClient.getPTB(
        getTarget('is_investor'),
        sender,
        [tokenAddress],
        [tokenDetails.investorInfo, investorId]
    )
    return SuiClient.devInspectBool(ptb, sender)
}

// SETTERS

export async function registerInvestor(signer: string, tokenAddress: string, investorId: string) {
    const tokenDetails = getTokenDetails(tokenAddress)
    return SuiClient.getMoveCallBytes({
        signer,
        target: getTarget('register_investor'),
        typeArgs: [tokenAddress],
        args: [
            tokenDetails.investorInfo,
            tokenDetails.auth,
            investorId,
            Config.vars.VERSION
        ],
    })
}

export async function removeInvestor(signer: string, tokenAddress: string, investorId: string) {
    const tokenDetails = getTokenDetails(tokenAddress)
    return SuiClient.getMoveCallBytes({
        signer,
        target: getTarget('remove_investor'),
        typeArgs: [tokenAddress],
        args: [
            tokenDetails.investorInfo,
            tokenDetails.auth,
            investorId,
            Config.vars.VERSION
        ],
    })
}

export async function updateInvestor(
    signer: string,
    tokenAddress: string,
    investorId: string,
    country: string,
    wallets: string[],
    attributeIds: number[],
    attributeValues: number[],
    attributeExpirations: number[],
) {
    const tokenDetails = getTokenDetails(tokenAddress)
    return SuiClient.getMoveCallBytes({
        signer,
        target: getTarget('update_investor'),
        typeArgs: [tokenAddress],
        args: [
            tokenDetails.investorInfo,
            tokenDetails.auth,
            investorId,
            country,
            wallets,
            attributeIds,
            attributeValues,
            attributeExpirations,
            Config.vars.VERSION
        ],
        argTypes: [
            MoveType.object,
            MoveType.object,
            MoveType.string,
            MoveType.string,
            MoveType.vec_address,
            MoveType.vec_u64,
            MoveType.vec_u64,
            MoveType.vec_u64,
            MoveType.object,
        ]
    })
}

export async function removeWallet(
    signer: string,
    tokenAddress: string,
    investorId: string,
    wallet: string
) {
    const tokenDetails = getTokenDetails(tokenAddress)
    return SuiClient.getMoveCallBytes({
        signer,
        target: getTarget('remove_wallet'),
        typeArgs: [tokenAddress],
        args: [
            tokenDetails.investorInfo,
            tokenDetails.auth,
            investorId,
            wallet,
            Config.vars.VERSION
        ],
    })
}

export async function setAttribute(
    signer: string,
    tokenAddress: string,
    investorId: string,
    attributeId: number,
    attributeValue: number,
    attributeExpiration: number,
) {
    const tokenDetails = getTokenDetails(tokenAddress)
    return SuiClient.getMoveCallBytes({
        signer,
        target: getTarget('set_attribute'),
        typeArgs: [tokenAddress],
        args: [
            tokenDetails.investorInfo,
            tokenDetails.auth,
            investorId,
            attributeId,
            attributeValue,
            attributeExpiration,
            Config.vars.VERSION
        ],
    })
}