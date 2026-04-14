/**************************************************************
 * THIS FILE IS GENERATED AND SHOULD NOT BE MANUALLY MODIFIED *
 **************************************************************/


/**
 * Defines the system object for managing coin data in a central registry. This
 * module provides a centralized way to store and manage metadata for all
 * currencies in the Sui ecosystem, including their supply information, regulatory
 * status, and metadata capabilities.
 */

import { MoveStruct } from '../../../utils/index.js';
import { bcs } from '@mysten/sui/bcs';
const $moduleName = '0x2::coin_registry';
export const MetadataCap = new MoveStruct({ name: `${$moduleName}::MetadataCap<phantom T>`, fields: {
        id: bcs.Address
    } });