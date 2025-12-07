//! WebIDL dictionary: DirectoryPickerOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const enums = @import("enums");

pub const DirectoryPickerOptions = struct {
    id: ?runtime.DOMString = null,
    startIn: ?typedefs.StartInDirectory = null,
    mode: ?enums.FileSystemPermissionMode = null,
};
