export interface TokenDescription {
  /** The name of the token */
  name: string;
  /** The symbol of the token */
  symbol: string;
  /** The number of decimals in the token (max 255) */
  decimals: number;
  /** The type of token */
  type: 'standard' | 'partitioned';
  /** The token multiplier (e.g., "1500000000000000000") - must be at least 19 characters */
  tokenMultiplier: string;
}
