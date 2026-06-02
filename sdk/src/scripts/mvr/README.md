# MVR setup scripts

These scripts implement Phases 2.2, 3, 4, and 6 of [docs/MVR_DEPLOYMENT.md](../../../../docs/MVR_DEPLOYMENT.md) for the `securitize` Move package. They cover both **testnet (test runs)** and **mainnet (production)** without modification.

## Files

| Script                           | Phase | Purpose                                                                                                                                                                |
| -------------------------------- | ----- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `phase-2-create-package-info.ts` | 2.2   | Wraps `securitize`'s `UpgradeCap` in a `PackageInfo`, attaches `GitInfo` + `Display`, transfers to custody.                                                            |
| `phase-3-register-app.ts`        | 3     | **Mainnet only.** Registers `@<suins>/securitize` on the MVR registry, sets metadata, binds mainnet+testnet `PackageInfo`s, transfers the `AppCap` to custody.         |
| `phase-4-set-default.ts`         | 4     | Writes `default = <mvrName>` metadata on the `PackageInfo` to enable reverse resolution. Runs per network.                                                             |
| `phase-6-update-git-info.ts`     | 6     | Refreshes the `GitInfo` pointer on the `PackageInfo` after a package upgrade. Runs per network.                                                                        |
| `update-metadata.ts`             | —     | **Mainnet only.** Set or unset a single key on the MVR `AppRecord` metadata (the fields seeded by Phase 3). Set when `METADATA_VALUE` is provided; unset when omitted. |
| `submit-signed.ts`               | —     | Submits a pre-signed transaction (bytes + signature from Fireblocks).                                                                                                  |
| `_shared.ts`                     | —     | Common utilities.                                                                                                                                                      |

## Configuration

Per-network MVR config lives in `sdk/mvr/<network>.json`. Identifiers produced by the scripts are tracked in `sdk/deployments/<network>.json`.

Edit both `sdk/mvr/testnet.json` and `sdk/mvr/mainnet.json` before running. For testnet, only `mvrName`, `repoUrl`, `gitSubdir`, and `displayName` matter. For mainnet, additionally fill in `suinsNftId` (your `SuinsRegistration` object) and `mvrRegistryId` (the shared MVR `MoveRegistry` object).

The default `mvrName` is `@testdomain/securitize`. Change in `mainnet.json` if your production SuiNS name differs.

## Signing modes

Each phase script chooses its mode automatically:

1. **Hot-key sign-and-execute** — `OPERATOR_PRIVATE_KEY` is set. The script signs and submits in one step. Use this on testnet, and on mainnet for the initial bootstrap if you choose to do MVR setup from a single hot address and transfer everything to Fireblocks afterwards.
2. **Build-bytes for offline signing** — `OPERATOR_PRIVATE_KEY` is unset. The script writes the unsigned BCS-encoded transaction to `sdk/out/tx-<network>-<label>.b64`. Hand the file to Fireblocks (RAW Sui signing), get a Sui-formatted signature back as base64, and submit with `submit-signed.ts`.

If Fireblocks returns only the raw 64-byte Ed25519 signature, assemble the Sui-formatted signature locally:

```ts
import { toSerializedSignature } from '@mysten/sui/cryptography'
import { Ed25519PublicKey } from '@mysten/sui/keypairs/ed25519'

const serialized = toSerializedSignature({
    signatureScheme: 'ED25519',
    signature: rawSigBytes,
    publicKey: new Ed25519PublicKey(safePubKeyBytes),
})
// Write `serialized` to SIG_FILE.
```

## Required environment variables

Common to all phase scripts:

| Var                    | Description                                                                                                             |
| ---------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| `NETWORK`              | `testnet` or `mainnet`                                                                                                  |
| `CUSTODY_ADDRESS`      | Address that will own the created objects. Operator address on testnet/bootstrap; Fireblocks Safe in steady state.      |
| `OPERATOR_PRIVATE_KEY` | Bech32 `suiprivkey1...`. Presence flips signing mode. Get one via `sui keytool export --key-identity <address> --json`. |
| `GAS_BUDGET`           | Optional. Defaults: 5×10⁸ for `phase-2`/`phase-3`, 1×10⁸ for `phase-4`/`phase-6`.                                       |
| `SDK_ROOT`             | Optional. Override config / deployments / out directory root. Defaults to `process.cwd()`.                              |

