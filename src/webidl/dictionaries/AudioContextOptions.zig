//! WebIDL dictionary: AudioContextOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");
const AudioSinkOptions = @import("AudioSinkOptions.zig").AudioSinkOptions;

pub const AudioContextOptions = struct {
    latencyHint: ?runtime.JSValue = null,
    sampleRate: ?f32 = null,
    sinkId: ?runtime.JSValue = null,
    renderSizeHint: ?runtime.JSValue = null,

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{"sampleRate"};

    /// Inline union members typed runtime.JSValue: one present with the
    /// value null converts to `.null`, for the impl to convert by the union.
    pub const jsvalue_union_members = .{ "latencyHint", "sinkId", "renderSizeHint" };

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "latencyHint", .{ .string = "interactive" } },
        .{ "renderSizeHint", .{ .string = "default" } },
    };
};
