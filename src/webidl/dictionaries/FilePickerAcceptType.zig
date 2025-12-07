//! WebIDL dictionary: FilePickerAcceptType
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const FilePickerAcceptType = struct {
    description: ?runtime.USVString = null,
    accept: ?[]const struct { key: runtime.USVString, value: *const anyopaque } = null,
};
