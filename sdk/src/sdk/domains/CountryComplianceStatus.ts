export interface CountryComplianceStatus {
  /** The name of the country */
  countryName: string;
  /** The compliance status for this country */
  complianceStatus: 'none' | 'us' | 'eu' | 'jp' | 'forbidden';
}