Phase-specific:

- `phase-2-create-package-info.ts` → `GIT_COMMIT` (commit SHA to record in `GitInfo`).
- `phase-6-update-git-info.ts` → `GIT_COMMIT` (the new commit after the upgrade).
- `update-metadata.ts` → `METADATA_KEY` (the AppRecord key to mutate); `METADATA_VALUE` (omit or set to `""` to unset; any other string sets the value).
- `submit-signed.ts` → `BYTES_FILE`, `SIG_FILE`.

## End-to-end testnet flow

```bash
cd sdk

# 1. Publish using the existing repo scripts. This produces Pub.testnet.toml.
pnpm deploy_testnet

# 2. Create sdk/deployments/testnet.json and copy the IDs for `securitize`
#    out of Pub.testnet.toml (or the publish transaction effects):
#    {
#      "network": "testnet",
#      "packages": {
#        "securitize": {
#          "packageId":    "0x…",
#          "upgradeCapId": "0x…",
#          "gitCommit":    "abc…"
#        }
#      }
#    }

# 3. Export env (hot-key mode for testnet).
export NETWORK=testnet
export CUSTODY_ADDRESS=$(sui client active-address)
export OPERATOR_PRIVATE_KEY=$(sui keytool export --key-identity "$CUSTODY_ADDRESS" --json | jq -r .exportedPrivateKey)
export GIT_COMMIT=$(git rev-parse HEAD)

# 4. Create PackageInfo. Writes packageInfoId back to deployments/testnet.json.
pnpm exec tsx src/scripts/mvr/phase-2-create-package-info.ts

# 5. Set reverse-resolution default. (Note: until Phase 3 runs on mainnet for
#    @testdomain/securitize, the name itself won't resolve — but the metadata
#    is still valid to write.)
pnpm exec tsx src/scripts/mvr/phase-4-set-default.ts

# 6. Inspect the result.
sui client object $(jq -r .packages.securitize.packageInfoId < deployments/testnet.json)
```

## Mainnet flow

Prerequisites:

- `sdk/deployments/testnet.json` has `packages.securitize.packageInfoId` (the testnet binding to attach during Phase 3).
- `sdk/deployments/mainnet.json` has `packages.securitize.packageId` + `upgradeCapId` (from the mainnet publish).
- `sdk/mvr/mainnet.json` has `suinsNftId` and `mvrRegistryId` filled in.
- `CUSTODY_ADDRESS` holds the SuiNS NFT at the moment Phase 3 runs.

```bash
export NETWORK=mainnet
export CUSTODY_ADDRESS=0x…
export OPERATOR_PRIVATE_KEY=…            # omit to enter build-bytes/Fireblocks mode
export GIT_COMMIT=$(git rev-parse mainnet-v1.0.0)

# Phase 2: create mainnet PackageInfo
pnpm exec tsx src/scripts/mvr/phase-2-create-package-info.ts

# Phase 3: register the MVR app (mainnet only). Atomic PTB that registers,
# sets metadata, binds mainnet PackageInfo (permanent), binds testnet
# PackageInfo, and transfers the AppCap to CUSTODY_ADDRESS.
pnpm exec tsx src/scripts/mvr/phase-3-register-app.ts

# Phase 4: set default metadata on the mainnet PackageInfo
pnpm exec tsx src/scripts/mvr/phase-4-set-default.ts
```

## Maintenance — updating AppRecord metadata

Phase 3 seeds five canonical keys on the on-chain `AppRecord`: `description`, `homepage_url`, `documentation_url`, `icon_url`, `contact`. Re-run `phase-3-register-app.ts` would fail (`register` is one-shot); use `update-metadata.ts` to mutate one key at a time. Mainnet only — the `MoveRegistry` is mainnet only.

