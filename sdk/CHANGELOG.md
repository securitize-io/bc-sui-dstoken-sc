# @securitize/sui-sdk

## 6.1.0

### Minor Changes

- Added the optional GRPC_AUTH_TOKEN environment variable to configure the Bearer header in gRPC connections.
- Use https to clone MystenLab repositories
- Add key pair on create token and use latest changes to use gRPC
- Support authenticated gRPC providers (e.g. Alchemy) via an optional GRPC_AUTH_TOKEN env var. When set, the SDK switches from the default grpc-web transport to the native gRPC transport (`@protobuf-ts/grpc-transport` + `@grpc/grpc-js`) and sends the token as an `Authorization: Bearer` gRPC metadata header — authenticated providers like Alchemy only expose native gRPC, not grpc-web.

### Patch Changes

- Fix publish testnet contracts

## 6.0.0

### Major Changes

- Upgrade to mainnet sui

### Minor Changes

- Use https to clone MystenLab repositories
- Add key pair on create token and use latest changes to use gRPC

### Patch Changes

- Fix publish testnet contracts

## 5.3.0

### Minor Changes

- Use https to clone MystenLab repositories
- Add key pair on create token and use latest changes to use gRPC

### Patch Changes

- Fix publish testnet contracts

## 5.2.0

### Minor Changes

- Use https to clone MystenLab repositories
- Add key pair on create token and use latest changes to use gRPC

## 5.1.0

### Minor Changes

- Use https to clone MystenLab repositories

## 5.0.0

### Major Changes

- The coin is seperated from the other pacakges on deployment

### Patch Changes

- Update the way to create dstoken address

## 4.0.0

### Major Changes

- The coin is seperated from the other pacakges on deployment

## 3.0.0

### Major Changes

- Publish latest version to allow publishing to allow testnet alpha, beta and gamma

### Patch Changes

- Fix PAS calls
- Latest version to publish
- Fixed SDK to return total balance of a single wallet
- Fixing issuance function
- Include console.log errors
- Fix to avoid derivated addresses in PTB
- Implement latest version
- Updated SDK to allow testnet deployment
- Include console.log on autodeployment feature
- Use latest main changes
- fixing roles
- Use latest main version

## 2.0.0

### Major Changes

- Publish latest version to allow publishing to allow testnet alpha, beta and gamma

### Patch Changes

- Latest version to publish
- Fixed SDK to return total balance of a single wallet
- Fixing issuance function
- Include console.log errors
- Fix to avoid derivated addresses in PTB
- Implement latest version
- Updated SDK to allow testnet deployment
- Include console.log on autodeployment feature
- Use latest main changes
- fixing roles
- Use latest main version

## 1.1.0

### Minor Changes

- This version include Investors, Rules, Roles and Wallets SDK.

## 1.0.7

### Patch Changes

- Move easysui inside the sdk
- rename easysui to securitize/easysui

## 1.0.6

### Patch Changes

- rename easysui to securitize/easysui
- Updated dependencies
    - @securitize/easysui@0.1.4

## 1.0.5

### Patch Changes

- rename easysui to securitize/easysui
- Updated dependencies
    - @securitize/easysui@0.1.3

## 1.0.4

### Patch Changes

- Fix build
- Use easysui using workspaces
- Make ADMIN_KEYPAIR optional
- Publish all
- Updated dependencies
    - @securitize/easysui@0.1.2

## 1.0.3

### Patch Changes

- Fix build
- Use easysui using workspaces
- Make ADMIN_KEYPAIR optional

## 1.0.2

### Patch Changes

- Use easysui using workspaces
- Make ADMIN_KEYPAIR optional

## 1.0.1

### Patch Changes

- Use easysui using workspaces

## 1.0.0

### Major Changes

- This is the first release of the SDK including the build tx bytes and execute from tx bytes
