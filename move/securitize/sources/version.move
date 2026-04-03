/// Module: version
///
/// Manages package versioning to ensure users interact with the latest contract version.
/// Provides version validation and migration support for package upgrades.
module securitize::version;

use sui::package::Publisher;

/// Shared object with `version` which updates on every upgrade.
/// Used as input to force the end-user to use the latest contract version.
public struct Version has key {
    id: UID,
    version: u64,
}

#[error(code = 0)]
const EInvalidPackageVersion: vector<u8> =
    b"Invalid package version - please use the latest version";

const VERSION: u64 = 1;

fun init(ctx: &mut TxContext) {
    transfer::share_object(Version { id: object::new(ctx), version: VERSION })
}

/// Function checking that the package-version matches the `Version` object.
///
/// # Aborts
/// * `EInvalidPackageVersion` - If the package version does not match the Version object
public fun check_is_valid(self: &Version) {
    assert!(self.version == VERSION, EInvalidPackageVersion);
}

public(package) fun migrate(version: &mut Version) {
    version.version = VERSION;
}

#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx);
}

#[test_only]
public fun set_version_for_testing(self: &mut Version, new_version: u64) {
    self.version = new_version;
}
