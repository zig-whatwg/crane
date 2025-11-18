//! WebIDL dictionary: SaveFilePickerOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const FilePickerOptions = @import("FilePickerOptions.zig").FilePickerOptions;

pub const SaveFilePickerOptions = struct {
    // Inherited from FilePickerOptions
    base: FilePickerOptions,

    suggestedName: ?anyopaque = null,
};
