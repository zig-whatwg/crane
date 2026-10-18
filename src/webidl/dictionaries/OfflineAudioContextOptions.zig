//! WebIDL dictionary: OfflineAudioContextOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const OfflineAudioContextOptions = struct {
    numberOfChannels: ?u32 = null,
    length: ?u32 = null,
    sampleRate: f32,
    renderSizeHint: ?runtime.JSValue = null,

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{"sampleRate"};

    /// Inline union members typed runtime.JSValue: one present with the
    /// value null converts to `.null`, for the impl to convert by the union.
    pub const jsvalue_union_members = .{"renderSizeHint"};

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "numberOfChannels", .{ .number = 1 } },
        .{ "length", .null },
        .{ "renderSizeHint", .{ .string = "default" } },
    };

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{"length"};
};
