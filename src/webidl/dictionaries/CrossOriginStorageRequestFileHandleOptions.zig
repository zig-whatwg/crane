//! WebIDL dictionary: CrossOriginStorageRequestFileHandleOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const CrossOriginStorageRequestFileHandleOptions = struct {
    create: ?bool = null,
    origins: ?runtime.JSValue = null,

    /// Inline union members typed runtime.JSValue: one present with the
    /// value null converts to `.null`, for the impl to convert by the union.
    pub const jsvalue_union_members = .{"origins"};

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "create", .{ .boolean = false } },
    };
};
