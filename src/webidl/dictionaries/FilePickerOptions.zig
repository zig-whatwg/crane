//! WebIDL dictionary: FilePickerOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const FilePickerAcceptType = @import("FilePickerAcceptType.zig").FilePickerAcceptType;

pub const FilePickerOptions = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    types: ?[]const FilePickerAcceptType = null,
    excludeAcceptAllOption: ?bool = null,
    id: ?runtime.DOMString = null,
    startIn: ?typedefs.StartInDirectory = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "excludeAcceptAllOption", .{ .boolean = false } },
    };
};
