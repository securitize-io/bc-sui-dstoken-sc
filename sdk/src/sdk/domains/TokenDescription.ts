export interface TokenDescription {
  /** The name of the token */
  name: string;
  /** The symbol of the token */
  symbol: string;
  /** The number of decimals in the token (max 255) */
  decimals: number;
  /** The type of token */
  type: 'standard' | 'partitioned';
  /** The token multiplier */
  tokenMultiplier: string;
  /** The icon of the token */
  iconUri: string;
  /** The token description */
  description: string;
}
