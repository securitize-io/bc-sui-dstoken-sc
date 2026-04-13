/**************************************************************
 * THIS FILE IS GENERATED AND SHOULD NOT BE MANUALLY MODIFIED *
 **************************************************************/


/**
 * Module: registry_service
 * 
 * Manages investor registration and their associated wallets. Stores investor
 * attributes, country information, and tracks wallet-to-investor mappings for
 * compliance verification during token transfers.
 */

import { MoveTuple, MoveStruct, normalizeMoveArguments, type RawTransactionArgument } from '../utils/index.js';
import { bcs } from '@mysten/sui/bcs';
import { type Transaction } from '@mysten/sui/transactions';
import * as table from './deps/sui/table.js';
import * as table_1 from './deps/sui/table.js';
import * as table_2 from './deps/sui/table.js';
import * as table_3 from './deps/sui/table.js';
import * as table_4 from './deps/sui/table.js';
import * as table_5 from './deps/sui/table.js';
import * as table_6 from './deps/sui/table.js';
import * as table_7 from './deps/sui/table.js';
import * as table_8 from './deps/sui/table.js';
const $moduleName = '@securitize/securitize::registry_service';
export const RegistryServiceKey = new MoveTuple({ name: `${$moduleName}::RegistryServiceKey<phantom T>`, fields: [bcs.bool()] });
export const InvestorInfo = new MoveStruct({ name: `${$moduleName}::InvestorInfo<phantom T>`, fields: {
        id: bcs.Address,
        /** Mapping of investor IDs to their investor data */
        investors: table.Table,
        /** Mapping of wallet addresses to their wallet data */
        investor_wallets: table_1.Table,
        /** Mapping of special wallet addresses (e.g., treasury, reserve) */
        special_wallets: table_2.Table,
        /** Mapping of special wallet addresses to balances */
        special_wallets_balance: table_3.Table,
        /** Total number of registered investors */
        total_investors_count: bcs.u64(),
        /** Count of accredited investors across all regions */
        accredited_investors_count: bcs.u64(),
        /** Count of accredited investors in the United States */
        us_accredited_investors_count: bcs.u64(),
        /** Count of all investors in the United States */
        us_investors_count: bcs.u64(),
        /** Count of all investors in Japan */
        jp_investors_count: bcs.u64(),
        /** Count of retail (non-qualified) investors per EU country */
        eu_retail_investors_count: table_4.Table,
        /** Mapping of country codes to their compliance region */
        countries_compliances: table_5.Table,
        /** Investor locks data */
        investor_locks: table_6.Table,
        /** Investor issuances data */
        investor_issuances: table_7.Table
    } });
export const Lock = new MoveStruct({ name: `${$moduleName}::Lock`, fields: {
        value: bcs.u64(),
        reason_code: bcs.u64(),
        reason_string: bcs.string(),
        release_time_ms: bcs.u64()
    } });
export const InvestorLockState = new MoveStruct({ name: `${$moduleName}::InvestorLockState`, fields: {
        fully_locked: bcs.bool(),
        liquidate_only: bcs.bool(),
        locks: bcs.vector(Lock)
    } });
export const Issuance = new MoveStruct({ name: `${$moduleName}::Issuance`, fields: {
        /** Amount of tokens issued */
        amount: bcs.u64(),
        /** Timestamp when tokens were issued (in milliseconds) */
        issuance_time_ms: bcs.u64()
    } });
export const Investor = new MoveStruct({ name: `${$moduleName}::Investor`, fields: {
        /** Address that created this investor record */
        creator: bcs.Address,
        /** Country code of the investor */
        country: bcs.string(),
        /** List of wallet addresses owned by this investor */
        wallets: bcs.vector(bcs.Address),
        /** Compliance attributes (KYC, accreditation, etc.) */
        attributes: table_8.Table,
        /** Total token balance across all wallets */
        total_balance: bcs.u64()
    } });
export const Wallet = new MoveStruct({ name: `${$moduleName}::Wallet`, fields: {
        /** Investor ID that owns this wallet */
        owner: bcs.string(),
        /** Address that linked this wallet to the investor */
        creator: bcs.Address,
        /** Wallet token balance */
        wallet_balance: bcs.u64()
    } });
export const Attribute = new MoveStruct({ name: `${$moduleName}::Attribute`, fields: {
        /** The attribute value (e.g., APPROVED, REJECTED) */
        value: bcs.u64(),
        /** Unix timestamp when this attribute expires */
        expiration: bcs.u64()
    } });
