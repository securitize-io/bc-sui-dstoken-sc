/**************************************************************
 * THIS FILE IS GENERATED AND SHOULD NOT BE MANUALLY MODIFIED *
 **************************************************************/
import { bcs } from '@mysten/sui/bcs';

import { MoveTuple } from '../utils/index.js';

const $moduleName = '@mysten/pas::keys';
export const RuleKey = new MoveTuple({ name: `${$moduleName}::RuleKey`, fields: [bcs.bool()] });
export const VaultKey = new MoveTuple({ name: `${$moduleName}::VaultKey`, fields: [bcs.Address] });
