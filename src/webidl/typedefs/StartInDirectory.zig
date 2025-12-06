//! WebIDL typedef: StartInDirectory
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const StartInDirectory = union(enum) {
    well_known_directory: enums.WellKnownDirectory,
    file_system_handle: *runtime.Instance,
};
