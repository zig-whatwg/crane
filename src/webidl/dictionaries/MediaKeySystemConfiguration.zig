//! WebIDL dictionary: MediaKeySystemConfiguration
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");
const MediaKeySystemMediaCapability = @import("MediaKeySystemMediaCapability.zig").MediaKeySystemMediaCapability;

pub const MediaKeySystemConfiguration = struct {
    label: ?runtime.DOMString = null,
    initDataTypes: ?[]const runtime.DOMString = null,
    audioCapabilities: ?[]const MediaKeySystemMediaCapability = null,
    videoCapabilities: ?[]const MediaKeySystemMediaCapability = null,
    distinctiveIdentifier: ?enums.MediaKeysRequirement = null,
    persistentState: ?enums.MediaKeysRequirement = null,
    sessionTypes: ?[]const runtime.DOMString = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "label", .{ .string = "" } },
        .{ "initDataTypes", .empty_sequence },
        .{ "audioCapabilities", .empty_sequence },
        .{ "videoCapabilities", .empty_sequence },
        .{ "distinctiveIdentifier", .{ .string = "optional" } },
        .{ "persistentState", .{ .string = "optional" } },
    };
};
