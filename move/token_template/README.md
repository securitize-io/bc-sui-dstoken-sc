# token_template

Placeholder Move package for the SDK's WASM-bytecode-template token deploy
flow. The compiled `.mv` is hex-encoded and embedded in
[`sdk/src/sdk/tokenTemplate/getBytecode.ts`](../../sdk/src/sdk/tokenTemplate/getBytecode.ts);
the SDK patches the `token_template` module identifier and the
`TOKEN_TEMPLATE` struct identifier per deploy via
`@mysten/move-bytecode-template`'s `update_identifiers`, then publishes the
patched bytecode directly — no `sui move build` is required at deploy time.

## Why these specific identifiers

- `token_template` (module) and `TOKEN_TEMPLATE` (struct) are the keys passed
  to `update_identifiers` in [`patchBytecode.ts`](../../sdk/src/sdk/tokenTemplate/patchBytecode.ts).
  They must match the names in the compiled bytecode exactly.
- The function signature of `create_ds_token` is identical to the legacy
  string-template version so the existing PTB in
  [`DeployDSToken.ts`](../../sdk/src/sdk/DeployDSToken.ts) keeps working
  unchanged after the identifier rename.

## Regenerating the embedded bytecode

Whenever this Move source changes, rebuild and re-paste the hex blob:

```bash
cd move/token_template
sui move build
xxd -p -c 100000 build/token_template/bytecode_modules/token_template.mv
```

Copy the single-line hex output into `BYTECODE_HEX` in
[`sdk/src/sdk/tokenTemplate/getBytecode.ts`](../../sdk/src/sdk/tokenTemplate/getBytecode.ts).
The hex blob is the source of truth at deploy time — the `.move` file is only
read at build time here.
