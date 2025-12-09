export interface Role {
  /** The address to assign the role to */
  address: string;
  /** The role to assign */
  role: 'none' | 'master' | 'issuer' | 'exchange' | 'transfer_agent';
}
