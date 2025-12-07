//! WebIDL dictionary: MediaMetadataInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const ChapterInformationInit = @import("ChapterInformationInit.zig").ChapterInformationInit;
const MediaImage = @import("MediaImage.zig").MediaImage;

pub const MediaMetadataInit = struct {
    title: ?runtime.DOMString = null,
    artist: ?runtime.DOMString = null,
    album: ?runtime.DOMString = null,
    artwork: ?[]const MediaImage = null,
    chapterInfo: ?[]const ChapterInformationInit = null,
};
