# Permissioned Token Standard

## Overview

The Permissioned Token Standard is a comprehensive framework for managing compliant tokenized assets on Sui. Built around a secure vault-based architecture, it enables issuers to enforce regulatory controls, transfer restrictions, and compliance mechanisms directly at the protocol level, ensuring that tokenized assets meet jurisdictional requirements without sacrificing composability.

## Key Innovations

- **Vault-based ownership**: Tokens reside in user-specific `Vault` objects (derived from registry + address), providing clear on-chain ownership while enabling sophisticated balance management. 
**Benefit**: Vaults are fully discoverable on-chain, allowing anyone to query user holdings, track asset distribution, and build transparent analytics.

- **Programmable compliance**: Issuers define a `Rule` with authorization witness that validates all token operations (transfers, mints, burns, clawbacks) against business logic. 
**Benefit**: Issuers can enforce their own custom compliance policies (KYC requirements, jurisdictional restrictions, transfer limits, accreditation checks) built directly into the framework, ensuring regulatory requirements are met at the protocol level rather than through external enforcement.

## How the Standard Works

The standard operates in two distinct modes depending on how the issuer chooses to manage the `TreasuryCap<T>`:

### Setup: Creating the Rule

Every token type must first establish a `Rule<T>` derived from `(registry.id, TypeName<T>)`. The rule stores:
- The **authorization witness** `TypeName` used to validate all operations through the issuer's compliance contract
- The **clawback configuration** (immutable after creation)
- Optionally, the **locked `TreasuryCap<T>`** as a dynamic object field

### Mode 1: Locked TreasuryCap (Fully Managed)

When the `TreasuryCap<T>` is permanently locked inside the `Rule<T>` using `rule::new_with_treasury()`, all token operations remain within the framework:

**Balance flow:**
- **Mint**: Tokens are minted directly into vaults via `rule::mint()` or `rule::mint_to_vault()` - balances never exist outside the vault system
- **Burn**: Tokens are burned directly from vaults via `rule::burn_from_vault()` using vault owner authorization
- **Clawback**: Extracted balances are by default deposited to another vault via `rule::clawback_to_vault()`
- **Transfer**: Vault-to-vault transfers via `vault::transfer_to_vault()` keep balances entirely within the framework

**Key characteristic:** Balances are created and destroyed within vaults - no `Balance<T>` objects ever leave the vault ecosystem.

### Mode 2: Issuer-Managed TreasuryCap (Flexible)

When the issuer retains the `TreasuryCap<T>` using `rule::new()`, they manage minting externally and deposit balances into the framework:

**Balance flow:**
- **Mint**: Issuer mints `Balance<T>` externally using their `TreasuryCap<T>`, then deposits via `rule::deposit()` or `rule::deposit_to_vault()`
- **Unlock**: Balances can be extracted from vaults via `rule::unlock_from_vault()` with owner authorization, returning `Balance<T>` for external use
- **Clawback**: Returns `Balance<T>` via `rule::clawback()` that can be used outside the framework
- **Transfer**: Same vault-to-vault transfers as Mode 1

**Key characteristic:** Balances can flow in and out of the framework, enabling hybrid integration with existing DeFi or issuer-managed systems.

### Witness Enforcement: Issuer Control

**Critical:** All operations (`mint`, `burn`, `deposit`, `unlock`, `clawback`, `resolve_transfer`) require the authorization witness defined in the rule. This means:

1. Operations can **only be called from within the issuer's compliance contract** that possesses the witness type
2. The issuer's contract implements custom validation logic (whitelists, limits, KYC checks, etc.)
3. All compliance rules are enforced before the standard's functions execute

### Transfer Flow

Regardless of mode, all vault-to-vault transfers follow the same pattern:

1. **Initiate**: `vault::transfer()` or `vault::transfer_to_vault()` creates an `TransferRequest<T>` hot potato
2. **Validate**: The request must be passed to the issuer's compliance contract
3. **Resolve**: The issuer's contract calls `rule::resolve_transfer()` with their authorization witness after validating compliance rules
4. **Complete**: The hot potato is consumed, finalizing the transfer

