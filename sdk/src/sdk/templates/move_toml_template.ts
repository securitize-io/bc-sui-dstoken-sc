export const MOVE_TOML = `
[package]
name = "{MODULE}"
edition = "2024"

[dependencies]
securitize = { local = "{SECURITIZE_PACKAGE_PATH}" }
pas = { git = "git@github.com:MystenLabs/pas.git", subdir = "packages/pas", rev = "main" }
`