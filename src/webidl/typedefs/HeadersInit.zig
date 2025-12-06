//! WebIDL typedef: HeadersInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const HeadersInit = union(enum) {
    sequence_byte_string_sequence: []const []const runtime.ByteString,
    byte_string_byte_string_record: []const struct { key: runtime.ByteString, value: runtime.ByteString },
};
