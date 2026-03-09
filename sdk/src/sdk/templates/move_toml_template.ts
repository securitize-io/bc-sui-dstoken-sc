export const MOVE_TOML = `
[package]
name = "{MODULE}"
edition = "2024"

[dependencies]
securitize = { git = "git@github.com:securitize-io/bc-sui-dstoken-sc.git", subdir = "move/securitize", rev = "deployment-tests"  }
pas = { git = "git@github.com:chariskms/pas-test.git", subdir = "packages/pas", rev = "main" }

[environments]
{TESTNET_ENV} = "4c78adac"

[dep-replacements.{TESTNET_ENV}]
securitize = { use-environment = "{TESTNET_ENV}" }
pas = { use-environment = "testnet" }
`
