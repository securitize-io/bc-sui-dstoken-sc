# Steps to execute the integration tests

## First setup the sui local environment and test address
1. Run a localnet with 
```
sui start --with-faucet --force-regenesis
```
2. Switch to the localnet environment with 
```
sui client switch --env localnet
```
**If localnet is not defined, create it and then switch to localnet.**
```
sui client new-env --alias localnet --rpc http://127.0.0.1:9000
sui client switch --env localnet
```
3. Import an address that is created for testing purposes and is used within the contracts with 
```
sui keytool import --alias admin suiprivkey1qpq4r2l7kr3n5vrtt56qah5nj576hj6ppjexztq38x43n03cxjmhqp7rz6q ed25519
```
4. Switch to that address and get some sui tokens to publish the contracts and run the transactions 
```
sui client switch --address admin
sui client faucet
```

## Lastly create the env file and run the integration tests
1. Create the initial .env file with required variables
```
    touch .env
    echo "NETWORK=localnet" >> .env
    echo "ADMIN_PRIVATE_KEY=suiprivkey1qpq4r2l7kr3n5vrtt56qah5nj576hj6ppjexztq38x43n03cxjmhqp7rz6q" >> .env
    echo "FULLNODE_URL=http://127.0.0.1:9000" >> .env
```
2. Install the dependencies with 
```
pnpm install
```
3. Run publish test first 
```
pnpm test publish.test.ts
```

4. Then run all other tests
```
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
