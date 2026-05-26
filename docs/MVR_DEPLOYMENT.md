# Deploying the Securitize Move Package to Sui MVR

This guide walks through publishing the Securitize Move packages to Sui mainnet and registering the `securitize` package in the [Move Registry (MVR)](https://docs.suins.io/move-registry) so consumers can reference it by name (`@securitize/securitize`) instead of by raw package address.

**MVR scope.** Only the `securitize` package is registered in MVR. `pas` and `voloro` are still published by the existing deploy scripts (they ship on-chain alongside `securitize`), but they do **not** receive a `PackageInfo`, MVR app, or reverse-resolution entry. Everywhere this guide says "the package" it means `securitize`.

## Audience and assumptions

This document is written for the engineer(s) executing the on-chain deployment. It assumes:

- The SuiNS name (e.g. `securitize.sui`) has already been registered on **mainnet** and is held by the team's custody address.
- The **Safe / multisig address** (custodied by Fireblocks or equivalent) that will own the `UpgradeCap`s, the `securitize` `PackageInfo` objects, and the MVR `AppCap` has already been chosen.
- You have funded keys (or signer access to the Safe) on both **mainnet** and **testnet**.

## How Sui MVR works (short version)

Three facts to internalise:

1. **Each Sui package has a different address on each network.** Publishing to testnet and mainnet produces two unrelated package IDs.
2. **Each upgrade produces a new package address on its network.** The stable identity across upgrades is the `UpgradeCap`, not the address.
3. **MVR hides both forms of churn.** Consumers say `@securitize/securitize` and the registry resolves to the latest mainnet address; `@securitize/securitize/3` pins version 3.

Two on-chain layers:

- **`PackageInfo` (per package, per network).** Holds the `UpgradeCap`, a `GitInfo` record (repo URL + subdir + commit), a `Display`, and an optional `default` MVR name for reverse-resolution.
- **MVR app registration (mainnet only).** A single source of truth on mainnet that maps `@<suins>/<pkg>` to `PackageInfo` objects across all networks. Controlled by an `AppCap` minted at registration time.

Because MVR scope is limited to `securitize`, the end-state is: **1 MVR name** (`@securitize/securitize`), **up to 2 `PackageInfo` objects** (testnet + mainnet), and **1 `AppCap`** (mainnet).

---

## Phase 1 — Open-source the repository

Pick a license, add `LICENSE`, `README.md`, `SECURITY.md`, `CONTRIBUTING.md`, and `CODE_OF_CONDUCT.md`, scrub history for secrets, run `pnpm audit` clean, then cut a signed annotated tag (e.g. `mainnet-v1.0.0`) and make the GitHub repo public. The tag's commit SHA is what gets embedded in the mainnet `securitize` `PackageInfo.GitInfo`, so it must be permanent and public before Phase 3 begins.

---

## Phase 2 — Publish, then create the `securitize` `PackageInfo`

Two parts: publish all three packages using the existing repo tooling (2.1), then build a `PackageInfo` only for `securitize` (2.2). Do **testnet first**, smoke-test, then repeat on mainnet. The publish order — `pas` → `securitize` → `voloro` — is fixed by the local Move dependency chain and is already enforced by [sdk/src/scripts/deploy.ts](sdk/src/scripts/deploy.ts).

All identifiers produced by this and later phases are tracked in `deployments/<network>.json` (committed). Append to it as you go; the final shape per network is:

```json
{
  "network": "mainnet",
  "packages": {
    "pas":        { "packageId": "0x…", "upgradeCapId": "0x…", "gitCommit": "abc123…" },
    "securitize": { "packageId": "0x…", "upgradeCapId": "0x…", "packageInfoId": "0x…", "appCapId": "0x…", "gitCommit": "abc123…" },
    "voloro":     { "packageId": "0x…", "upgradeCapId": "0x…", "gitCommit": "abc123…" }
  }
}
```

`packageInfoId` is created in 2.2 and `appCapId` in Phase 3 — both apply only to `securitize`. `pas` and `voloro` carry their published IDs only.

All scripts below assume you are running from `sdk/`, where `@mysten/sui` and `tsx` are already installed. Set these environment variables once per shell:

```bash
export NETWORK=testnet                                # or mainnet
export CUSTODY_ADDRESS=0x…                             # Safe address that will own the objects
export GIT_REPO_URL=https://github.com/securitize-io/<repo>
export GIT_COMMIT=$(git rev-parse mainnet-v1.0.0)
```

### 2.1 — Publish

Publishing is handled by the existing repo scripts: [sdk/src/scripts/deploy.ts](sdk/src/scripts/deploy.ts), driven by the `pnpm --filter @securitize/sui-sdk deploy_<network>` commands defined in [sdk/package.json](sdk/package.json). These scripts already select the right Sui environment and write a `Pub.<network>.toml` artifact for each package, covering all three of `pas`, `securitize`, and `voloro`.

After each successful publish, copy the identifiers from `Pub.<network>.toml` (or from the publish tx effects) into `deployments/<network>.json`:

- `packageId` (all three packages)
- `upgradeCapId` (all three packages) — transfer to the Safe immediately if the deploy script did not already
- `publisherId` (if `init` minted one)

The MVR work in 2.2 onwards only consumes `securitize.upgradeCapId`, but `pas` and `voloro` still need their `UpgradeCap`s safely custodied for future upgrades.

### 2.2 — Create the `securitize` `PackageInfo`

`PackageInfo` is transferable **only at creation** — the Move type forbids public transfers afterwards, so it must be moved to the Safe in the same PTB that creates it. Because the `UpgradeCap` lives in the Fireblocks-custodied Safe, the operator never sees a private key; we split the workflow into three steps:

1. **Build** — operator constructs the PTB locally and writes the unsigned transaction bytes to a file.
2. **Sign** — the file is handed to Fireblocks (or any external signer that controls the Safe address). The signer returns a Sui-formatted signature.
3. **Submit** — operator submits the bytes + signature to the network.

Two scripts implement this flow. They are reused unchanged in Phases 3, 4, and 6 (any operation against a Safe-owned object follows the same pattern).

#### 2.2.a — `build_package_info_tx.ts`

Create `sdk/src/scripts/build_package_info_tx.ts`:

```ts
import { SuiJsonRpcClient, getJsonRpcFullnodeUrl } from '@mysten/sui/jsonRpc';
import { Transaction } from '@mysten/sui/transactions';
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';

const network = process.env.NETWORK as 'mainnet' | 'testnet';
const custody = process.env.CUSTODY_ADDRESS!;           // Safe address (sender + gas owner)
const repoUrl = process.env.GIT_REPO_URL!;
const commit = process.env.GIT_COMMIT!;
const gasBudget = BigInt(process.env.GAS_BUDGET ?? '500000000');

const PKG = 'securitize';

const deployments = JSON.parse(readFileSync(`deployments/${network}.json`, 'utf8'));
const upgradeCapId: string = deployments.packages[PKG].upgradeCapId;

// SuiJsonRpcClient auto-wires MVR resolution against the per-network endpoint
// (https://<network>.mvr.mystenlabs.com); pass `mvr: { url }` to override.
const client = new SuiJsonRpcClient({ network, url: getJsonRpcFullnodeUrl(network) });

// `set_git_versioning` needs the on-chain package version the GitInfo describes.
// Read it off the UpgradeCap (1 for a fresh publish; bumps by 1 on each upgrade).
const capResp = await client.getObject({ id: upgradeCapId, options: { showContent: true } });
if (capResp.data?.content?.dataType !== 'moveObject') {
  throw new Error(`UpgradeCap ${upgradeCapId} not found`);
}
const upgradeCapVersion = BigInt(
  (capResp.data.content.fields as { version: string }).version,
);

const tx = new Transaction();
tx.setSender(custody);
tx.setGasOwner(custody);
tx.setGasBudget(gasBudget);

// 1. Create PackageInfo from the UpgradeCap (the cap is `&mut`-borrowed, not consumed —
//    it stays owned by `custody` and is what you use for future upgrades).
const packageInfo = tx.moveCall({
  target: '@mvr/metadata::package_info::new',
  arguments: [tx.object(upgradeCapId)],
});

// 2. Build + attach GitInfo at the current package version
const gitInfo = tx.moveCall({
  target: '@mvr/metadata::git::new',
  arguments: [
    tx.pure.string(repoUrl),
    tx.pure.string(`move/${PKG}`),
    tx.pure.string(commit),
  ],
});
tx.moveCall({
  target: '@mvr/metadata::package_info::set_git_versioning',
  arguments: [packageInfo, tx.pure.u64(upgradeCapVersion), gitInfo],
});

// 3. Build + attach Display
const display = tx.moveCall({
  target: '@mvr/metadata::display::default',
  arguments: [tx.pure.string('Securitize')],
});
tx.moveCall({
  target: '@mvr/metadata::package_info::set_display',
  arguments: [packageInfo, display],
});

// 4. Transfer to custody — last chance, PackageInfo cannot be transferred again afterwards
tx.moveCall({
  target: '@mvr/metadata::package_info::transfer',
  arguments: [packageInfo, tx.pure.address(custody)],
});

const bytes = await tx.build({ client });
const b64 = Buffer.from(bytes).toString('base64');

mkdirSync('out', { recursive: true });
const outPath = `out/tx-${network}-${PKG}-package-info.b64`;
writeFileSync(outPath, b64, 'utf8');

console.log('Unsigned transaction bytes written to:', outPath);
console.log('Sender / gas owner:', custody);
console.log('Gas budget:', gasBudget.toString());
console.log('Hand this file to Fireblocks for signing.');
```

Run it once per network:

```bash
NETWORK=testnet pnpm exec tsx src/scripts/build_package_info_tx.ts
# Repeat with NETWORK=mainnet after testnet is verified.
```

The output `out/tx-<network>-securitize-package-info.b64` contains the BCS-encoded `TransactionData` (base64). This is what Fireblocks signs.

#### 2.2.b — Fireblocks signing

Hand `out/tx-<network>-securitize-package-info.b64` to whoever drives the Fireblocks workspace (or run it through the Fireblocks SDK directly if you have API access from the operator machine). The signer's job:

1. Decode the base64 to raw bytes.
2. Submit a `RAW` signing operation under the Sui vault account that controls `CUSTODY_ADDRESS`, with the bytes as the message.
3. After approval, retrieve the raw 64-byte Ed25519 signature and the public key of the signing vault.
4. Assemble a Sui-formatted signature (flag byte `0x00` for Ed25519 || 64-byte signature || 32-byte public key, base64-encoded) and return it.

If Fireblocks returns the assembled Sui signature directly, skip step 4. If it returns only the raw signature, assemble it locally:

```ts
import { toSerializedSignature } from '@mysten/sui/cryptography';
import { Ed25519PublicKey } from '@mysten/sui/keypairs/ed25519';

const serialized = toSerializedSignature({
  signatureScheme: 'ED25519',
  signature: rawSigBytes,                       // 64 bytes from Fireblocks
  publicKey: new Ed25519PublicKey(safePubKeyBytes),  // 32 bytes — Safe vault's pubkey
});
// `serialized` is the base64 string to pass to the submit script.
```

#### 2.2.c — `submit_signed_tx.ts`

Create `sdk/src/scripts/submit_signed_tx.ts`. This is generic and is reused for every Safe-signed transaction in this guide:

```ts
import { SuiJsonRpcClient, getJsonRpcFullnodeUrl } from '@mysten/sui/jsonRpc';
import { readFileSync } from 'node:fs';

const network = process.env.NETWORK as 'mainnet' | 'testnet';
const bytesFile = process.env.BYTES_FILE!;          // e.g. out/tx-mainnet-securitize-package-info.b64
const sigFile = process.env.SIG_FILE!;              // file containing the Sui-formatted signature (base64)

const transactionBlock = Buffer.from(readFileSync(bytesFile, 'utf8').trim(), 'base64');
const signature = readFileSync(sigFile, 'utf8').trim();

const client = new SuiJsonRpcClient({ network, url: getJsonRpcFullnodeUrl(network) });

const result = await client.executeTransactionBlock({
  transactionBlock,
  signature,
  options: { showObjectChanges: true, showEffects: true, showEvents: true },
  requestType: 'WaitForLocalExecution',
});

if (result.effects?.status?.status !== 'success') {
  console.error('Transaction failed:', result.effects?.status);
  process.exit(1);
}

const created = (result.objectChanges ?? []).filter((c: any) => c.type === 'created');
console.log('Tx digest:', result.digest);
console.log('Created objects:');
for (const c of created) console.log(' ', (c as any).objectType, '→', (c as any).objectId);
```

Submit each transaction once Fireblocks returns the signature:

```bash
NETWORK=testnet \
  BYTES_FILE=out/tx-testnet-securitize-package-info.b64 \
  SIG_FILE=out/sig-testnet-securitize-package-info.b64 \
  pnpm exec tsx src/scripts/submit_signed_tx.ts
```

From the printed `Created objects`, find the line ending in `::package_info::PackageInfo` and copy its object ID into `deployments/<network>.json` under `packages.securitize.packageInfoId`.

> **Why the explicit `setSender` / `setGasOwner` / `setGasBudget`.** When `tx.build` is called without an active signer, the SDK has no way to infer who pays gas or what the budget is, and it cannot dry-run as the signer. Setting these explicitly is required for offline-signing flows like Fireblocks. The Safe must hold enough SUI on the target network to cover `gasBudget`.

### 2.3 — Verify

```bash
sui client object <packageInfoId>
```

Confirm `upgrade_cap` is set, `git_versioning` reflects the right repo/subdir/commit, and the owner is the Safe.

---

## Phase 3 — Register the MVR app on mainnet

Performed **once, on mainnet only**, for `securitize`. The SuiNS name NFT is required as input; the script reads both the mainnet and testnet `securitize.packageInfoId` values from `deployments/*.json` so the single PTB can bind both networks atomically.

The MVR registry currently requires the SuiNS NFT to be present in the transaction, which means whoever submits this PTB must hold the SuiNS NFT. If the SuiNS NFT lives in the Safe (recommended), the operator builds, Fireblocks signs, the operator submits — same offline-signing pattern as 2.2.

Create `sdk/src/scripts/build_register_mvr_app_tx.ts`:

```ts
import { SuiJsonRpcClient, getJsonRpcFullnodeUrl } from '@mysten/sui/jsonRpc';
import { Transaction } from '@mysten/sui/transactions';
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';

const PKG = 'securitize';
const MVR_NAME = '@securitize/securitize';
const TESTNET_CHAIN_ID = '4c78adac';

const suinsObjectId = process.env.SUINS_OBJECT_ID!;     // SuiNS Name NFT held by the Safe
const mvrRegistryId = process.env.MVR_REGISTRY_ID!;     // Shared MoveRegistry object on mainnet
const custody = process.env.CUSTODY_ADDRESS!;
const repoUrl = process.env.GIT_REPO_URL!;
const gasBudget = BigInt(process.env.GAS_BUDGET ?? '500000000');

const mainnet = JSON.parse(readFileSync('deployments/mainnet.json', 'utf8'));
const testnet = JSON.parse(readFileSync('deployments/testnet.json', 'utf8'));
const mainnetPackageInfoId = mainnet.packages[PKG].packageInfoId;
const testnetPackageInfoId = testnet.packages[PKG].packageInfoId;

const client = new SuiJsonRpcClient({ network: 'mainnet', url: getJsonRpcFullnodeUrl('mainnet') });

const tx = new Transaction();
tx.setSender(custody);
tx.setGasOwner(custody);
tx.setGasBudget(gasBudget);

// 1. Register the MVR name → AppCap
const appCap = tx.moveCall({
  target: '@mvr/core::move_registry::register',
  arguments: [
    tx.object(mvrRegistryId),
    tx.object(suinsObjectId),
    tx.pure.string(PKG),
    tx.object('0x6'), // Clock
  ],
});

// 2. Metadata
for (const [key, value] of [
  ['description',       'Securitize Move package — tokenized RWA primitives'],
  ['homepage_url',      'https://securitize.io'],
  ['documentation_url', `${repoUrl}#readme`],
  ['icon_url',          'https://securitize.io/icon.svg'],
  ['contact',           'security@securitize.io'],
] as const) {
  tx.moveCall({
    target: '@mvr/core::move_registry::set_metadata',
    arguments: [appCap, tx.pure.string(key), tx.pure.string(value)],
  });
}

