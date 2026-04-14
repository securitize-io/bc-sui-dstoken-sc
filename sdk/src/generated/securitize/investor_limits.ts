/**************************************************************
 * THIS FILE IS GENERATED AND SHOULD NOT BE MANUALLY MODIFIED *
 **************************************************************/


/**
 * Module: investor_limits
 * 
 * Rule that enforces limits on the number of investors by category total,
 * accredited, non-accredited, by region, etc.
 */

import { MoveStruct, normalizeMoveArguments, type RawTransactionArgument } from '../utils/index.js';
import { bcs } from '@mysten/sui/bcs';
import { type Transaction } from '@mysten/sui/transactions';
const $moduleName = '@securitize/securitize::investor_limits';
export const InvestorLimits = new MoveStruct({ name: `${$moduleName}::InvestorLimits`, fields: {
        /** Total investor limit (0 = no limit) */
        total_investors_limit: bcs.u64(),
        /** Minimum total investors required (0 = no minimum) */
        minimum_total_investors: bcs.u64(),
        /** US investor limit (0 = no limit) */
        us_investors_limit: bcs.u64(),
        /** US accredited investor limit (0 = no limit) */
        us_accredited_limit: bcs.u64(),
        /** Non-accredited investor limit (0 = no limit) */
        non_accredited_limit: bcs.u64(),
        /** JP investor limit (0 = no limit) */
        jp_investors_limit: bcs.u64(),
        /** EU retail investor limit (0 = no limit) */
        eu_retail_limit: bcs.u64(),
        /** Maximum US investors as percentage of total (0 = no limit) */
        max_us_percentage: bcs.u64()
    } });
