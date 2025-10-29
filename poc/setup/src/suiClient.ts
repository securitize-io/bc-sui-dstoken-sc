import { SuiClient } from "@mysten/sui/client";
import { ENV } from "./env";

export const suiClient = new SuiClient({
  url: ENV.SUI_NETWORK,
});
