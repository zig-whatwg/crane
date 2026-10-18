//! WebIDL dictionary: StructuredSerializeOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const StructuredSerializeOptions = struct {
    transfer: ?[]const runtime.JSValue = null,

    /// WebIDL `object` members (or sequences of `object`): a value that is
    /// not an Object throws a TypeError when the dictionary is converted.
    pub const object_members = .{"transfer"};

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "transfer", .empty_sequence },
    };
};
