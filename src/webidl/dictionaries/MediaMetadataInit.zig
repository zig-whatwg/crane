//! WebIDL dictionary: MediaMetadataInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const MediaMetadataInit = struct {
    title: ?runtime.DOMString = null,
    artist: ?runtime.DOMString = null,
    album: ?runtime.DOMString = null,
    artwork: ?anyopaque = null,
    chapterInfo: ?anyopaque = null,
};
