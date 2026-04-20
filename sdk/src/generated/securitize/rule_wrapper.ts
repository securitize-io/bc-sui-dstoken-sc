/**************************************************************
 * THIS FILE IS GENERATED AND SHOULD NOT BE MANUALLY MODIFIED *
 **************************************************************/


/**
 * Module: rule_wrapper
 * 
 * Generic hot potato wrappers for compliance rule flows.
 */

import { type BcsType } from '@mysten/sui/bcs';
import { MoveStruct } from '../utils/index.js';
const $moduleName = '@securitize/securitize::rule_wrapper';
/**
 * Hot potato wrapper used during _rule creation_. Must be resolved (unwrapped) in
 * the same transaction.
 */
export function RuleInitWrapper<R extends BcsType<any>>(...typeParameters: [
    R
]) {
    return new MoveStruct({ name: `${$moduleName}::RuleInitWrapper<phantom T, ${typeParameters[0].name as R['name']}>`, fields: {
            rule: typeParameters[0]
        } });
}
/**
 * Hot potato wrapper used during _rule updates_. Must be resolved (unwrapped) in
 * the same transaction.
 */
export function RuleUpdateWrapper<R extends BcsType<any>>(...typeParameters: [
    R
]) {
    return new MoveStruct({ name: `${$moduleName}::RuleUpdateWrapper<phantom T, ${typeParameters[0].name as R['name']}>`, fields: {
            rule: typeParameters[0]
        } });
}