// 3. Bind mainnet PackageInfo — PERMANENT
tx.moveCall({
  target: '@mvr/core::move_registry::assign_package',
  arguments: [appCap, tx.object(mainnetPackageInfoId)],
});

// 4. Bind testnet PackageInfo by chain ID
tx.moveCall({
  target: '@mvr/core::move_registry::set_network',
  arguments: [
    appCap,
    tx.pure.string(TESTNET_CHAIN_ID),
    tx.object(testnetPackageInfoId),
  ],
});

// 5. Transfer AppCap to custody
tx.transferObjects([appCap], tx.pure.address(custody));

const bytes = await tx.build({ client });
const b64 = Buffer.from(bytes).toString('base64');

mkdirSync('out', { recursive: true });
const outPath = `out/tx-mainnet-${PKG}-register.b64`;
writeFileSync(outPath, b64, 'utf8');

console.log('Unsigned transaction bytes written to:', outPath);
console.log('MVR name to be created:', MVR_NAME);
console.log('Sender / gas owner:', custody);
console.log('Gas budget:', gasBudget.toString());
console.log('Hand this file to Fireblocks for signing.');
```

Run it (mainnet only):

```bash
SUINS_OBJECT_ID=0x… MVR_REGISTRY_ID=0x… pnpm exec tsx src/scripts/build_register_mvr_app_tx.ts
```

`MVR_REGISTRY_ID` is the shared `MoveRegistry` object exposed by `@mvr/core` on mainnet. Look it up via [docs.suins.io/move-registry/mvr-names](https://docs.suins.io/move-registry/mvr-names) or the [MystenLabs/mvr](https://github.com/MystenLabs/mvr) deployment table.

Hand the output through the same Fireblocks signing flow as 2.2.b, then submit with `submit_signed_tx.ts`:

```bash
NETWORK=mainnet \
  BYTES_FILE=out/tx-mainnet-securitize-register.b64 \
  SIG_FILE=out/sig-mainnet-securitize-register.b64 \
  pnpm exec tsx src/scripts/submit_signed_tx.ts
