//! WebIDL typedef: JsonLdInput
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");

pub const JsonLdInput = union(enum) {
    json_ld_record: typedefs.JsonLdRecord,
    json_ld_record_sequence: []const typedefs.JsonLdRecord,
    usvstring: runtime.USVString,
    remote_document: *runtime.Instance,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "json_ld_record", .kind = .record },
        .{ .field = "json_ld_record_sequence", .kind = .{ .sequence = null } },
        .{ .field = "usvstring", .kind = .string },
        .{ .field = "remote_document", .kind = .{ .interface = "RemoteDocument" } },
    };
};
