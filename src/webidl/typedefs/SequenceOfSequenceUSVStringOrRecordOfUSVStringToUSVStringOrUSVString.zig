//! WebIDL typedef: SequenceOfSequenceUSVStringOrRecordOfUSVStringToUSVStringOrUSVString
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");

pub const SequenceOfSequenceUSVStringOrRecordOfUSVStringToUSVStringOrUSVString = union(enum) {
    sequence_usvstring_sequence: []const []const runtime.USVString,
    usvstring_usvstring_record: []const struct {
        pub const webidl_record_entry = true;
        key: runtime.USVString,
        value: runtime.USVString,
    },
    usvstring: runtime.USVString,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "sequence_usvstring_sequence", .kind = .{ .sequence = null } },
        .{ .field = "usvstring_usvstring_record", .kind = .record },
        .{ .field = "usvstring", .kind = .string },
    };
};
