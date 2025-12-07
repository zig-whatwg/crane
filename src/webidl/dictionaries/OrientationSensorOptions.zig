//! WebIDL dictionary: OrientationSensorOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const enums = @import("enums");
const SensorOptions = @import("SensorOptions.zig").SensorOptions;

pub const OrientationSensorOptions = struct {
    // Inherited from SensorOptions
    base: SensorOptions,

    referenceFrame: ?enums.OrientationSensorLocalCoordinateSystem = null,
};
