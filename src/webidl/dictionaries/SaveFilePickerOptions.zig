//! WebIDL dictionary: SaveFilePickerOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const FilePickerOptions = @import("FilePickerOptions.zig").FilePickerOptions;

pub const SaveFilePickerOptions = struct {
    // Inherited from FilePickerOptions
    base: FilePickerOptions,

    suggestedName: ?runtime.USVString = null,

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{"suggestedName"};
};
