//! WebIDL typedef: ArrayBufferOrJsonWebKey
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");
const dictionaries = @import("dictionaries");

pub const ArrayBufferOrJsonWebKey = union(enum) {
    array_buffer: runtime.JSValue,
    json_web_key: dictionaries.JsonWebKey,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "array_buffer", .kind = .array_buffer },
        .{ .field = "json_web_key", .kind = .dictionary },
    };
};