```

From the printed `Created objects`, locate `::move_registry::AppCap` and copy its object ID into `deployments/mainnet.json` under `packages.securitize.appCapId`.

> **`assign_package` is permanent.** A `PackageInfo` cannot be detached from an MVR name once assigned. Verify `mainnetPackageInfoId` against `deployments/mainnet.json` before signing. `set_network` for non-mainnet bindings is reversible.

---

## Phase 4 — Enable reverse resolution

For the `securitize` `PackageInfo` on **each network**, set `default = "@securitize/securitize"` so explorers can turn a raw package address back into the MVR name. Must be done **after** Phase 3 so the name already points to this `PackageInfo`.

Create `sdk/src/scripts/build_set_default_tx.ts`:

```ts
import { SuiJsonRpcClient, getJsonRpcFullnodeUrl } from '@mysten/sui/jsonRpc';
import { Transaction } from '@mysten/sui/transactions';
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';

const PKG = 'securitize';
const MVR_NAME = '@securitize/securitize';

const network = process.env.NETWORK as 'mainnet' | 'testnet';
const custody = process.env.CUSTODY_ADDRESS!;
const gasBudget = BigInt(process.env.GAS_BUDGET ?? '100000000');

const deployments = JSON.parse(readFileSync(`deployments/${network}.json`, 'utf8'));
const packageInfoId = deployments.packages[PKG].packageInfoId;

