export interface Multisig {
  /** The owner addresses of the multisig contract */
  owners: string[];
  /** The amount of signers required to execute a multisig contract transaction (minimum 2) */
  requiredConfirmations: number;
}