Prerequisites:

- Phase 3 has completed and `sdk/deployments/mainnet.json.packages.securitize.appCapId` is populated.
- `CUSTODY_ADDRESS` is the current owner of that `AppCap`.

```bash
# Update documentation URL (hot-key mode)
NETWORK=mainnet \
  CUSTODY_ADDRESS=0x… \
  OPERATOR_PRIVATE_KEY=suiprivkey1… \
  METADATA_KEY=documentation_url \
  METADATA_VALUE=https://docs.securitize.io/sui \
  pnpm exec tsx src/scripts/mvr/update-metadata.ts

# Clear the contact key (omit METADATA_VALUE entirely — or set it to "")
NETWORK=mainnet \
  CUSTODY_ADDRESS=0x… \
  OPERATOR_PRIVATE_KEY=suiprivkey1… \
  METADATA_KEY=contact \
  pnpm exec tsx src/scripts/mvr/update-metadata.ts

# Build-only for Fireblocks signing
NETWORK=mainnet \
  CUSTODY_ADDRESS=0x… \
  METADATA_KEY=homepage_url \
  METADATA_VALUE=https://securitize.io \
  pnpm exec tsx src/scripts/mvr/update-metadata.ts
# → writes sdk/out/tx-mainnet-securitize-metadata-homepage_url.b64, then sign + submit-signed.ts
```

Caveats:

- The Move package does not enforce a key schema — `METADATA_KEY=documentaion_url` (typo) silently writes a junk key alongside the real one. Stick to the canonical five unless you have a reason not to.
- `documentation_url` / `icon_url` flow to suins.io and any MVR consumer quickly; smoke-test the URL first.
- `METADATA_VALUE=""` is treated as unset. If you genuinely want an empty string on-chain you'd have to modify the script.

## Fireblocks signing (build-only mode)

Run any phase script with `OPERATOR_PRIVATE_KEY` unset. It will write a file like `sdk/out/tx-mainnet-securitize-register.b64`. Sign those bytes externally (Sui ED25519 over the raw `TransactionData`), then submit:

```bash
NETWORK=mainnet \
  BYTES_FILE=sdk/out/tx-mainnet-securitize-register.b64 \
  SIG_FILE=sdk/out/sig-mainnet-securitize-register.b64 \
  pnpm exec tsx src/scripts/mvr/submit-signed.ts
```

After Phase 3 completes in build-only mode, manually update `sdk/deployments/mainnet.json` with the `appCapId` from the transaction effects — the script can't write it back when it didn't sign.

## Finding shared object IDs (mainnet)

For Phase 3:

- **`suinsNftId`** — the `SuinsRegistration` NFT for your SuiNS domain. List with `sui client objects --owner <suins-holder-address>` and filter to types ending in `::suins_registration::SuinsRegistration`.
- **`mvrRegistryId`** — the shared `MoveRegistry` object exposed by `@mvr/core`. Look it up in [docs.suins.io/move-registry/mvr-names](https://docs.suins.io/move-registry/mvr-names) or the [MystenLabs/mvr](https://github.com/MystenLabs/mvr) deployment table for mainnet.

## Notes

- `sdk/out/` is for transient build-mode artifacts. Add it to `.gitignore` if you want; the bytes themselves are not secret, but keeping `out/` clean avoids noise in `git status`.
- `assign_package` (inside Phase 3) is permanent. Verify `deployments/mainnet.json` and `deployments/testnet.json` are correct before signing the Phase 3 transaction.
- MVR name resolution (`@mvr/core::*`, `@mvr/metadata::*`) is auto-wired into `SuiJsonRpcClient` (and `SuiGrpcClient`) as of `@mysten/sui` 2.15 — no plugin registration is needed. The endpoint defaults to `https://<network>.mvr.mystenlabs.com` based on the client's `network` field. If you hit resolution errors on testnet (almost always because one of those packages isn't published there), pass `mvr: { url, overrides }` to the client constructor to pin a different endpoint or hardcode `packages`/`types`.