const client = new SuiJsonRpcClient({ network, url: getJsonRpcFullnodeUrl(network) });

const tx = new Transaction();
tx.setSender(custody);
tx.setGasOwner(custody);
tx.setGasBudget(gasBudget);

tx.moveCall({
  target: '@mvr/metadata::package_info::set_metadata',
  arguments: [
    tx.object(packageInfoId),
    tx.pure.string('default'),
    tx.pure.string(MVR_NAME),
  ],
});

const bytes = await tx.build({ client });
const b64 = Buffer.from(bytes).toString('base64');

mkdirSync('out', { recursive: true });
const outPath = `out/tx-${network}-${PKG}-set-default.b64`;
writeFileSync(outPath, b64, 'utf8');

console.log('Unsigned transaction bytes written to:', outPath);
console.log(`Will set ${network} ${PKG} PackageInfo.default = ${MVR_NAME}`);
console.log('Hand this file to Fireblocks for signing.');
```

Run once per network, sign via Fireblocks, then submit with `submit_signed_tx.ts`:

```bash
for net in testnet mainnet; do
  NETWORK=$net pnpm exec tsx src/scripts/build_set_default_tx.ts
done
```

---

## Phase 5 — Expose the MVR name to consumers

Once `@securitize/securitize` resolves end-to-end on mainnet.

### 5.1 — `Move.toml` consumption

External Move consumers depend on the package via MVR. In their `Move.toml`:

```toml
[dependencies]
securitize = { r.mvr = "@securitize/securitize" }

