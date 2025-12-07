//! WebIDL dictionary: ShareData
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");

pub const ShareData = struct {
    files: ?[]const *runtime.Instance = null,
    title: ?runtime.USVString = null,
    text: ?runtime.USVString = null,
    url: ?runtime.USVString = null,
};