This design ensures **every transfer must pass through issuer-defined compliance logic** before completion.

## Architecture Overview

The standard is built on three fundamental components that work together to enforce compliant token transfers while maintaining composability:

### Core Components

#### 1. Registry
The central coordination point for the entire framework, deployed as a shared object during initialization. The `Registry` serves as the namespace root from which all vaults and rules are deterministically derived using Sui's `derived_object` pattern. This design ensures:

- **Predictable addressing**: Any participant can calculate the address of a vault or rule without on-chain lookups
- **No collision risk**: Derived objects are unique per (registry.id, key) pair
- **Discoverability**: All vaults and rules for a given registry can be queried and discovered on-chain


#### 2. Vault
Personal token custody containers where user balances are stored. Each vault is uniquely derived from the registry and an owner identifier, supporting both address-based ownership (`Owner::Address`) and object-based ownership (`Owner::Object`).

**Architecture details:**
- **Shared objects**: Vaults are shared by default, enabling issuer control.
- **Multi-token support**: A single vault can hold multiple token types as separate `Balance<T>`.

#### 3. Rule
Token-specific compliance enforcement module that defines operational rules and authorization requirements. Each token type has exactly one rule, derived from `(registry.id, TypeName)` and deployed as a shared object.

**Architecture details:**
- **Authorization witness**: Stores the `TypeName` of a custom witness type that must be provided to validate all operations
- **Witness pattern enforcement**: All critical functions (mint, burn, transfer, clawback) require the authorization witness, ensuring operations flow through the issuer's compliance contract
- **Clawback capability**: Configurable at creation (immutable thereafter) - when enabled, allows forcible withdrawal from vaults without owner authorization
- **Treasury options**: Rules can be created with or without locking the `TreasuryCap<T>` inside as a dynamic object field

## Features

### **Unclawbackable Vaults**

Vaults include a mechanism for permanently disabling clawback on a per-vault basis for a specific Permissioned type. Each Vault can be attached a ClawbacksDisabled<T> (always with a boolean true as the value) dynamic field, and all clawback operations MUST check that ClawbacksDisabled<T> does not exist in the vault in order to proceed, using is_clawback_enabled<T>(vault): bool, which checks the existence of the key.

Issuers may call a one-way function disable_clawback() using their authorization witness, which permanently attaches the DF to the Vault for type T. This action is irreversible.

**Rationale:**
This feature allows issuers to exempt specific vaults from clawback when the global clawback capability is considered too broad. It guarantees to vault owners that, once certain issuer-defined criteria are met, a vault becomes permanently immune to clawback actions for type T.

### **Unlock Non-Permissioned Funds from a Vault**

Vaults may receive `Balance<T>` objects that are not governed by any Permissioned rule object. If the Vault receives an asset type `T` for which no `Rule<T>` exists, the vault owner is permitted to unlock and withdraw these funds.

Rule existence is checked via:

```move
derived_object::exists(registry.uid_mut(), RuleKey<T>())
```

If no rule object exists for `T`, the asset is classified as non-Permissioned, and the owner may withdraw it.
The only required authentication for this operation is possession of the `VaultOwnerProof`.

**Rationale:**
This prevents non-Permissioned funds from becoming stuck inside vaults.

### **MoveCommand for Off-Chain Action Resolution**

The standard introduces the `MoveCommand` abstraction to embed resolution metadata directly in each `Rule`. For every supported action type, the rule stores a `MoveCommand` describing the validation function that must be called before executing the resolve step. 

`MoveCommand` structure includes:
* contract address (static or MVR),
* module and function names,
* type arguments,
* supported argument types (shared refs, mutable shared refs, immutable refs, typed payments, and standard placeholders such as sender vault, receiver vault, rule, and transfer request).

Each token-specific rule exposes:

```move
resolution_info: VecMap<TypeName, MoveCommand>,
```

mapping action types (e.g., `TransferRequest`) to their required validation commands.

**Rationale:**
This allows SDKs to determine and construct the correct validation call inside the PTB, enabling dynamic invocation without hard-coded contract logic.



