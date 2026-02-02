export interface Owners {
  /** Omnibus TBE address (optional) */
  omnibusTBEAddress?: string;
  /** The token owner address */
  tokenOwner: string;
  /** The wallet registrar owner address */
  walletRegistrarOwner: string;
    /** Token role ownership type (optional) */
  walletRegistrarOwnerType?: string;
  /** The redemption address (optional) */
  redemptionAddress?: string;
}