[r.mvr]
network = "mainnet"
```

For this repo's own internal builds, keep `local = "../securitize"` in [move/voloro/Move.toml](move/voloro/Move.toml) so internal development does not require a network round-trip. The same applies to `pas` (always local). Document the external form in [README.md](README.md).

### 5.2 — TypeScript SDK consumption

As of `@mysten/sui` 2.15 the MVR plugin is **auto-attached** to every `Transaction` that is built or executed through a `SuiJsonRpcClient` / `SuiGrpcClient`. No explicit `Transaction.registerGlobalSerializationPlugin` call is needed — the client's `network` parameter selects the right MVR endpoint (`https://<network>.mvr.mystenlabs.com`) automatically.

Just instantiate the client with the active network:

```ts
import { SuiJsonRpcClient, getJsonRpcFullnodeUrl } from '@mysten/sui/jsonRpc';

const client = new SuiJsonRpcClient({
  network: 'mainnet',                       // or 'testnet'
  url: getJsonRpcFullnodeUrl('mainnet'),
  // Optional: pin a specific MVR endpoint or local overrides.
  // mvr: { url: 'https://mainnet.mvr.mystenlabs.com' },
});
```

With this client, the SDK can build transactions using `target: '@securitize/securitize::module::function'` and the auto-plugin substitutes the right package ID at build/execute time. `pas` and `voloro` continue to be referenced by their raw package IDs from `deployments/<network>.json`.