export interface NewArguments {
    auth: RawTransactionArgument<string>;
    totalInvestorsLimit: RawTransactionArgument<number | bigint>;
    minimumTotalInvestors: RawTransactionArgument<number | bigint>;
    usInvestorsLimit: RawTransactionArgument<number | bigint>;
    usAccreditedLimit: RawTransactionArgument<number | bigint>;
    nonAccreditedLimit: RawTransactionArgument<number | bigint>;
    jpInvestorsLimit: RawTransactionArgument<number | bigint>;
    euRetailLimit: RawTransactionArgument<number | bigint>;
    maxUsPercentage: RawTransactionArgument<number | bigint>;
    version: RawTransactionArgument<string>;
}
export interface NewOptions {
    package?: string;
    arguments: NewArguments | [
        auth: RawTransactionArgument<string>,
        totalInvestorsLimit: RawTransactionArgument<number | bigint>,
        minimumTotalInvestors: RawTransactionArgument<number | bigint>,
        usInvestorsLimit: RawTransactionArgument<number | bigint>,
        usAccreditedLimit: RawTransactionArgument<number | bigint>,
        nonAccreditedLimit: RawTransactionArgument<number | bigint>,
        jpInvestorsLimit: RawTransactionArgument<number | bigint>,
        euRetailLimit: RawTransactionArgument<number | bigint>,
        maxUsPercentage: RawTransactionArgument<number | bigint>,
        version: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/**
 * Create a new InvestorLimits rule
 *
 * # Aborts
 *
 * - `ENotAuthorized` - If caller lacks RegisterRule ability
 */
export function _new(options: NewOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        'u64',
        'u64',
        'u64',
        'u64',
        'u64',
        'u64',
        'u64',
        'u64',
        null
    ] satisfies (string | null)[];
    const parameterNames = ["auth", "totalInvestorsLimit", "minimumTotalInvestors", "usInvestorsLimit", "usAccreditedLimit", "nonAccreditedLimit", "jpInvestorsLimit", "euRetailLimit", "maxUsPercentage", "version"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'investor_limits',
        function: 'new',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface SetTotalLimitArguments {
    auth: RawTransactionArgument<string>;
    wrapper: RawTransactionArgument<string>;
    limit: RawTransactionArgument<number | bigint>;
    version: RawTransactionArgument<string>;
}
export interface SetTotalLimitOptions {
    package?: string;
    arguments: SetTotalLimitArguments | [
        auth: RawTransactionArgument<string>,
        wrapper: RawTransactionArgument<string>,
        limit: RawTransactionArgument<number | bigint>,
        version: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/**
 * Set total investor limit
 *
 * # Aborts
 *
 * - `ENotAuthorized` - If caller lacks ManageRules ability
 */
export function setTotalLimit(options: SetTotalLimitOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        null,
        'u64',
        null
    ] satisfies (string | null)[];
    const parameterNames = ["auth", "wrapper", "limit", "version"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'investor_limits',
        function: 'set_total_limit',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface SetMinimumTotalInvestorsArguments {
    auth: RawTransactionArgument<string>;
    wrapper: RawTransactionArgument<string>;
    minimum: RawTransactionArgument<number | bigint>;
    version: RawTransactionArgument<string>;
}
export interface SetMinimumTotalInvestorsOptions {
    package?: string;
    arguments: SetMinimumTotalInvestorsArguments | [
        auth: RawTransactionArgument<string>,
        wrapper: RawTransactionArgument<string>,
        minimum: RawTransactionArgument<number | bigint>,
        version: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/**
 * Set minimum total investors
 *
 * # Aborts
 *
 * - `ENotAuthorized` - If caller lacks ManageRules ability
 */
export function setMinimumTotalInvestors(options: SetMinimumTotalInvestorsOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        null,
        'u64',
        null
    ] satisfies (string | null)[];
    const parameterNames = ["auth", "wrapper", "minimum", "version"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'investor_limits',
        function: 'set_minimum_total_investors',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface SetUsLimitArguments {
    auth: RawTransactionArgument<string>;
    wrapper: RawTransactionArgument<string>;
    limit: RawTransactionArgument<number | bigint>;
    version: RawTransactionArgument<string>;
}
export interface SetUsLimitOptions {
    package?: string;
    arguments: SetUsLimitArguments | [
        auth: RawTransactionArgument<string>,
        wrapper: RawTransactionArgument<string>,
        limit: RawTransactionArgument<number | bigint>,
        version: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/**
 * Set US investor limit
 *
 * # Aborts
 *
 * - `ENotAuthorized` - If caller lacks ManageRules ability
 */
export function setUsLimit(options: SetUsLimitOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        null,
        'u64',
        null
    ] satisfies (string | null)[];
    const parameterNames = ["auth", "wrapper", "limit", "version"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'investor_limits',
        function: 'set_us_limit',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface SetUsAccreditedLimitArguments {
    auth: RawTransactionArgument<string>;
    wrapper: RawTransactionArgument<string>;
    limit: RawTransactionArgument<number | bigint>;
    version: RawTransactionArgument<string>;
}
export interface SetUsAccreditedLimitOptions {
    package?: string;
    arguments: SetUsAccreditedLimitArguments | [
        auth: RawTransactionArgument<string>,
        wrapper: RawTransactionArgument<string>,
        limit: RawTransactionArgument<number | bigint>,
        version: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/**
 * Set US accredited limit
 *
 * # Aborts
 *
 * - `ENotAuthorized` - If caller lacks ManageRules ability
 */
export function setUsAccreditedLimit(options: SetUsAccreditedLimitOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        null,
        'u64',
        null
    ] satisfies (string | null)[];
    const parameterNames = ["auth", "wrapper", "limit", "version"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'investor_limits',
        function: 'set_us_accredited_limit',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface SetNonAccreditedLimitArguments {
    auth: RawTransactionArgument<string>;
    wrapper: RawTransactionArgument<string>;
    limit: RawTransactionArgument<number | bigint>;
    version: RawTransactionArgument<string>;
}
export interface SetNonAccreditedLimitOptions {
    package?: string;
    arguments: SetNonAccreditedLimitArguments | [
        auth: RawTransactionArgument<string>,
        wrapper: RawTransactionArgument<string>,
        limit: RawTransactionArgument<number | bigint>,
        version: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/**
 * Set non-accredited limit
 *
 * # Aborts
 *
 * - `ENotAuthorized` - If caller lacks ManageRules ability
 */
export function setNonAccreditedLimit(options: SetNonAccreditedLimitOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        null,
        'u64',
        null
    ] satisfies (string | null)[];
    const parameterNames = ["auth", "wrapper", "limit", "version"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'investor_limits',
        function: 'set_non_accredited_limit',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface SetJpLimitArguments {
    auth: RawTransactionArgument<string>;
    wrapper: RawTransactionArgument<string>;
    limit: RawTransactionArgument<number | bigint>;
    version: RawTransactionArgument<string>;
}
export interface SetJpLimitOptions {
    package?: string;
    arguments: SetJpLimitArguments | [
        auth: RawTransactionArgument<string>,
        wrapper: RawTransactionArgument<string>,
        limit: RawTransactionArgument<number | bigint>,
        version: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/**
 * Set JP investor limit
 *
 * # Aborts
 *
 * - `ENotAuthorized` - If caller lacks ManageRules ability
 */
export function setJpLimit(options: SetJpLimitOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        null,
        'u64',
        null
    ] satisfies (string | null)[];
    const parameterNames = ["auth", "wrapper", "limit", "version"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'investor_limits',
        function: 'set_jp_limit',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface SetEuRetailLimitArguments {
    auth: RawTransactionArgument<string>;
    wrapper: RawTransactionArgument<string>;
    limit: RawTransactionArgument<number | bigint>;
    version: RawTransactionArgument<string>;
}
export interface SetEuRetailLimitOptions {
    package?: string;
    arguments: SetEuRetailLimitArguments | [
        auth: RawTransactionArgument<string>,
        wrapper: RawTransactionArgument<string>,
        limit: RawTransactionArgument<number | bigint>,
        version: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/**
 * Set EU retail limit
 *
 * # Aborts
 *
 * - `ENotAuthorized` - If caller lacks ManageRules ability
 */
export function setEuRetailLimit(options: SetEuRetailLimitOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        null,
        'u64',
        null
    ] satisfies (string | null)[];
    const parameterNames = ["auth", "wrapper", "limit", "version"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'investor_limits',
        function: 'set_eu_retail_limit',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface SetMaxUsPercentageArguments {
    auth: RawTransactionArgument<string>;
    wrapper: RawTransactionArgument<string>;
    percentage: RawTransactionArgument<number | bigint>;
    version: RawTransactionArgument<string>;
}
export interface SetMaxUsPercentageOptions {
    package?: string;
    arguments: SetMaxUsPercentageArguments | [
        auth: RawTransactionArgument<string>,
        wrapper: RawTransactionArgument<string>,
        percentage: RawTransactionArgument<number | bigint>,
        version: RawTransactionArgument<string>
    ];
    typeArguments: [
        string
    ];
}
/**
 * Set max US percentage
 *
 * # Aborts
 *
 * - `ENotAuthorized` - If caller lacks ManageRules ability
 */
export function setMaxUsPercentage(options: SetMaxUsPercentageOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        null,
        'u64',
        null
    ] satisfies (string | null)[];
    const parameterNames = ["auth", "wrapper", "percentage", "version"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'investor_limits',
        function: 'set_max_us_percentage',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface ValidateInvestorLimitsForTransferArguments {
    limitsRule: RawTransactionArgument<string>;
    registry: RawTransactionArgument<string>;
    fromIsAccredited: RawTransactionArgument<boolean>;
    fromIsExitInvestor: RawTransactionArgument<boolean>;
    fromIsQualified: RawTransactionArgument<boolean>;
    toRegion: RawTransactionArgument<number | bigint>;
    toCountry: RawTransactionArgument<string>;
    toIsAccredited: RawTransactionArgument<boolean>;
    toIsQualified: RawTransactionArgument<boolean>;
    toIsNewInvestor: RawTransactionArgument<boolean>;
    equalRegion: RawTransactionArgument<boolean>;
    equalCountry: RawTransactionArgument<boolean>;
}
export interface ValidateInvestorLimitsForTransferOptions {
    package?: string;
    arguments: ValidateInvestorLimitsForTransferArguments | [
        limitsRule: RawTransactionArgument<string>,
        registry: RawTransactionArgument<string>,
        fromIsAccredited: RawTransactionArgument<boolean>,
        fromIsExitInvestor: RawTransactionArgument<boolean>,
        fromIsQualified: RawTransactionArgument<boolean>,
        toRegion: RawTransactionArgument<number | bigint>,
        toCountry: RawTransactionArgument<string>,
        toIsAccredited: RawTransactionArgument<boolean>,
        toIsQualified: RawTransactionArgument<boolean>,
        toIsNewInvestor: RawTransactionArgument<boolean>,
        equalRegion: RawTransactionArgument<boolean>,
        equalCountry: RawTransactionArgument<boolean>
    ];
    typeArguments: [
        string
    ];
}
/** Validate investor limits for transfer */
export function validateInvestorLimitsForTransfer(options: ValidateInvestorLimitsForTransferOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        null,
        'bool',
        'bool',
        'bool',
        'u64',
        '0x1::string::String',
        'bool',
        'bool',
        'bool',
        'bool',
        'bool'
    ] satisfies (string | null)[];
    const parameterNames = ["limitsRule", "registry", "fromIsAccredited", "fromIsExitInvestor", "fromIsQualified", "toRegion", "toCountry", "toIsAccredited", "toIsQualified", "toIsNewInvestor", "equalRegion", "equalCountry"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'investor_limits',
        function: 'validate_investor_limits_for_transfer',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface ValidateInvestorLimitsForIssuanceArguments {
    limitsRule: RawTransactionArgument<string>;
    registry: RawTransactionArgument<string>;
    toRegion: RawTransactionArgument<number | bigint>;
    toCountry: RawTransactionArgument<string>;
    toIsAccredited: RawTransactionArgument<boolean>;
    toIsQualified: RawTransactionArgument<boolean>;
    toIsNewInvestor: RawTransactionArgument<boolean>;
}
export interface ValidateInvestorLimitsForIssuanceOptions {
    package?: string;
    arguments: ValidateInvestorLimitsForIssuanceArguments | [
        limitsRule: RawTransactionArgument<string>,
        registry: RawTransactionArgument<string>,
        toRegion: RawTransactionArgument<number | bigint>,
        toCountry: RawTransactionArgument<string>,
        toIsAccredited: RawTransactionArgument<boolean>,
        toIsQualified: RawTransactionArgument<boolean>,
        toIsNewInvestor: RawTransactionArgument<boolean>
    ];
    typeArguments: [
        string
    ];
}
/** Validate investor limits for issuance */
export function validateInvestorLimitsForIssuance(options: ValidateInvestorLimitsForIssuanceOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        null,
        'u64',
        '0x1::string::String',
        'bool',
        'bool',
        'bool'
    ] satisfies (string | null)[];
    const parameterNames = ["limitsRule", "registry", "toRegion", "toCountry", "toIsAccredited", "toIsQualified", "toIsNewInvestor"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'investor_limits',
        function: 'validate_investor_limits_for_issuance',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface ValidateUsInvestorLimitsArguments {
    limitsRule: RawTransactionArgument<string>;
    registry: RawTransactionArgument<string>;
    fromIsExitInvestor: RawTransactionArgument<boolean>;
    fromIsAccredited: RawTransactionArgument<boolean>;
    toIsNewInvestor: RawTransactionArgument<boolean>;
    toIsAccredited: RawTransactionArgument<boolean>;
    equalRegion: RawTransactionArgument<boolean>;
}
export interface ValidateUsInvestorLimitsOptions {
    package?: string;
    arguments: ValidateUsInvestorLimitsArguments | [
        limitsRule: RawTransactionArgument<string>,
        registry: RawTransactionArgument<string>,
        fromIsExitInvestor: RawTransactionArgument<boolean>,
        fromIsAccredited: RawTransactionArgument<boolean>,
        toIsNewInvestor: RawTransactionArgument<boolean>,
        toIsAccredited: RawTransactionArgument<boolean>,
        equalRegion: RawTransactionArgument<boolean>
    ];
    typeArguments: [
        string
    ];
}
/** Validate US investor limits */
export function validateUsInvestorLimits(options: ValidateUsInvestorLimitsOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        null,
        'bool',
        'bool',
        'bool',
        'bool',
        'bool'
    ] satisfies (string | null)[];
    const parameterNames = ["limitsRule", "registry", "fromIsExitInvestor", "fromIsAccredited", "toIsNewInvestor", "toIsAccredited", "equalRegion"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'investor_limits',
        function: 'validate_us_investor_limits',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
        typeArguments: options.typeArguments
    });
}
export interface ValidateTransferTotalInvestorsArguments {
    rule: RawTransactionArgument<string>;
    currentCount: RawTransactionArgument<number | bigint>;
    fromIsExitInvestor: RawTransactionArgument<boolean>;
    toIsNewInvestor: RawTransactionArgument<boolean>;
}
export interface ValidateTransferTotalInvestorsOptions {
    package?: string;
    arguments: ValidateTransferTotalInvestorsArguments | [
        rule: RawTransactionArgument<string>,
        currentCount: RawTransactionArgument<number | bigint>,
        fromIsExitInvestor: RawTransactionArgument<boolean>,
        toIsNewInvestor: RawTransactionArgument<boolean>
    ];
}
/**
 * Validate total investor count.
 *
 * # Aborts
 *
 * - `EMaxInvestorsExceeded` - If adding new investor would exceed total limit
 */
export function validateTransferTotalInvestors(options: ValidateTransferTotalInvestorsOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        'u64',
        'bool',
        'bool'
    ] satisfies (string | null)[];
    const parameterNames = ["rule", "currentCount", "fromIsExitInvestor", "toIsNewInvestor"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'investor_limits',
        function: 'validate_transfer_total_investors',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface ValidateIssuanceTotalInvestorsArguments {
    rule: RawTransactionArgument<string>;
    currentCount: RawTransactionArgument<number | bigint>;
    toIsNewInvestor: RawTransactionArgument<boolean>;
}
export interface ValidateIssuanceTotalInvestorsOptions {
    package?: string;
    arguments: ValidateIssuanceTotalInvestorsArguments | [
        rule: RawTransactionArgument<string>,
        currentCount: RawTransactionArgument<number | bigint>,
        toIsNewInvestor: RawTransactionArgument<boolean>
    ];
}
/**
 * Validate total investor count.
 *
 * # Aborts
 *
 * - `EMaxInvestorsExceeded` - If adding new investor would exceed total limit
 */
export function validateIssuanceTotalInvestors(options: ValidateIssuanceTotalInvestorsOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        'u64',
        'bool'
    ] satisfies (string | null)[];
    const parameterNames = ["rule", "currentCount", "toIsNewInvestor"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'investor_limits',
        function: 'validate_issuance_total_investors',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface ValidateTransferUsInvestorsArguments {
    rule: RawTransactionArgument<string>;
    currentUsCount: RawTransactionArgument<number | bigint>;
    totalCount: RawTransactionArgument<number | bigint>;
    fromIsExitInvestor: RawTransactionArgument<boolean>;
    toIsNewUsInvestor: RawTransactionArgument<boolean>;
    equalRegion: RawTransactionArgument<boolean>;
}
export interface ValidateTransferUsInvestorsOptions {
    package?: string;
    arguments: ValidateTransferUsInvestorsArguments | [
        rule: RawTransactionArgument<string>,
        currentUsCount: RawTransactionArgument<number | bigint>,
        totalCount: RawTransactionArgument<number | bigint>,
        fromIsExitInvestor: RawTransactionArgument<boolean>,
        toIsNewUsInvestor: RawTransactionArgument<boolean>,
        equalRegion: RawTransactionArgument<boolean>
    ];
}
/**
 * Validate US investor count.
 *
 * # Aborts
 *
 * - `EMaxUSInvestorsExceeded` - If adding new US investor would exceed US limit
 */
export function validateTransferUsInvestors(options: ValidateTransferUsInvestorsOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        'u64',
        'u64',
        'bool',
        'bool',
        'bool'
    ] satisfies (string | null)[];
    const parameterNames = ["rule", "currentUsCount", "totalCount", "fromIsExitInvestor", "toIsNewUsInvestor", "equalRegion"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'investor_limits',
        function: 'validate_transfer_us_investors',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface ValidateIssuanceUsInvestorsArguments {
    rule: RawTransactionArgument<string>;
    currentUsCount: RawTransactionArgument<number | bigint>;
    totalCount: RawTransactionArgument<number | bigint>;
    isNewUsInvestor: RawTransactionArgument<boolean>;
}
export interface ValidateIssuanceUsInvestorsOptions {
    package?: string;
    arguments: ValidateIssuanceUsInvestorsArguments | [
        rule: RawTransactionArgument<string>,
        currentUsCount: RawTransactionArgument<number | bigint>,
        totalCount: RawTransactionArgument<number | bigint>,
        isNewUsInvestor: RawTransactionArgument<boolean>
    ];
}
/**
 * Validate US investor count.
 *
 * # Aborts
 *
 * - `EMaxUSInvestorsExceeded` - If adding new US investor would exceed US limit
 */
export function validateIssuanceUsInvestors(options: ValidateIssuanceUsInvestorsOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        'u64',
        'u64',
        'bool'
    ] satisfies (string | null)[];
    const parameterNames = ["rule", "currentUsCount", "totalCount", "isNewUsInvestor"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'investor_limits',
        function: 'validate_issuance_us_investors',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface ValidateTransferUsAccreditedArguments {
    rule: RawTransactionArgument<string>;
    currentCount: RawTransactionArgument<number | bigint>;
    toIsNewInvestor: RawTransactionArgument<boolean>;
    fromIsExitInvestor: RawTransactionArgument<boolean>;
    fromIsAccredited: RawTransactionArgument<boolean>;
    equalRegion: RawTransactionArgument<boolean>;
}
export interface ValidateTransferUsAccreditedOptions {
    package?: string;
    arguments: ValidateTransferUsAccreditedArguments | [
        rule: RawTransactionArgument<string>,
        currentCount: RawTransactionArgument<number | bigint>,
        toIsNewInvestor: RawTransactionArgument<boolean>,
        fromIsExitInvestor: RawTransactionArgument<boolean>,
        fromIsAccredited: RawTransactionArgument<boolean>,
        equalRegion: RawTransactionArgument<boolean>
    ];
}
/**
 * Validate US accredited investor count.
 *
 * # Aborts
 *
 * - `EMaxUSAccreditedExceeded` - If adding new US accredited investor would exceed
 *   limit
 */
export function validateTransferUsAccredited(options: ValidateTransferUsAccreditedOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        'u64',
        'bool',
        'bool',
        'bool',
        'bool'
    ] satisfies (string | null)[];
    const parameterNames = ["rule", "currentCount", "toIsNewInvestor", "fromIsExitInvestor", "fromIsAccredited", "equalRegion"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'investor_limits',
        function: 'validate_transfer_us_accredited',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface ValidateIssuanceUsAccreditedArguments {
    rule: RawTransactionArgument<string>;
    currentCount: RawTransactionArgument<number | bigint>;
    toIsNewInvestor: RawTransactionArgument<boolean>;
}
export interface ValidateIssuanceUsAccreditedOptions {
    package?: string;
    arguments: ValidateIssuanceUsAccreditedArguments | [
        rule: RawTransactionArgument<string>,
        currentCount: RawTransactionArgument<number | bigint>,
        toIsNewInvestor: RawTransactionArgument<boolean>
    ];
}
/**
 * Validate US accredited investor count.
 *
 * # Aborts
 *
 * - `EMaxUSAccreditedExceeded` - If adding new US accredited investor would exceed
 *   limit
 */
export function validateIssuanceUsAccredited(options: ValidateIssuanceUsAccreditedOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        'u64',
        'bool'
    ] satisfies (string | null)[];
    const parameterNames = ["rule", "currentCount", "toIsNewInvestor"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'investor_limits',
        function: 'validate_issuance_us_accredited',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface ValidateTransferNonAccreditedArguments {
    rule: RawTransactionArgument<string>;
    currentNonAccredited: RawTransactionArgument<number | bigint>;
    toIsNewInvestor: RawTransactionArgument<boolean>;
    fromIsExitInvestor: RawTransactionArgument<boolean>;
    fromIsAccredited: RawTransactionArgument<boolean>;
}
export interface ValidateTransferNonAccreditedOptions {
    package?: string;
    arguments: ValidateTransferNonAccreditedArguments | [
        rule: RawTransactionArgument<string>,
        currentNonAccredited: RawTransactionArgument<number | bigint>,
        toIsNewInvestor: RawTransactionArgument<boolean>,
        fromIsExitInvestor: RawTransactionArgument<boolean>,
        fromIsAccredited: RawTransactionArgument<boolean>
    ];
}
/**
 * Validate non-accredited investor count.
 *
 * # Aborts
 *
 * - `EMaxNonAccreditedExceeded` - If adding new non-accredited investor would
 *   exceed limit
 */
export function validateTransferNonAccredited(options: ValidateTransferNonAccreditedOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        'u64',
        'bool',
        'bool',
        'bool'
    ] satisfies (string | null)[];
    const parameterNames = ["rule", "currentNonAccredited", "toIsNewInvestor", "fromIsExitInvestor", "fromIsAccredited"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'investor_limits',
        function: 'validate_transfer_non_accredited',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface ValidateIssuanceNonAccreditedArguments {
    rule: RawTransactionArgument<string>;
    currentCount: RawTransactionArgument<number | bigint>;
    toIsNewInvestor: RawTransactionArgument<boolean>;
}
export interface ValidateIssuanceNonAccreditedOptions {
    package?: string;
    arguments: ValidateIssuanceNonAccreditedArguments | [
        rule: RawTransactionArgument<string>,
        currentCount: RawTransactionArgument<number | bigint>,
        toIsNewInvestor: RawTransactionArgument<boolean>
    ];
}
/**
 * Validate non-accredited investor count.
 *
 * # Aborts
 *
 * - `EMaxNonAccreditedExceeded` - If adding new non-accredited investor would
 *   exceed limit
 */
export function validateIssuanceNonAccredited(options: ValidateIssuanceNonAccreditedOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        'u64',
        'bool'
    ] satisfies (string | null)[];
    const parameterNames = ["rule", "currentCount", "toIsNewInvestor"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'investor_limits',
        function: 'validate_issuance_non_accredited',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface ValidateTransferEuRetailArguments {
    rule: RawTransactionArgument<string>;
    currentCount: RawTransactionArgument<number | bigint>;
    fromIsExitInvestor: RawTransactionArgument<boolean>;
    fromIsQualified: RawTransactionArgument<boolean>;
    toIsNewEuRetailInvestor: RawTransactionArgument<boolean>;
    equalCountry: RawTransactionArgument<boolean>;
}
export interface ValidateTransferEuRetailOptions {
    package?: string;
    arguments: ValidateTransferEuRetailArguments | [
        rule: RawTransactionArgument<string>,
        currentCount: RawTransactionArgument<number | bigint>,
        fromIsExitInvestor: RawTransactionArgument<boolean>,
        fromIsQualified: RawTransactionArgument<boolean>,
        toIsNewEuRetailInvestor: RawTransactionArgument<boolean>,
        equalCountry: RawTransactionArgument<boolean>
    ];
}
/**
 * Validate EU retail investor count.
 *
 * # Aborts
 *
 * - `EMaxEURetailExceeded` - If adding new EU retail investor would exceed limit
 */
export function validateTransferEuRetail(options: ValidateTransferEuRetailOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        'u64',
        'bool',
        'bool',
        'bool',
        'bool'
    ] satisfies (string | null)[];
    const parameterNames = ["rule", "currentCount", "fromIsExitInvestor", "fromIsQualified", "toIsNewEuRetailInvestor", "equalCountry"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'investor_limits',
        function: 'validate_transfer_eu_retail',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface ValidateIssuanceEuRetailArguments {
    rule: RawTransactionArgument<string>;
    currentCount: RawTransactionArgument<number | bigint>;
    toIsNewEuRetailInvestor: RawTransactionArgument<boolean>;
}
export interface ValidateIssuanceEuRetailOptions {
    package?: string;
    arguments: ValidateIssuanceEuRetailArguments | [
        rule: RawTransactionArgument<string>,
        currentCount: RawTransactionArgument<number | bigint>,
        toIsNewEuRetailInvestor: RawTransactionArgument<boolean>
    ];
}
/**
 * Validate EU retail investor count.
 *
 * # Aborts
 *
 * - `EMaxEURetailExceeded` - If adding new EU retail investor would exceed limit
 */
export function validateIssuanceEuRetail(options: ValidateIssuanceEuRetailOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        'u64',
        'bool'
    ] satisfies (string | null)[];
    const parameterNames = ["rule", "currentCount", "toIsNewEuRetailInvestor"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'investor_limits',
        function: 'validate_issuance_eu_retail',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface ValidateTransferJpInvestorsArguments {
    rule: RawTransactionArgument<string>;
    currentCount: RawTransactionArgument<number | bigint>;
    fromIsExitInvestor: RawTransactionArgument<boolean>;
    toIsNewJpInvestor: RawTransactionArgument<boolean>;
    equalRegion: RawTransactionArgument<boolean>;
}
export interface ValidateTransferJpInvestorsOptions {
    package?: string;
    arguments: ValidateTransferJpInvestorsArguments | [
        rule: RawTransactionArgument<string>,
        currentCount: RawTransactionArgument<number | bigint>,
        fromIsExitInvestor: RawTransactionArgument<boolean>,
        toIsNewJpInvestor: RawTransactionArgument<boolean>,
        equalRegion: RawTransactionArgument<boolean>
    ];
}
/**
 * Validate JP investor count.
 *
 * # Aborts
 *
 * - `EMaxJPInvestorsExceeded` - If adding new JP investor would exceed limit
 */
export function validateTransferJpInvestors(options: ValidateTransferJpInvestorsOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        'u64',
        'bool',
        'bool',
        'bool'
    ] satisfies (string | null)[];
    const parameterNames = ["rule", "currentCount", "fromIsExitInvestor", "toIsNewJpInvestor", "equalRegion"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'investor_limits',
        function: 'validate_transfer_jp_investors',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface ValidateIssuanceJpInvestorsArguments {
    rule: RawTransactionArgument<string>;
    currentCount: RawTransactionArgument<number | bigint>;
    toIsNewJpInvestor: RawTransactionArgument<boolean>;
}
export interface ValidateIssuanceJpInvestorsOptions {
    package?: string;
    arguments: ValidateIssuanceJpInvestorsArguments | [
        rule: RawTransactionArgument<string>,
        currentCount: RawTransactionArgument<number | bigint>,
        toIsNewJpInvestor: RawTransactionArgument<boolean>
    ];
}
/**
 * Validate JP investor count.
 *
 * # Aborts
 *
 * - `EMaxJPInvestorsExceeded` - If adding new JP investor would exceed limit
 */
export function validateIssuanceJpInvestors(options: ValidateIssuanceJpInvestorsOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        'u64',
        'bool'
    ] satisfies (string | null)[];
    const parameterNames = ["rule", "currentCount", "toIsNewJpInvestor"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'investor_limits',
        function: 'validate_issuance_jp_investors',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface ValidateTransferMinimumTotalInvestorsArguments {
    rule: RawTransactionArgument<string>;
    currentCount: RawTransactionArgument<number | bigint>;
    fromIsExitInvestor: RawTransactionArgument<boolean>;
    toIsNewInvestor: RawTransactionArgument<boolean>;
}
export interface ValidateTransferMinimumTotalInvestorsOptions {
    package?: string;
    arguments: ValidateTransferMinimumTotalInvestorsArguments | [
        rule: RawTransactionArgument<string>,
        currentCount: RawTransactionArgument<number | bigint>,
        fromIsExitInvestor: RawTransactionArgument<boolean>,
        toIsNewInvestor: RawTransactionArgument<boolean>
    ];
}
/**
 * Validate minimum total investors requirement. Used to prevent transfers that
 * would reduce total investors below minimum.
 *
 * # Aborts
 *
 * - `EBelowMinimumInvestors` - If transfer would reduce count below minimum
 */
export function validateTransferMinimumTotalInvestors(options: ValidateTransferMinimumTotalInvestorsOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null,
        'u64',
        'bool',
        'bool'
    ] satisfies (string | null)[];
    const parameterNames = ["rule", "currentCount", "fromIsExitInvestor", "toIsNewInvestor"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'investor_limits',
        function: 'validate_transfer_minimum_total_investors',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface EffectiveUsLimitArguments {
    absoluteLimit: RawTransactionArgument<number | bigint>;
    maxPercentage: RawTransactionArgument<number | bigint>;
    total: RawTransactionArgument<number | bigint>;
}
export interface EffectiveUsLimitOptions {
    package?: string;
    arguments: EffectiveUsLimitArguments | [
        absoluteLimit: RawTransactionArgument<number | bigint>,
        maxPercentage: RawTransactionArgument<number | bigint>,
        total: RawTransactionArgument<number | bigint>
    ];
}
/**
 * Returns the effective US investor limit.
 *
 * - If both absolute and percentage limits are set, returns their minimum.
 * - If only one is set, returns that one.
 * - If both are zero, returns 0 (unlimited). Percentage limit uses floor(total \*
 *   percentage / 100)
 */
export function effectiveUsLimit(options: EffectiveUsLimitOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        'u64',
        'u64',
        'u64'
    ] satisfies (string | null)[];
    const parameterNames = ["absoluteLimit", "maxPercentage", "total"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'investor_limits',
        function: 'effective_us_limit',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface TotalLimitArguments {
    rule: RawTransactionArgument<string>;
}
export interface TotalLimitOptions {
    package?: string;
    arguments: TotalLimitArguments | [
        rule: RawTransactionArgument<string>
    ];
}
export function totalLimit(options: TotalLimitOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["rule"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'investor_limits',
        function: 'total_limit',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface MinimumTotalInvestorsArguments {
    rule: RawTransactionArgument<string>;
}
export interface MinimumTotalInvestorsOptions {
    package?: string;
    arguments: MinimumTotalInvestorsArguments | [
        rule: RawTransactionArgument<string>
    ];
}
export function minimumTotalInvestors(options: MinimumTotalInvestorsOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["rule"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'investor_limits',
        function: 'minimum_total_investors',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface UsLimitArguments {
    rule: RawTransactionArgument<string>;
}
export interface UsLimitOptions {
    package?: string;
    arguments: UsLimitArguments | [
        rule: RawTransactionArgument<string>
    ];
}
export function usLimit(options: UsLimitOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["rule"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'investor_limits',
        function: 'us_limit',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface UsAccreditedLimitArguments {
    rule: RawTransactionArgument<string>;
}
export interface UsAccreditedLimitOptions {
    package?: string;
    arguments: UsAccreditedLimitArguments | [
        rule: RawTransactionArgument<string>
    ];
}
export function usAccreditedLimit(options: UsAccreditedLimitOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["rule"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'investor_limits',
        function: 'us_accredited_limit',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface NonAccreditedLimitArguments {
    rule: RawTransactionArgument<string>;
}
export interface NonAccreditedLimitOptions {
    package?: string;
    arguments: NonAccreditedLimitArguments | [
        rule: RawTransactionArgument<string>
    ];
}
export function nonAccreditedLimit(options: NonAccreditedLimitOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["rule"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'investor_limits',
        function: 'non_accredited_limit',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface JpLimitArguments {
    rule: RawTransactionArgument<string>;
}
export interface JpLimitOptions {
    package?: string;
    arguments: JpLimitArguments | [
        rule: RawTransactionArgument<string>
    ];
}
export function jpLimit(options: JpLimitOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["rule"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'investor_limits',
        function: 'jp_limit',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface EuRetailLimitArguments {
    rule: RawTransactionArgument<string>;
}
export interface EuRetailLimitOptions {
    package?: string;
    arguments: EuRetailLimitArguments | [
        rule: RawTransactionArgument<string>
    ];
}
export function euRetailLimit(options: EuRetailLimitOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["rule"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'investor_limits',
        function: 'eu_retail_limit',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}
export interface MaxUsPercentageArguments {
    rule: RawTransactionArgument<string>;
}
export interface MaxUsPercentageOptions {
    package?: string;
    arguments: MaxUsPercentageArguments | [
        rule: RawTransactionArgument<string>
    ];
}
export function maxUsPercentage(options: MaxUsPercentageOptions) {
    const packageAddress = options.package ?? '@securitize/securitize';
    const argumentsTypes = [
        null
    ] satisfies (string | null)[];
    const parameterNames = ["rule"];
    return (tx: Transaction) => tx.moveCall({
        package: packageAddress,
        module: 'investor_limits',
        function: 'max_us_percentage',
        arguments: normalizeMoveArguments(options.arguments, argumentsTypes, parameterNames),
    });
}