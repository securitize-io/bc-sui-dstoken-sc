export interface ComplianceRules {
  forceAccredited?: boolean; // Mapped to AccreditedOnly.force_accredited
  forceAccreditedUS?: boolean; // Mapped to AccreditedOnly.force_us_accredited

  blockFlowbackEndTime?: number; // Mapped to FlowbackRestriction.block_flowback_end_time_ms

  worldWideForceFullTransfer?: boolean; // Mapped to ForceFullTransfer.force_full_transfer_worldwide
  forceFullTransfer?: boolean; // Mapped to ForceFullTransfer.force_full_transfer_us

  minUSTokens?: string; // Mapped to HoldingLimits.region_mins
  minEUTokens?: string; // Mapped to HoldingLimits.region_mins
  minimumHoldingsPerInvestor?: string; // Mapped to HoldingLimits.min_holdings_per_investor
  maximumHoldingsPerInvestor?: string; // Mapped to HoldingLimits.max_holdings_per_investor

  totalInvestorsLimit?: number; // Mapped to InvestorLimits.total_investors_limit
  usInvestorsLimit?: number; // Mapped to InvestorLimits.us_investors_limit
  euRetailInvestorsLimit?: number; // Mapped to InvestorLimits.eu_retail_limit
  jpInvestorsLimit?: number; // Mapped to InvestorLimits.jp_investors_limit
  usAccreditedInvestorsLimit?: number; // Mapped to InvestorLimits.us_accredited_limit
  nonAccreditedInvestorsLimit?: number; // Mapped to InvestorLimits.non_accredited_limit
  maxUSInvestorsPercentage?: number; // Mapped to InvestorLimits.max_us_percentage
  minimumTotalInvestors?: number; // Mapped to InvestorLimits.minimum_total_investors

  nonUSLockPeriod?: number; // Mapped to LockupRestriction.non_us_lock_period_ms
  usLockPeriod?: number; // Mapped to LockupRestriction.us_lock_period_ms
  disallowBackDating?: boolean; // Mapped to BackdatingIssuance.allow_backdating

  authorizedSecurities?: string; // Mapped to AuthorizedSecurities.max_supply
}
