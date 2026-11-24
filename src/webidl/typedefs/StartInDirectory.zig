//! WebIDL typedef: StartInDirectory
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const enums = @import("enums");

pub const StartInDirectory = union(enum) {
    well_known_directory: enums.WellKnownDirectory,
    file_system_handle: *runtime.Instance,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "well_known_directory", .kind = .enumeration },
        .{ .field = "file_system_handle", .kind = .{ .interface = "FileSystemHandle" } },
    };
};
