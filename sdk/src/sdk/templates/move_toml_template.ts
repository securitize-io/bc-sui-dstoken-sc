export const MOVE_TOML = `
[package]
name = "{MODULE}"
edition = "2024"

[dependencies]
securitize = { git = "git@github.com:securitize-io/bc-sui-dstoken-sc.git", subdir = "move/securitize", rev = "deployment-tests"  }
pas = { git = "git@github.com:MystenLabs/pas.git", subdir = "packages/pas", rev = "main" }

[dep-replacements.testnet]
securitize = { use-environment = "{TESTNET_ENV}" }
`
