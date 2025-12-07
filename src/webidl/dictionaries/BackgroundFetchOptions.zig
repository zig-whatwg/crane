//! WebIDL dictionary: BackgroundFetchOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const BackgroundFetchUIOptions = @import("BackgroundFetchUIOptions.zig").BackgroundFetchUIOptions;

pub const BackgroundFetchOptions = struct {
    // Inherited from BackgroundFetchUIOptions
    base: BackgroundFetchUIOptions,

    downloadTotal: ?u64 = null,
};
