export const MOVE_TOML = `
[package]
name = "{MODULE}"
edition = "2024"

[dependencies]
securitize = { git = "git@github.com:chariskms/securitize-test.git", subdir = "packages/pas", rev = "main"  }
pas = { git = "git@github.com:chariskms/pas-test.git", subdir = "packages/pas", rev = "main" }

[dep-replacements.testnet]
securitize = { use-environment = {TESTNET_ENV} }
`