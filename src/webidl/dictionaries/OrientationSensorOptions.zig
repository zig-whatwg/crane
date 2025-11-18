//! WebIDL dictionary: OrientationSensorOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const SensorOptions = @import("SensorOptions.zig").SensorOptions;

pub const OrientationSensorOptions = struct {
    // Inherited from SensorOptions
    base: SensorOptions,

    referenceFrame: ?anyopaque = null,
};
