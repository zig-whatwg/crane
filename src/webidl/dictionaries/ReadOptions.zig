//! WebIDL dictionary: ReadOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const GeolocationSensorOptions = @import("GeolocationSensorOptions.zig").GeolocationSensorOptions;

pub const ReadOptions = struct {
    // Inherited from GeolocationSensorOptions
    base: GeolocationSensorOptions,

    signal: ?*runtime.Instance = null,
};
