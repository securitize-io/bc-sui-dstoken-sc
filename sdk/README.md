# Securitize Sui SDK

## RPC Transport

The SDK uses **gRPC** exclusively for all Sui network communication (`@mysten/sui/grpc`). JSON-RPC is not used.

Key details:
- Transaction building and execution use `SuiGrpcClient`
- Read-only view functions use `simulateTransaction` (gRPC equivalent of `devInspectTransactionBlock`)
- The `GRPC_URL` environment variable is required (e.g. `https://fullnode.devnet.sui.io:443`)

## Code Generation

The SDK uses `@mysten/codegen` to generate type-safe TypeScript wrappers for Move function calls. The generated code lives in `src/generated/` and handles argument type serialization automatically (addresses as `ptb.pure.address()`, objects as `ptb.object()`, strings as `ptb.pure.string()`, Clock auto-injected, etc.).

### Regenerating

When the Move contracts change, regenerate the wrappers:

```bash
cd sdk
npx sui-ts-codegen generate
```

This reads `sui-codegen.config.ts`, runs `sui move summary` on the Move package, and outputs typed TypeScript files to `src/generated/`.

### How it's used

Service classes import generated functions and call them with named arguments:

```typescript
import * as dsToken from '../generated/securitize/ds_token'

dsToken.issueTokens({
    package: Config.vars.PACKAGE_ID,
    arguments: { treasury, auth, investors, to, value, ... },
    typeArguments: [tokenAddress],
})(ptb)
```

The generated code replaces manual `ptb.moveCall()` with `MoveType` annotations, eliminating the address-vs-object type bugs that affected gRPC.

## Token Template

Token deployment uses pre-compiled Move bytecode with WASM-based identifier patching. No `sui` CLI or `sui move build` is needed at deploy time.

The flow:
1. Load pre-compiled bytecode from `src/sdk/tokenTemplate/getBytecode.ts`
2. Patch `token_template` (module) and `TOKEN_TEMPLATE` (struct) identifiers with the token symbol using `@mysten/move-bytecode-template`
3. Publish the patched bytecode via `tx.publish()`

The Move source lives in `move/token_template/`. See its [README](../move/token_template/README.md) for instructions on regenerating the embedded bytecode.

## Running Integration Tests

Integration tests should only be run on **devnet** or **localnet**. Do not run `.ts` tests on testnet — testnet deployments are persistent and shared across environments.

### Running tests on devnet

On devnet (and localnet), `deploy()` publishes fresh securitize packages each run. The `Pub.devnet.toml` ephemeral publish file is automatically cleaned before each deploy to avoid stale entries.

Set `.env`:
```
NETWORK=devnet
ADMIN_PRIVATE_KEY=<your-key>
```

Run tests:
```
pnpm install
pnpm test publish.test.ts
pnpm test "**/*.test.ts" -- --testPathIgnorePatterns=publish.test.ts
```

## Deploying to Testnet

The SDK supports deploying to testnet with optional isolated environments.

### Environment Files

| Environment | Config files loaded | Publish flag | Use case |
|-------------|---------------------|--------------|----------|
| **testnet** (default) | `.env.testnet` | None | Standard testnet deployment |
| **testnet_alpha** | `.env.testnet` + `.env.testnet_alpha` | `-e testnet_alpha` | Isolated environment for alpha testing |
| **testnet_beta** | `.env.testnet` + `.env.testnet_beta` | `-e testnet_beta` | Isolated environment for beta testing |
| **testnet_gamma** | `.env.testnet` + `.env.testnet_gamma` | `-e testnet_gamma` | Isolated environment for gamma testing |

### Using the --env Flag

```bash
# Deploy to plain testnet (default)
pnpm deploy_testnet

# Deploy to an isolated environment
pnpm deploy_testnet --env testnet_alpha
pnpm deploy_testnet --env testnet_beta
pnpm deploy_testnet --env testnet_gamma
```

### How It Works

1. **Plain testnet** (`pnpm deploy_testnet`):
   - Loads only `.env.testnet`
   - Publishes without the `-e` flag
   - Packages are deployed to the shared testnet environment

2. **Isolated environments** (`pnpm deploy_testnet --env testnet_alpha`):
   - Loads `.env.testnet`, then overrides with `.env.testnet_alpha`
   - Publishes with `-e testnet_alpha` flag
   - Creates an isolated Move environment separate from plain testnet

### When to Use Isolated Environments

The Move `-e` flag creates isolated environments on the same network. Use isolated environments when:
- Multiple teams need separate deployments
- Testing features in parallel without interference
- You need a clean environment without affecting shared testnet state
