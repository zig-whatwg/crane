//! WebIDL dictionary: ChapterInformationInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const MediaImage = @import("MediaImage.zig").MediaImage;

pub const ChapterInformationInit = struct {
    title: ?runtime.DOMString = null,
    startTime: ?f64 = null,
    artwork: ?[]const MediaImage = null,

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{"startTime"};
};
