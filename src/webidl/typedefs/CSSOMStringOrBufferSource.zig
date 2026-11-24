//! WebIDL typedef: CSSOMStringOrBufferSource
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");

pub const CSSOMStringOrBufferSource = union(enum) {
    cssomstring: typedefs.CSSOMString,
    buffer_source: typedefs.BufferSource,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "cssomstring", .kind = .string },
        .{ .field = "buffer_source", .kind = .buffer_source },
    };
};
