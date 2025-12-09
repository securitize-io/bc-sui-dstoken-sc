export interface ComplianceRules {
  /** Total limit of investors */
  totalInvestorsLimit?: number;
  /** Minimum tokens for US investors */
  minUSTokens?: string;
  /** Minimum tokens for EU investors */
  minEUTokens?: string;
  /** Limit of US investors */
  usInvestorsLimit?: number;
  /** Limit of EU retail investors */
  euRetailInvestorsLimit?: number;
  /** Limit of JP investors */
  jpInvestorsLimit?: number;
  /** Limit of US accredited investors */
  usAccreditedInvestorsLimit?: number;
  /** Limit of non-accredited investors */
  nonAccreditedInvestorsLimit?: number;
  /** Maximum percentage of US investors */
  maxUSInvestorsPercentage?: number;
  /** Block flowback end time (timestamp) */
  blockFlowbackEndTime?: number;
  /** Non-US lock period (in seconds) */
  nonUSLockPeriod?: number;
  /** Minimum total number of investors */
  minimumTotalInvestors?: number;
  /** Minimum holdings per investor */
  minimumHoldingsPerInvestor?: string;
  /** Maximum holdings per investor */
  maximumHoldingsPerInvestor?: string;
  /** US lock period (in seconds) */
  usLockPeriod?: number;
  /** Authorized securities */
  authorizedSecurities?: string;
  /** Force full transfer flag */
  forceFullTransfer?: boolean;
  /** Force accredited flag */
  forceAccredited?: boolean;
  /** Force accredited for US investors flag */
  forceAccreditedUS?: boolean;
  /** Worldwide force full transfer flag */
  worldWideForceFullTransfer?: boolean;
  /** Disallow back dating flag */
  disallowBackDating?: boolean;
}
