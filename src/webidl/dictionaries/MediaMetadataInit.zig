//! WebIDL dictionary: MediaMetadataInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const ChapterInformationInit = @import("ChapterInformationInit.zig").ChapterInformationInit;
const MediaImage = @import("MediaImage.zig").MediaImage;

pub const MediaMetadataInit = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    title: ?runtime.DOMString = null,
    artist: ?runtime.DOMString = null,
    album: ?runtime.DOMString = null,
    artwork: ?[]const MediaImage = null,
    chapterInfo: ?[]const ChapterInformationInit = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "title", .{ .string = "" } },
        .{ "artist", .{ .string = "" } },
        .{ "album", .{ .string = "" } },
        .{ "artwork", .empty_sequence },
        .{ "chapterInfo", .empty_sequence },
    };
};
