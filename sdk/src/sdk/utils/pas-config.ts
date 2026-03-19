import type { PASPackageConfig } from '@mysten/pas';
import { Config } from './config';

export function getPASPackageConfig(): PASPackageConfig {
    return {
        packageId: Config.vars.PAS_PACKAGE_ID,
        namespaceId: Config.vars.PAS_NAMESPACE,
    };
}
