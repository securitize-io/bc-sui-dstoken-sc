export type RoleTypes = 'none' | 'master' | 'issuer' | 'exchange' | 'transfer_agent';

export interface Role {
  /** The address to assign the role to */
  address: string;
  /** The role to assign */
  role: RoleTypes;
  /** Ownership type (optional) */
  ownership?: string;
}