---

## Phase 6 — Upgrade workflow (ongoing)

This applies whenever the on-chain `securitize` bytecode changes. `pas` and `voloro` upgrades follow the standard `sui client upgrade` flow with no MVR follow-up; only `securitize` needs steps 4–5 below.

1. Land the change on `main`, then cut a new signed tag (`mainnet-v1.1.0`) and push it.
2. Capture the new commit: `export NEW_COMMIT=$(git rev-parse mainnet-v1.1.0)`.
3. Upgrade the package on testnet first, then mainnet. The `UpgradeCap` is in the Safe, so the upgrade itself also goes through the build/sign/submit flow — driven either by the existing deploy tooling (if it already supports offline signing) or by a small `build_upgrade_tx.ts` mirroring the patterns in 2.2.a. The `UpgradeCap` inside the `PackageInfo` automatically follows the new version; no MVR re-registration is needed.

4. Refresh `GitInfo` on the `securitize` `PackageInfo`. Create `sdk/src/scripts/build_update_git_info_tx.ts`:

   ```ts
   import { SuiJsonRpcClient, getJsonRpcFullnodeUrl } from '@mysten/sui/jsonRpc';
   import { Transaction } from '@mysten/sui/transactions';
   import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';

   const PKG = 'securitize';
   const network = process.env.NETWORK as 'mainnet' | 'testnet';
   const custody = process.env.CUSTODY_ADDRESS!;
   const repoUrl = process.env.GIT_REPO_URL!;
   const commit = process.env.NEW_COMMIT!;
   const gasBudget = BigInt(process.env.GAS_BUDGET ?? '100000000');

   const deployments = JSON.parse(readFileSync(`deployments/${network}.json`, 'utf8'));
   const packageInfoId = deployments.packages[PKG].packageInfoId;
   const upgradeCapId: string = deployments.packages[PKG].upgradeCapId;

   const client = new SuiJsonRpcClient({ network, url: getJsonRpcFullnodeUrl(network) });

   // After the upgrade, read the new package version off the UpgradeCap so the
   // GitInfo is bound to the version it actually describes.
   const capResp = await client.getObject({ id: upgradeCapId, options: { showContent: true } });
   if (capResp.data?.content?.dataType !== 'moveObject') {
     throw new Error(`UpgradeCap ${upgradeCapId} not found`);
   }
   const upgradeCapVersion = BigInt(
     (capResp.data.content.fields as { version: string }).version,
   );

   const tx = new Transaction();
   tx.setSender(custody);
   tx.setGasOwner(custody);
   tx.setGasBudget(gasBudget);

   const gitInfo = tx.moveCall({
     target: '@mvr/metadata::git::new',
     arguments: [
       tx.pure.string(repoUrl),
       tx.pure.string(`move/${PKG}`),
       tx.pure.string(commit),
     ],
   });
   tx.moveCall({
     target: '@mvr/metadata::package_info::set_git_versioning',
     arguments: [tx.object(packageInfoId), tx.pure.u64(upgradeCapVersion), gitInfo],
   });

   const bytes = await tx.build({ client });
   const b64 = Buffer.from(bytes).toString('base64');
   mkdirSync('out', { recursive: true });
   const outPath = `out/tx-${network}-${PKG}-update-git.b64`;
   writeFileSync(outPath, b64, 'utf8');
   console.log('Unsigned transaction bytes written to:', outPath);
   ```

   Run for each network where the upgrade landed, sign via Fireblocks, then submit with `submit_signed_tx.ts`:

   ```bash
   NETWORK=mainnet NEW_COMMIT=$NEW_COMMIT pnpm exec tsx src/scripts/build_update_git_info_tx.ts
   ```

