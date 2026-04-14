/**************************************************************
 * THIS FILE IS GENERATED AND SHOULD NOT BE MANUALLY MODIFIED *
 **************************************************************/


/**
 * Module: wallet_manager
 * 
 * This module manages special wallets for security tokens. Special wallets are
 * designated addresses Issuer, Platform that have special privileges in the token
 * ecosystem and are not associated with regular investors.
 */

import { type Transaction } from '@mysten/sui/transactions';
import { normalizeMoveArguments, type RawTransactionArgument } from '../utils/index.js';
export interface AddIssuerWalletArguments {
    investorInfo: RawTransactionArgument<string>;
    auth: RawTransactionArgument<string>;
    namespace: RawTransactionArgument<string>;
    wallet: RawTransactionArgument<string>;
    version: RawTransactionArgument<string>;
}
export interface AddIssuerWalletOptions {
    package?: string;
    arguments: AddIssuerWalletArguments | [
        investorInfo: RawTransactionArgument<string>,
        auth: RawTransactionArgument<string>,
        namespace: RawTransactionArgument<string>,
        wallet: RawTransactionArgument<string>,
        version: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/**
 * Adds a wallet address as an issuer wallet. Only authorized addresses with the
 * SetIssuerWallet ability can call this function.
 *
 * # Aborts
 *
 * - `ENotAuthorized` - If caller lacks SetIssuerWallet ability
 * - `EWalletBelongsToInvestor` - If the wallet belongs to an investor
 * - `EDirectWalletChange` - If the wallet is already a special wallet
 */
export function addIssuerWallet(options: AddIssuerWalletOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        null,
        null,
        'address',
        null
    ] satisfies (string | null)[];
    const parameterNames = ["investorInfo", "auth", "namespace", "wallet", "version"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'wallet_manager',
        function: 'add_issuer_wallet',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface AddPlatformWalletArguments {
    investorInfo: RawTransactionArgument<string>;
    auth: RawTransactionArgument<string>;
    namespace: RawTransactionArgument<string>;
    wallet: RawTransactionArgument<string>;
    version: RawTransactionArgument<string>;
}
export interface AddPlatformWalletOptions {
    package?: string;
    arguments: AddPlatformWalletArguments | [
        investorInfo: RawTransactionArgument<string>,
        auth: RawTransactionArgument<string>,
        namespace: RawTransactionArgument<string>,
        wallet: RawTransactionArgument<string>,
        version: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/**
 * Adds a wallet address as a platform wallet. Only authorized addresses with the
 * SetPlatformWallet ability can call this function.
 *
 * # Aborts
 *
 * - `ENotAuthorized` - If caller lacks SetPlatformWallet ability
 * - `EWalletBelongsToInvestor` - If the wallet belongs to an investor
 * - `EDirectWalletChange` - If the wallet is already a special wallet
 */
export function addPlatformWallet(options: AddPlatformWalletOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        null,
        null,
        'address',
        null
    ] satisfies (string | null)[];
    const parameterNames = ["investorInfo", "auth", "namespace", "wallet", "version"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'wallet_manager',
        function: 'add_platform_wallet',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface RemoveSpecialWalletArguments {
    investorInfo: RawTransactionArgument<string>;
    auth: RawTransactionArgument<string>;
    wallet: RawTransactionArgument<string>;
    version: RawTransactionArgument<string>;
}
export interface RemoveSpecialWalletOptions {
    package?: string;
    arguments: RemoveSpecialWalletArguments | [
        investorInfo: RawTransactionArgument<string>,
        auth: RawTransactionArgument<string>,
        wallet: RawTransactionArgument<string>,
        version: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/**
 * Removes a special wallet from the registry. Only authorized addresses with the
 * RemoveSpecialWallet ability can call this function.
 *
 * # Aborts
 *
 * - `ENotAuthorized` - If caller lacks RemoveSpecialWallet ability
 * - `ENotSpecialWallet` - If the wallet is not a special wallet
 */
export function removeSpecialWallet(options: RemoveSpecialWalletOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        null,
        'address',
        null
    ] satisfies (string | null)[];
    const parameterNames = ["investorInfo", "auth", "wallet", "version"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'wallet_manager',
        function: 'remove_special_wallet',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface IsPlatformWalletArguments {
    investorInfo: RawTransactionArgument<string>;
    wallet: RawTransactionArgument<string>;
}
export interface IsPlatformWalletOptions {
    package?: string;
    arguments: IsPlatformWalletArguments | [
        investorInfo: RawTransactionArgument<string>,
        wallet: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/** Returns whether the given wallet is a platform wallet. */
export function isPlatformWallet(options: IsPlatformWalletOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        'address'
    ] satisfies (string | null)[];
    const parameterNames = ["investorInfo", "wallet"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'wallet_manager',
        function: 'is_platform_wallet',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface IsIssuerWalletArguments {
    investorInfo: RawTransactionArgument<string>;
    wallet: RawTransactionArgument<string>;
}
export interface IsIssuerWalletOptions {
    package?: string;
    arguments: IsIssuerWalletArguments | [
        investorInfo: RawTransactionArgument<string>,
        wallet: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/** Returns whether the given wallet is an issuer wallet. */
export function isIssuerWallet(options: IsIssuerWalletOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        'address'
    ] satisfies (string | null)[];
    const parameterNames = ["investorInfo", "wallet"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'wallet_manager',
        function: 'is_issuer_wallet',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}