# Securitize Sui SDK

## RPC Transport

The SDK uses **gRPC** exclusively for all Sui network communication (`@mysten/sui/grpc`). JSON-RPC is not used.

Key details:
- Transaction building and execution use `SuiGrpcClient`
- Read-only view functions use `simulateTransaction` (gRPC equivalent of `devInspectTransactionBlock`)
- The `simulateTransaction` resolution plugin resolves all `ptb.object()` inputs server-side. Addresses and strings must be passed as pure values (`ptb.pure.address()`, `ptb.pure.string()`), not as object references

## Running Integration Tests

Integration tests should only be run on **devnet** or **localnet**. Do not run `.ts` tests on testnet — testnet deployments are persistent and shared across environments. Running tests on testnet would deploy new packages on every run, polluting the shared state and wasting gas.

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

## Adding View Functions

When adding new view functions that use `buildGetPTB`, you **must** specify explicit `argTypes` for all arguments. The `argTypes` parameter is required to prevent addresses from being misinterpreted as object references by the gRPC transport.

```typescript
// Correct - explicit arg types
const ptb = this.buildGetPTB('get_role', [owner], [MoveType.address])

Common type mappings:
- Wallet/owner addresses: `MoveType.address`
- Investor IDs, country codes: `MoveType.string`
- Numeric values: `MoveType.u64`
- On-chain objects (auth, treasury, etc.): `MoveType.object`
