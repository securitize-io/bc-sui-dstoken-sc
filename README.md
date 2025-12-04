# Securitize

This is the internal repository to design the contracts for the **Securitize RWA platform**. 

## Prerequisites

1. Use the correct node version in [.nvmrc](.nvmrc):

```bash
nvm use
```

1. Install the [sui cli](https://docs.sui.io/guides/developer/getting-started/sui-install)
2. Install the [MVR cli](https://docs.suins.io/move-registry/tooling/mvr-cli)

## Project Structure

This project is a monorepo utilizing [pnpm workspaces](https://pnpm.io/workspaces)

The project is comprised by 2 main folders:

1. [move](move): This folder holds all the Move on chain contracts and packages
2. [sdk](sdk): This folder holds a typescript SDK to call the contracts and E2E tests

## Executing tests

To execute all tests for all codebases, dapp, move, sdk run:

```bash
pnpm test
```

To execute a specific codebase test run:

```bash
pnpm --filter move test
```

For test coverage run:
```bash
pnpm coverage
```

## Linting the codebase

To check the code format for all codebases, dapp, move, sdk run:

```bash
pnpm lint
```

To fix the code format all for codebases, dapp, move, sdk run:

```bash
pnpm fix
```

## Configuration

Configure all the correct variables in the `.env` file

```bash
cp .env.example .env
```

1. `COST_ANALYZER_ENABLED` if the cost analyzer should be enabled or not, check details below.
1. `ADMIN_PRIVATE_KEY` the private key of the wallet you want to deploy the contract with


## Execution

### For localnet execution:

Start localnet sui chain and get some sui:
```bash
pnpm start_localnet
```
```bash
pnpm faucet
```

View your localnet on [suiscan](https://custom.suiscan.xyz/custom/home?network=http%3A%2F%2Flocalhost%3A9000)

Deploy the contracts to localnet:

```bash
pnpm faucet
```