export interface RegisterInvestorArguments {
    investorInfo: RawTransactionArgument<string>;
    auth: RawTransactionArgument<string>;
    investorId: RawTransactionArgument<string>;
    version: RawTransactionArgument<string>;
}
export interface RegisterInvestorOptions {
    package?: string;
    arguments: RegisterInvestorArguments | [
        investorInfo: RawTransactionArgument<string>,
        auth: RawTransactionArgument<string>,
        investorId: RawTransactionArgument<string>,
        version: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/**
 * Registers a new investor in the registry. Only authorized addresses with the
 * RegisterInvestor ability can call this function.
 *
 * # Aborts
 *
 * - `ENotAuthorized` - If the sender does not have the RegisterInvestor ability
 * - `EInvestorExists` - If the investor already exists
 */
export function registerInvestor(options: RegisterInvestorOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        null,
        '0x1::string::String',
        null
    ] satisfies (string | null)[];
    const parameterNames = ["investorInfo", "auth", "investorId", "version"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'registry_service',
        function: 'register_investor',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface RegisterInvestorIfNotExistsArguments {
    investorInfo: RawTransactionArgument<string>;
    auth: RawTransactionArgument<string>;
    investorId: RawTransactionArgument<string>;
    version: RawTransactionArgument<string>;
}
export interface RegisterInvestorIfNotExistsOptions {
    package?: string;
    arguments: RegisterInvestorIfNotExistsArguments | [
        investorInfo: RawTransactionArgument<string>,
        auth: RawTransactionArgument<string>,
        investorId: RawTransactionArgument<string>,
        version: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/**
 * Registers a new investor if they don't already exist. Does nothing if the
 * investor already exists. Only authorized addresses with the RegisterInvestor
 * ability can call this function.
 *
 * # Aborts
 *
 * - `ENotAuthorized` - If the sender does not have the RegisterInvestor ability
 */
export function registerInvestorIfNotExists(options: RegisterInvestorIfNotExistsOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        null,
        '0x1::string::String',
        null
    ] satisfies (string | null)[];
    const parameterNames = ["investorInfo", "auth", "investorId", "version"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'registry_service',
        function: 'register_investor_if_not_exists',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface RemoveInvestorArguments {
    investorInfo: RawTransactionArgument<string>;
    auth: RawTransactionArgument<string>;
    investorId: RawTransactionArgument<string>;
    version: RawTransactionArgument<string>;
}
export interface RemoveInvestorOptions {
    package?: string;
    arguments: RemoveInvestorArguments | [
        investorInfo: RawTransactionArgument<string>,
        auth: RawTransactionArgument<string>,
        investorId: RawTransactionArgument<string>,
        version: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/**
 * Removes an investor from the registry. The investor must have no wallets
 * associated before removal. Only authorized addresses with the RemoveInvestor
 * ability can call this function.
 *
 * # Aborts
 *
 * - `ENotAuthorized` - If the sender does not have the RemoveInvestor ability
 * - `EInvestorNotFound` - If the investor does not exist
 * - `EInvestorHasWallets` - If the investor still has wallets associated
 */
export function removeInvestor(options: RemoveInvestorOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        null,
        '0x1::string::String',
        null
    ] satisfies (string | null)[];
    const parameterNames = ["investorInfo", "auth", "investorId", "version"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'registry_service',
        function: 'remove_investor',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface UpdateInvestorArguments {
    investorInfo: RawTransactionArgument<string>;
    auth: RawTransactionArgument<string>;
    namespace: RawTransactionArgument<string>;
    investorId: RawTransactionArgument<string>;
    country: RawTransactionArgument<string>;
    wallets: RawTransactionArgument<Array<string>>;
    attributeIds: RawTransactionArgument<Array<number | bigint>>;
    attributeValues: RawTransactionArgument<Array<number | bigint>>;
    attributeExpirations: RawTransactionArgument<Array<number | bigint>>;
    version: RawTransactionArgument<string>;
}
export interface UpdateInvestorOptions {
    package?: string;
    arguments: UpdateInvestorArguments | [
        investorInfo: RawTransactionArgument<string>,
        auth: RawTransactionArgument<string>,
        namespace: RawTransactionArgument<string>,
        investorId: RawTransactionArgument<string>,
        country: RawTransactionArgument<string>,
        wallets: RawTransactionArgument<Array<string>>,
        attributeIds: RawTransactionArgument<Array<number | bigint>>,
        attributeValues: RawTransactionArgument<Array<number | bigint>>,
        attributeExpirations: RawTransactionArgument<Array<number | bigint>>,
        version: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/**
 * Updates an investor's information including country, wallets, and attributes. If
 * the investor does not exist, it will be registered first. Only authorized
 * addresses with the UpdateInvestor ability can call this function.
 *
 * # Aborts
 *
 * - `ENotAuthorized` - If the sender does not have the UpdateInvestor ability
 * - `EWrongVectorLength` - If attribute vectors have mismatched lengths
 * - `EWrongInvestor` - If a wallet already belongs to a different investor
 */
export function updateInvestor(options: UpdateInvestorOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        null,
        null,
        '0x1::string::String',
        '0x1::string::String',
        'vector<address>',
        'vector<u64>',
        'vector<u64>',
        'vector<u64>',
        null
    ] satisfies (string | null)[];
    const parameterNames = ["investorInfo", "auth", "namespace", "investorId", "country", "wallets", "attributeIds", "attributeValues", "attributeExpirations", "version"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'registry_service',
        function: 'update_investor',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface AddWalletArguments {
    investorInfo: RawTransactionArgument<string>;
    auth: RawTransactionArgument<string>;
    namespace: RawTransactionArgument<string>;
    investorId: RawTransactionArgument<string>;
    walletAddr: RawTransactionArgument<string>;
    version: RawTransactionArgument<string>;
}
export interface AddWalletOptions {
    package?: string;
    arguments: AddWalletArguments | [
        investorInfo: RawTransactionArgument<string>,
        auth: RawTransactionArgument<string>,
        namespace: RawTransactionArgument<string>,
        investorId: RawTransactionArgument<string>,
        walletAddr: RawTransactionArgument<string>,
        version: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/**
 * Adds a wallet address to an investor's list of wallets. Only authorized
 * addresses with the AddWallet ability can call this function.
 *
 * # Aborts
 *
 * - `ENotAuthorized` - If the sender does not have the AddWallet ability
 * - `ESpecialWallet` - If the wallet is a special wallet (e.g., treasury)
 * - `EInvestorNotFound` - If the investor does not exist
 * - `EWalletAlreadyExists` - If the wallet is already registered
 */
export function addWallet(options: AddWalletOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        null,
        null,
        '0x1::string::String',
        'address',
        null
    ] satisfies (string | null)[];
    const parameterNames = ["investorInfo", "auth", "namespace", "investorId", "walletAddr", "version"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'registry_service',
        function: 'add_wallet',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface RemoveWalletArguments {
    investorInfo: RawTransactionArgument<string>;
    auth: RawTransactionArgument<string>;
    investorId: RawTransactionArgument<string>;
    walletAddr: RawTransactionArgument<string>;
    version: RawTransactionArgument<string>;
}
export interface RemoveWalletOptions {
    package?: string;
    arguments: RemoveWalletArguments | [
        investorInfo: RawTransactionArgument<string>,
        auth: RawTransactionArgument<string>,
        investorId: RawTransactionArgument<string>,
        walletAddr: RawTransactionArgument<string>,
        version: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/**
 * Removes a wallet address from an investor's list of wallets. Only authorized
 * addresses with the RemoveWallet ability can call this function.
 *
 * # Aborts
 *
 * - `ENotAuthorized` - If the sender does not have the RemoveWallet ability
 * - `EWalletNotFound` - If the wallet does not exist
 * - `EWalletDoesNotBelongToInvestor` - If the wallet does not belong to the
 *   specified investor
 */
export function removeWallet(options: RemoveWalletOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        null,
        '0x1::string::String',
        'address',
        null
    ] satisfies (string | null)[];
    const parameterNames = ["investorInfo", "auth", "investorId", "walletAddr", "version"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'registry_service',
        function: 'remove_wallet',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface SetCountryArguments {
    investorInfo: RawTransactionArgument<string>;
    auth: RawTransactionArgument<string>;
    investorId: RawTransactionArgument<string>;
    country: RawTransactionArgument<string>;
    version: RawTransactionArgument<string>;
}
export interface SetCountryOptions {
    package?: string;
    arguments: SetCountryArguments | [
        investorInfo: RawTransactionArgument<string>,
        auth: RawTransactionArgument<string>,
        investorId: RawTransactionArgument<string>,
        country: RawTransactionArgument<string>,
        version: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/**
 * Sets the country for an investor and updates compliance statistics. Only
 * authorized addresses with the SetCountry ability can call this function.
 *
 * # Aborts
 *
 * - `ENotAuthorized` - If the sender does not have the SetCountry ability
 * - `EInvestorNotFound` - If the investor does not exist
 */
export function setCountry(options: SetCountryOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        null,
        '0x1::string::String',
        '0x1::string::String',
        null
    ] satisfies (string | null)[];
    const parameterNames = ["investorInfo", "auth", "investorId", "country", "version"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'registry_service',
        function: 'set_country',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface SetAttributeArguments {
    investorInfo: RawTransactionArgument<string>;
    auth: RawTransactionArgument<string>;
    investorId: RawTransactionArgument<string>;
    attributeId: RawTransactionArgument<number | bigint>;
    attributeValue: RawTransactionArgument<number | bigint>;
    attributeExpiration: RawTransactionArgument<number | bigint>;
    version: RawTransactionArgument<string>;
}
export interface SetAttributeOptions {
    package?: string;
    arguments: SetAttributeArguments | [
        investorInfo: RawTransactionArgument<string>,
        auth: RawTransactionArgument<string>,
        investorId: RawTransactionArgument<string>,
        attributeId: RawTransactionArgument<number | bigint>,
        attributeValue: RawTransactionArgument<number | bigint>,
        attributeExpiration: RawTransactionArgument<number | bigint>,
        version: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/**
 * Sets or updates a compliance attribute for an investor. If the attribute already
 * exists, it will be updated; otherwise, it will be created. Only authorized
 * addresses with the SetAttribute ability can call this function.
 *
 * # Aborts
 *
 * - `ENotAuthorized` - If the sender does not have the SetAttribute ability
 * - `EInvestorNotFound` - If the investor does not exist
 * - `EUnknownAttribute` - If the attribute_id is >= 16
 */
export function setAttribute(options: SetAttributeOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        null,
        '0x1::string::String',
        'u64',
        'u64',
        'u64',
        null
    ] satisfies (string | null)[];
    const parameterNames = ["investorInfo", "auth", "investorId", "attributeId", "attributeValue", "attributeExpiration", "version"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'registry_service',
        function: 'set_attribute',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface IsInvestorArguments {
    investorInfo: RawTransactionArgument<string>;
    investorId: RawTransactionArgument<string>;
}
export interface IsInvestorOptions {
    package?: string;
    arguments: IsInvestorArguments | [
        investorInfo: RawTransactionArgument<string>,
        investorId: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/** Returns whether an investor exists in the registry. */
export function isInvestor(options: IsInvestorOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        '0x1::string::String'
    ] satisfies (string | null)[];
    const parameterNames = ["investorInfo", "investorId"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'registry_service',
        function: 'is_investor',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface GetInvestorIdByWalletArguments {
    investorInfo: RawTransactionArgument<string>;
    wallet: RawTransactionArgument<string>;
}
export interface GetInvestorIdByWalletOptions {
    package?: string;
    arguments: GetInvestorIdByWalletArguments | [
        investorInfo: RawTransactionArgument<string>,
        wallet: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/** Returns whether an investor exists in the registry. */
export function getInvestorIdByWallet(options: GetInvestorIdByWalletOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        'address'
    ] satisfies (string | null)[];
    const parameterNames = ["investorInfo", "wallet"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'registry_service',
        function: 'get_investor_id_by_wallet',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface IsWalletArguments {
    investorInfo: RawTransactionArgument<string>;
    wallet: RawTransactionArgument<string>;
}
export interface IsWalletOptions {
    package?: string;
    arguments: IsWalletArguments | [
        investorInfo: RawTransactionArgument<string>,
        wallet: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/** Returns whether a wallet is registered in the registry. */
export function isWallet(options: IsWalletOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        'address'
    ] satisfies (string | null)[];
    const parameterNames = ["investorInfo", "wallet"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'registry_service',
        function: 'is_wallet',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface IsSpecialWalletArguments {
    investorInfo: RawTransactionArgument<string>;
    wallet: RawTransactionArgument<string>;
}
export interface IsSpecialWalletOptions {
    package?: string;
    arguments: IsSpecialWalletArguments | [
        investorInfo: RawTransactionArgument<string>,
        wallet: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/** Returns whether a wallet is a special wallet (e.g., ISSUER, PLATFORM). */
export function isSpecialWallet(options: IsSpecialWalletOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        'address'
    ] satisfies (string | null)[];
    const parameterNames = ["investorInfo", "wallet"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'registry_service',
        function: 'is_special_wallet',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface GetSpecialWalletTypeArguments {
    investorInfo: RawTransactionArgument<string>;
    wallet: RawTransactionArgument<string>;
}
export interface GetSpecialWalletTypeOptions {
    package?: string;
    arguments: GetSpecialWalletTypeArguments | [
        investorInfo: RawTransactionArgument<string>,
        wallet: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/** Retrieves the wallet type for a special wallet address. */
export function getSpecialWalletType(options: GetSpecialWalletTypeOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        'address'
    ] satisfies (string | null)[];
    const parameterNames = ["investorInfo", "wallet"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'registry_service',
        function: 'get_special_wallet_type',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface InvestorWalletBalanceTotalArguments {
    investorInfo: RawTransactionArgument<string>;
    investorId: RawTransactionArgument<string>;
}
export interface InvestorWalletBalanceTotalOptions {
    package?: string;
    arguments: InvestorWalletBalanceTotalArguments | [
        investorInfo: RawTransactionArgument<string>,
        investorId: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/**
 * Returns the total token balance across all wallets for an investor.
 *
 * # Aborts
 *
 * - `EInvestorNotFound` - If the investor does not exist
 */
export function investorWalletBalanceTotal(options: InvestorWalletBalanceTotalOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        '0x1::string::String'
    ] satisfies (string | null)[];
    const parameterNames = ["investorInfo", "investorId"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'registry_service',
        function: 'investor_wallet_balance_total',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface InvestorWalletBalanceArguments {
    investorInfo: RawTransactionArgument<string>;
    walletAddr: RawTransactionArgument<string>;
}
export interface InvestorWalletBalanceOptions {
    package?: string;
    arguments: InvestorWalletBalanceArguments | [
        investorInfo: RawTransactionArgument<string>,
        walletAddr: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/**
 * Returns the total token balance of an investor's wallet.
 *
 * # Aborts
 *
 * - `EInvestorNotFound` - If the investor does not exist
 */
export function investorWalletBalance(options: InvestorWalletBalanceOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        'address'
    ] satisfies (string | null)[];
    const parameterNames = ["investorInfo", "walletAddr"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'registry_service',
        function: 'investor_wallet_balance',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface IsAccreditedInvestorByIdArguments {
    investorInfo: RawTransactionArgument<string>;
    investorId: RawTransactionArgument<string>;
}
export interface IsAccreditedInvestorByIdOptions {
    package?: string;
    arguments: IsAccreditedInvestorByIdArguments | [
        investorInfo: RawTransactionArgument<string>,
        investorId: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/** Returns whether an investor has accredited status. */
export function isAccreditedInvestorById(options: IsAccreditedInvestorByIdOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        '0x1::string::String'
    ] satisfies (string | null)[];
    const parameterNames = ["investorInfo", "investorId"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'registry_service',
        function: 'is_accredited_investor_by_id',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface IsAccreditedInvestorArguments {
    investorInfo: RawTransactionArgument<string>;
    wallet: RawTransactionArgument<string>;
}
export interface IsAccreditedInvestorOptions {
    package?: string;
    arguments: IsAccreditedInvestorArguments | [
        investorInfo: RawTransactionArgument<string>,
        wallet: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/** Returns whether an investor has accredited status based on their wallet address. */
export function isAccreditedInvestor(options: IsAccreditedInvestorOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        'address'
    ] satisfies (string | null)[];
    const parameterNames = ["investorInfo", "wallet"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'registry_service',
        function: 'is_accredited_investor',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface IsQualifiedInvestorByIdArguments {
    investorInfo: RawTransactionArgument<string>;
    investorId: RawTransactionArgument<string>;
}
export interface IsQualifiedInvestorByIdOptions {
    package?: string;
    arguments: IsQualifiedInvestorByIdArguments | [
        investorInfo: RawTransactionArgument<string>,
        investorId: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/** Returns whether an investor has qualified status. */
export function isQualifiedInvestorById(options: IsQualifiedInvestorByIdOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        '0x1::string::String'
    ] satisfies (string | null)[];
    const parameterNames = ["investorInfo", "investorId"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'registry_service',
        function: 'is_qualified_investor_by_id',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface IsQualifiedInvestorArguments {
    investorInfo: RawTransactionArgument<string>;
    wallet: RawTransactionArgument<string>;
}
export interface IsQualifiedInvestorOptions {
    package?: string;
    arguments: IsQualifiedInvestorArguments | [
        investorInfo: RawTransactionArgument<string>,
        wallet: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/** Returns whether an investor has qualified status based on their wallet address. */
export function isQualifiedInvestor(options: IsQualifiedInvestorOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        'address'
    ] satisfies (string | null)[];
    const parameterNames = ["investorInfo", "wallet"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'registry_service',
        function: 'is_qualified_investor',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface GetCountryComplianceArguments {
    investorInfo: RawTransactionArgument<string>;
    country: RawTransactionArgument<string>;
}
export interface GetCountryComplianceOptions {
    package?: string;
    arguments: GetCountryComplianceArguments | [
        investorInfo: RawTransactionArgument<string>,
        country: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/** Returns the compliance region for a given country code. */
export function getCountryCompliance(options: GetCountryComplianceOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        '0x1::string::String'
    ] satisfies (string | null)[];
    const parameterNames = ["investorInfo", "country"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'registry_service',
        function: 'get_country_compliance',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface GetCountryArguments {
    investorInfo: RawTransactionArgument<string>;
    investorId: RawTransactionArgument<string>;
}
export interface GetCountryOptions {
    package?: string;
    arguments: GetCountryArguments | [
        investorInfo: RawTransactionArgument<string>,
        investorId: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/** Returns the country of the investor. */
export function getCountry(options: GetCountryOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        '0x1::string::String'
    ] satisfies (string | null)[];
    const parameterNames = ["investorInfo", "investorId"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'registry_service',
        function: 'get_country',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface GetAttributeValueArguments {
    investorInfo: RawTransactionArgument<string>;
    investorId: RawTransactionArgument<string>;
    attributeId: RawTransactionArgument<number | bigint>;
}
export interface GetAttributeValueOptions {
    package?: string;
    arguments: GetAttributeValueArguments | [
        investorInfo: RawTransactionArgument<string>,
        investorId: RawTransactionArgument<string>,
        attributeId: RawTransactionArgument<number | bigint>
    ];
    typeArguments: [
        string
    ];
}
/**
 * Returns the value of a specific attribute for an investor. Returns 0 if the
 * attribute does not exist. Aborts if the investor does not exist.
 */
export function getAttributeValue(options: GetAttributeValueOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        '0x1::string::String',
        'u64'
    ] satisfies (string | null)[];
    const parameterNames = ["investorInfo", "investorId", "attributeId"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'registry_service',
        function: 'get_attribute_value',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface GetAttributeExpirationArguments {
    investorInfo: RawTransactionArgument<string>;
    investorId: RawTransactionArgument<string>;
    attributeId: RawTransactionArgument<number | bigint>;
}
export interface GetAttributeExpirationOptions {
    package?: string;
    arguments: GetAttributeExpirationArguments | [
        investorInfo: RawTransactionArgument<string>,
        investorId: RawTransactionArgument<string>,
        attributeId: RawTransactionArgument<number | bigint>
    ];
    typeArguments: [
        string
    ];
}
/**
 * Returns the expiration timestamp of a specific attribute for an investor.
 * Returns 0 if the attribute does not exist. Aborts if the investor does not
 * exist.
 */
export function getAttributeExpiration(options: GetAttributeExpirationOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        '0x1::string::String',
        'u64'
    ] satisfies (string | null)[];
    const parameterNames = ["investorInfo", "investorId", "attributeId"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'registry_service',
        function: 'get_attribute_expiration',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface GetTotalInvestorsCountArguments {
    investorInfo: RawTransactionArgument<string>;
}
export interface GetTotalInvestorsCountOptions {
    package?: string;
    arguments: GetTotalInvestorsCountArguments | [
        investorInfo: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/** Returns the total number of investors. */
export function getTotalInvestorsCount(options: GetTotalInvestorsCountOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["investorInfo"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'registry_service',
        function: 'get_total_investors_count',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface GetAccreditedInvestorCountArguments {
    investorInfo: RawTransactionArgument<string>;
}
export interface GetAccreditedInvestorCountOptions {
    package?: string;
    arguments: GetAccreditedInvestorCountArguments | [
        investorInfo: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/** Returns the total number of accredited investors. */
export function getAccreditedInvestorCount(options: GetAccreditedInvestorCountOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["investorInfo"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'registry_service',
        function: 'get_accredited_investor_count',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface GetUsInvestorCountArguments {
    investorInfo: RawTransactionArgument<string>;
}
export interface GetUsInvestorCountOptions {
    package?: string;
    arguments: GetUsInvestorCountArguments | [
        investorInfo: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/** Returns the total number of US investors. */
export function getUsInvestorCount(options: GetUsInvestorCountOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["investorInfo"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'registry_service',
        function: 'get_us_investor_count',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface GetUsAccreditedInvestorCountArguments {
    investorInfo: RawTransactionArgument<string>;
}
export interface GetUsAccreditedInvestorCountOptions {
    package?: string;
    arguments: GetUsAccreditedInvestorCountArguments | [
        investorInfo: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/** Returns the total number of US accredited investors. */
export function getUsAccreditedInvestorCount(options: GetUsAccreditedInvestorCountOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["investorInfo"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'registry_service',
        function: 'get_us_accredited_investor_count',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface GetJpInvestorCountArguments {
    investorInfo: RawTransactionArgument<string>;
}
export interface GetJpInvestorCountOptions {
    package?: string;
    arguments: GetJpInvestorCountArguments | [
        investorInfo: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/** Returns the total number of JP investors. */
export function getJpInvestorCount(options: GetJpInvestorCountOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["investorInfo"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'registry_service',
        function: 'get_jp_investor_count',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface GetEuRetailInvestorCountArguments {
    investorInfo: RawTransactionArgument<string>;
    toCountry: RawTransactionArgument<string>;
}
export interface GetEuRetailInvestorCountOptions {
    package?: string;
    arguments: GetEuRetailInvestorCountArguments | [
        investorInfo: RawTransactionArgument<string>,
        toCountry: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/** Returns the total number of EU retail investors for a given country. */
export function getEuRetailInvestorCount(options: GetEuRetailInvestorCountOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        '0x1::string::String'
    ] satisfies (string | null)[];
    const parameterNames = ["investorInfo", "toCountry"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'registry_service',
        function: 'get_eu_retail_investor_count',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface NewIssuanceArguments {
    amount: RawTransactionArgument<number | bigint>;
    issuanceTimeMs: RawTransactionArgument<number | bigint>;
}
export interface NewIssuanceOptions {
    package?: string;
    arguments: NewIssuanceArguments | [
        amount: RawTransactionArgument<number | bigint>,
        issuanceTimeMs: RawTransactionArgument<number | bigint>
    ];
}
/** Creates a new Issuance record */
export function newIssuance(options: NewIssuanceOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        'u64',
        'u64'
    ] satisfies (string | null)[];
    const parameterNames = ["amount", "issuanceTimeMs"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'registry_service',
        function: 'new_issuance',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface IssuanceAmountArguments {
    issuance: RawTransactionArgument<string>;
}
export interface IssuanceAmountOptions {
    package?: string;
    arguments: IssuanceAmountArguments | [
        issuance: RawTransactionArgument<string>
    ];
}
/** Get amount from issuance */
export function issuanceAmount(options: IssuanceAmountOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["issuance"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'registry_service',
        function: 'issuance_amount',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface IssuanceTimeMsArguments {
    issuance: RawTransactionArgument<string>;
}
export interface IssuanceTimeMsOptions {
    package?: string;
    arguments: IssuanceTimeMsArguments | [
        issuance: RawTransactionArgument<string>
    ];
}
/** Get issuance time from issuance (in milliseconds) */
export function issuanceTimeMs(options: IssuanceTimeMsOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["issuance"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'registry_service',
        function: 'issuance_time_ms',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface SetTotalInvestorsCountArguments {
    investorInfo: RawTransactionArgument<string>;
    auth: RawTransactionArgument<string>;
    count: RawTransactionArgument<number | bigint>;
    version: RawTransactionArgument<string>;
}
export interface SetTotalInvestorsCountOptions {
    package?: string;
    arguments: SetTotalInvestorsCountArguments | [
        investorInfo: RawTransactionArgument<string>,
        auth: RawTransactionArgument<string>,
        count: RawTransactionArgument<number | bigint>,
        version: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/** Sets the total count of investors. Requires SetInvestorCounts ability. */
export function setTotalInvestorsCount(options: SetTotalInvestorsCountOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        null,
        'u64',
        null
    ] satisfies (string | null)[];
    const parameterNames = ["investorInfo", "auth", "count", "version"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'registry_service',
        function: 'set_total_investors_count',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface SetUsInvestorsCountArguments {
    investorInfo: RawTransactionArgument<string>;
    auth: RawTransactionArgument<string>;
    count: RawTransactionArgument<number | bigint>;
    version: RawTransactionArgument<string>;
}
export interface SetUsInvestorsCountOptions {
    package?: string;
    arguments: SetUsInvestorsCountArguments | [
        investorInfo: RawTransactionArgument<string>,
        auth: RawTransactionArgument<string>,
        count: RawTransactionArgument<number | bigint>,
        version: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/** Sets the count of US investors. Requires SetInvestorCounts ability. */
export function setUsInvestorsCount(options: SetUsInvestorsCountOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        null,
        'u64',
        null
    ] satisfies (string | null)[];
    const parameterNames = ["investorInfo", "auth", "count", "version"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'registry_service',
        function: 'set_us_investors_count',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface SetUsAccreditedInvestorsCountArguments {
    investorInfo: RawTransactionArgument<string>;
    auth: RawTransactionArgument<string>;
    count: RawTransactionArgument<number | bigint>;
    version: RawTransactionArgument<string>;
}
export interface SetUsAccreditedInvestorsCountOptions {
    package?: string;
    arguments: SetUsAccreditedInvestorsCountArguments | [
        investorInfo: RawTransactionArgument<string>,
        auth: RawTransactionArgument<string>,
        count: RawTransactionArgument<number | bigint>,
        version: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/** Sets the count of US accredited investors. Requires SetInvestorCounts ability. */
export function setUsAccreditedInvestorsCount(options: SetUsAccreditedInvestorsCountOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        null,
        'u64',
        null
    ] satisfies (string | null)[];
    const parameterNames = ["investorInfo", "auth", "count", "version"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'registry_service',
        function: 'set_us_accredited_investors_count',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface SetAccreditedInvestorsCountArguments {
    investorInfo: RawTransactionArgument<string>;
    auth: RawTransactionArgument<string>;
    count: RawTransactionArgument<number | bigint>;
    version: RawTransactionArgument<string>;
}
export interface SetAccreditedInvestorsCountOptions {
    package?: string;
    arguments: SetAccreditedInvestorsCountArguments | [
        investorInfo: RawTransactionArgument<string>,
        auth: RawTransactionArgument<string>,
        count: RawTransactionArgument<number | bigint>,
        version: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/** Sets the count of accredited investors. Requires SetInvestorCounts ability. */
export function setAccreditedInvestorsCount(options: SetAccreditedInvestorsCountOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        null,
        'u64',
        null
    ] satisfies (string | null)[];
    const parameterNames = ["investorInfo", "auth", "count", "version"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'registry_service',
        function: 'set_accredited_investors_count',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface SetJpInvestorsCountArguments {
    investorInfo: RawTransactionArgument<string>;
    auth: RawTransactionArgument<string>;
    count: RawTransactionArgument<number | bigint>;
    version: RawTransactionArgument<string>;
}
export interface SetJpInvestorsCountOptions {
    package?: string;
    arguments: SetJpInvestorsCountArguments | [
        investorInfo: RawTransactionArgument<string>,
        auth: RawTransactionArgument<string>,
        count: RawTransactionArgument<number | bigint>,
        version: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/** Sets the count of Japanese investors. Requires SetInvestorCounts ability. */
export function setJpInvestorsCount(options: SetJpInvestorsCountOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        null,
        'u64',
        null
    ] satisfies (string | null)[];
    const parameterNames = ["investorInfo", "auth", "count", "version"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'registry_service',
        function: 'set_jp_investors_count',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface GetInvestorIssuancesArguments {
    investorInfo: RawTransactionArgument<string>;
    investorId: RawTransactionArgument<string>;
}
export interface GetInvestorIssuancesOptions {
    package?: string;
    arguments: GetInvestorIssuancesArguments | [
        investorInfo: RawTransactionArgument<string>,
        investorId: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/** Returns a reference to the investor issuances for a given investor ID. */
export function getInvestorIssuances(options: GetInvestorIssuancesOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        '0x1::string::String'
    ] satisfies (string | null)[];
    const parameterNames = ["investorInfo", "investorId"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'registry_service',
        function: 'get_investor_issuances',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}