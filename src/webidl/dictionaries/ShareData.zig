//! WebIDL dictionary: ShareData
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const ShareData = struct {
    files: ?*const anyopaque = null,
    title: ?runtime.USVString = null,
    text: ?runtime.USVString = null,
    url: ?runtime.USVString = null,
};
