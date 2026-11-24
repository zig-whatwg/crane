//! WebIDL typedef: JsonLdContext
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");

pub const JsonLdContext = union(enum) {
    json_ld_record: typedefs.JsonLdRecord,
    json_ld_record_or_usvstring_sequence: []const runtime.JSValue,
    usvstring: runtime.USVString,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "json_ld_record", .kind = .record },
        .{ .field = "json_ld_record_or_usvstring_sequence", .kind = .sequence },
        .{ .field = "usvstring", .kind = .string },
    };
};
