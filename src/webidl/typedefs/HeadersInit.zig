//! WebIDL typedef: HeadersInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");

pub const HeadersInit = union(enum) {
    sequence_byte_string_sequence: []const []const runtime.ByteString,
    byte_string_byte_string_record: []const struct {
        pub const webidl_record_entry = true;
        key: runtime.ByteString,
        value: runtime.ByteString,
    },

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "sequence_byte_string_sequence", .kind = .sequence },
        .{ .field = "byte_string_byte_string_record", .kind = .record },
    };
};
