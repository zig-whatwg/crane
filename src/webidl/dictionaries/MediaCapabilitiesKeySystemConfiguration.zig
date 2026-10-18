//! WebIDL dictionary: MediaCapabilitiesKeySystemConfiguration
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");
const KeySystemTrackConfiguration = @import("KeySystemTrackConfiguration.zig").KeySystemTrackConfiguration;

pub const MediaCapabilitiesKeySystemConfiguration = struct {
    keySystem: runtime.DOMString,
    initDataType: ?runtime.DOMString = null,
    distinctiveIdentifier: ?enums.MediaKeysRequirement = null,
    persistentState: ?enums.MediaKeysRequirement = null,
    sessionTypes: ?[]const runtime.DOMString = null,
    audio: ?KeySystemTrackConfiguration = null,
    video: ?KeySystemTrackConfiguration = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "initDataType", .{ .string = "" } },
        .{ "distinctiveIdentifier", .{ .string = "optional" } },
        .{ "persistentState", .{ .string = "optional" } },
    };
};
