//! WebIDL dictionary: MagnetometerSensorOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");
const SensorOptions = @import("SensorOptions.zig").SensorOptions;

pub const MagnetometerSensorOptions = struct {
    // Inherited from SensorOptions
    base: SensorOptions,

    referenceFrame: ?enums.MagnetometerLocalCoordinateSystem = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "referenceFrame", .{ .string = "device" } },
    };
};
