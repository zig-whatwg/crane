//! WebIDL dictionary: PannerOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");
const AudioNodeOptions = @import("AudioNodeOptions.zig").AudioNodeOptions;

pub const PannerOptions = struct {
    // Inherited from AudioNodeOptions
    base: AudioNodeOptions,

    panningModel: ?enums.PanningModelType = null,
    distanceModel: ?enums.DistanceModelType = null,
    positionX: ?f32 = null,
    positionY: ?f32 = null,
    positionZ: ?f32 = null,
    orientationX: ?f32 = null,
    orientationY: ?f32 = null,
    orientationZ: ?f32 = null,
    refDistance: ?f64 = null,
    maxDistance: ?f64 = null,
    rolloffFactor: ?f64 = null,
    coneInnerAngle: ?f64 = null,
    coneOuterAngle: ?f64 = null,
    coneOuterGain: ?f64 = null,

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{ "positionX", "positionY", "positionZ", "orientationX", "orientationY", "orientationZ", "refDistance", "maxDistance", "rolloffFactor", "coneInnerAngle", "coneOuterAngle", "coneOuterGain" };

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "panningModel", .{ .string = "equalpower" } },
        .{ "distanceModel", .{ .string = "inverse" } },
        .{ "positionX", .{ .number = 0 } },
        .{ "positionY", .{ .number = 0 } },
        .{ "positionZ", .{ .number = 0 } },
        .{ "orientationX", .{ .number = 1 } },
        .{ "orientationY", .{ .number = 0 } },
        .{ "orientationZ", .{ .number = 0 } },
        .{ "refDistance", .{ .number = 1 } },
        .{ "maxDistance", .{ .number = 10000 } },
        .{ "rolloffFactor", .{ .number = 1 } },
        .{ "coneInnerAngle", .{ .number = 360 } },
        .{ "coneOuterAngle", .{ .number = 360 } },
        .{ "coneOuterGain", .{ .number = 0 } },
    };
};
