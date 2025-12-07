//! WebIDL dictionary: FilePickerOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const FilePickerAcceptType = @import("FilePickerAcceptType.zig").FilePickerAcceptType;

pub const FilePickerOptions = struct {
    types: ?[]const FilePickerAcceptType = null,
    excludeAcceptAllOption: ?bool = null,
    id: ?runtime.DOMString = null,
    startIn: ?typedefs.StartInDirectory = null,
};
