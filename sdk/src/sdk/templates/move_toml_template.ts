export const MOVE_TOML = `
[package]
name = "{MODULE}"
edition = "2024"

[dependencies]
securitize = { local = "{SECURITIZE_PACKAGE_PATH}" }
pas = { local = "{PAS_PACKAGE_PATH}" }
`