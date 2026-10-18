//! WebIDL dictionary: LoadDocumentOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const LoadDocumentOptions = struct {
    extractAllScripts: ?bool = null,
    profile: ?runtime.USVString = null,
    requestProfile: ?runtime.JSValue = null,

    /// Inline union members typed runtime.JSValue: one present with the
    /// value null converts to `.null`, for the impl to convert by the union.
    pub const jsvalue_union_members = .{"requestProfile"};

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "extractAllScripts", .{ .boolean = false } },
        .{ "profile", .null },
        .{ "requestProfile", .null },
    };
};