5. Update `deployments/<network>.json` with the new `gitCommit` for `securitize`. Consumers using `@securitize/securitize` automatically pick up the new version; consumers pinned to `@securitize/securitize/N` continue to resolve to version N.

---

## Custody and key-management notes

The Safe must hold and never release the following (Phase 2 onwards):

1. **`UpgradeCap`** for each of `pas`, `securitize`, and `voloro` (per network) — anyone holding any of these can upgrade the respective package's on-chain bytecode. Compromise = attacker replaces your code.
2. **`PackageInfo`** for `securitize` (per network) — controls the `GitInfo` and `default` metadata that MVR consumers see.
3. **`AppCap`** for `@securitize/securitize` (mainnet only) — controls metadata and network bindings of the MVR name. Compromise = attacker repoints testnet bindings or defaces metadata; the mainnet `assign_package` binding itself is permanent.
4. **SuiNS name NFT** (mainnet) — controls the `<suins>` prefix. Compromise = attacker registers additional apps under your name.

Document the Safe's owners and threshold in an internal runbook (not in this public guide).

---

## Verification checklist

- [ ] `deployments/mainnet.json` and `deployments/testnet.json` are committed, with `packageId` + `upgradeCapId` for all three packages and additionally `packageInfoId` for `securitize` (plus `appCapId` for `securitize` on mainnet).
- [ ] `mvr resolve @securitize/securitize --network mainnet` returns the mainnet `securitize` package ID in `deployments/mainnet.json`.
- [ ] `mvr resolve @securitize/securitize --network testnet` returns the testnet `securitize` package ID in `deployments/testnet.json`.
- [ ] `sui client object <packageInfoId>` on each network shows the correct owner (Safe), correct `GitInfo`, and `default` metadata equal to `@securitize/securitize`.
- [ ] `sui client objects --owner <safe>` on mainnet lists the `AppCap`, the `securitize` `PackageInfo`, and the three `UpgradeCap`s (`pas`, `securitize`, `voloro`). On testnet, lists the three `UpgradeCap`s and the `securitize` `PackageInfo`.
- [ ] An external developer can run `sui move build` in a fresh project depending on `securitize = { r.mvr = "@securitize/securitize" }` and the build resolves.

---

## References

- [Move Registry overview](https://docs.suins.io/move-registry)
- [Managing MVR names (mainnet only)](https://docs.suins.io/move-registry/mvr-names)
- [Managing PackageInfo](https://docs.suins.io/move-registry/managing-package-info)
- [MVR CLI](https://docs.suins.io/move-registry/tooling/mvr-cli)
- [MVR TypeScript SDK plugin](https://docs.suins.io/move-registry/tooling/typescript-sdk)
- [MystenLabs/mvr on GitHub](https://github.com/MystenLabs/mvr)
