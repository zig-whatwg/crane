//! WebIDL dictionary: AudioOutputOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const AudioOutputOptions = struct {
    deviceId: ?runtime.DOMString = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "deviceId", .{ .string = "" } },
    };
};
