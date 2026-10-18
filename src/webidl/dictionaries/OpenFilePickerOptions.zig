//! WebIDL dictionary: OpenFilePickerOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const FilePickerOptions = @import("FilePickerOptions.zig").FilePickerOptions;

pub const OpenFilePickerOptions = struct {
    // Inherited from FilePickerOptions
    base: FilePickerOptions,

    multiple: ?bool = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "multiple", .{ .boolean = false } },
    };
};
