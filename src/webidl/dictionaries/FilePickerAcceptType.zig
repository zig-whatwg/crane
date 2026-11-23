//! WebIDL dictionary: FilePickerAcceptType
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const FilePickerAcceptType = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    description: ?runtime.USVString = null,
    accept: ?[]const struct {
        pub const webidl_record_entry = true;
        key: runtime.USVString,
        value: runtime.JSValue,
    } = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "description", .{ .string = "" } },
    };
};
