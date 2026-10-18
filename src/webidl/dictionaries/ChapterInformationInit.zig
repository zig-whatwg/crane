//! WebIDL dictionary: ChapterInformationInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const MediaImage = @import("MediaImage.zig").MediaImage;

pub const ChapterInformationInit = struct {
    title: ?runtime.DOMString = null,
    startTime: ?f64 = null,
    artwork: ?[]const MediaImage = null,

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{"startTime"};

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "title", .{ .string = "" } },
        .{ "startTime", .{ .number = 0 } },
        .{ "artwork", .empty_sequence },
    };
};
