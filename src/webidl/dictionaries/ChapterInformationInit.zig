//! WebIDL dictionary: ChapterInformationInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const MediaImage = @import("MediaImage.zig").MediaImage;

pub const ChapterInformationInit = struct {
    title: ?runtime.DOMString = null,
    startTime: ?f64 = null,
    artwork: ?[]const MediaImage = null,
};
