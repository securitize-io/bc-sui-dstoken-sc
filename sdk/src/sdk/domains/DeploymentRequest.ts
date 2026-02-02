import { TokenDescription } from './TokenDescription';
import { Owners } from './Owners';
import { Role } from './Role';
import { Multisig } from './Multisig';
import { ComplianceRules } from './ComplianceRules';
import { CountryComplianceStatus } from './CountryComplianceStatus';
import { SwapContract } from './SwapContract';

export interface DeploymentRequest {
  /** Internal deployment ID (ignored by SDK) */
  deploymentId?: string;
  /** Deployment priority */
  priority?: 'high' | 'medium' | 'low';
  /** Transaction gas price */
  gasPrice?: string;
  /** Token metadata (required) */
  tokenDescription: TokenDescription;
  /** Compliance level (required) */
  complianceType: 'regulated' | 'notRegulated' | 'whitelisted' | 'partitioned' | 'globalWhitelisted';
  /** Lock manager type (required) */
  lockManagerType: 'wallet' | 'investor' | 'partitioned';
  /** Token management addresses */
  owners?: Owners;
  /** Role assignments (required, minimum 1) */
  roles: Role[];
  /** Multi-signature configuration */
  multisig?: Multisig;
  /** Compliance rules configuration */
  complianceRules?: ComplianceRules;
  /** Country compliance mappings */
  countriesComplianceStatuses?: CountryComplianceStatus[];
  /** Swap contract configuration (can be null) */
  swapContract?: SwapContract | null;
  /** Additional metadata (ignored by SDK) */
  additionalData?: Record<string, unknown>;
}
