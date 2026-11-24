//! WebIDL typedef: BufferSourceOrJsonWebKey
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");
const dictionaries = @import("dictionaries");

pub const BufferSourceOrJsonWebKey = union(enum) {
    buffer_source: typedefs.BufferSource,
    json_web_key: dictionaries.JsonWebKey,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "buffer_source", .kind = .buffer_source },
        .{ .field = "json_web_key", .kind = .dictionary },
    };
};
