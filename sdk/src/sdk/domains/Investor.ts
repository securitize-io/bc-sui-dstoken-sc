import {Attribute} from "./Attributes";

export interface InvestorLock {
  value: string;
  releaseTime: number;
  reason: string;
  reasonCode: number;
}

export interface Investor {
  id: string;
  country: string;
  attributes?: Attribute[];
  wallet: string;
  value: string;
  reason: string;
  issuanceTime: number;
  lock?: InvestorLock;
}