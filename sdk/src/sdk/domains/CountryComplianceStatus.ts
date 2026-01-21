export type ComplianceStatus = 'none' | 'us' | 'eu' | 'jp' | 'forbidden'

export interface CountryComplianceStatus {
  /** The name of the country */
  countryName: string;
  /** The compliance status for this country */
  complianceStatus: ComplianceStatus;
  comment?: string;
}
