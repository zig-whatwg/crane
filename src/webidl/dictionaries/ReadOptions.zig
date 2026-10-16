//! WebIDL dictionary: ReadOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const GeolocationSensorOptions = @import("GeolocationSensorOptions.zig").GeolocationSensorOptions;

pub const ReadOptions = struct {
    // Inherited from GeolocationSensorOptions
    base: GeolocationSensorOptions,

    signal: ?*runtime.Instance = null,

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{"signal"};
};
