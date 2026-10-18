//! WebIDL dictionary: AccelerometerSensorOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");
const SensorOptions = @import("SensorOptions.zig").SensorOptions;

pub const AccelerometerSensorOptions = struct {
    // Inherited from SensorOptions
    base: SensorOptions,

    referenceFrame: ?enums.AccelerometerLocalCoordinateSystem = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "referenceFrame", .{ .string = "device" } },
    };
};
