//! WebIDL typedef: JsonLdRecordOrUSVString
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");

pub const JsonLdRecordOrUSVString = union(enum) {
    json_ld_record: typedefs.JsonLdRecord,
    usvstring: runtime.USVString,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "json_ld_record", .kind = .record },
        .{ .field = "usvstring", .kind = .string },
    };
};
