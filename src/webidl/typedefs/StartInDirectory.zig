//! WebIDL typedef: StartInDirectory
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");

pub const StartInDirectory = union(enum) {
    well_known_directory: enums.WellKnownDirectory,
    file_system_handle: *runtime.Instance,
};
