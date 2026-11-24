//! WebIDL typedef: NDEFMessageSource
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");
const dictionaries = @import("dictionaries");

pub const NDEFMessageSource = union(enum) {
    domstring: runtime.DOMString,
    buffer_source: typedefs.BufferSource,
    ndefmessage_init: dictionaries.NDEFMessageInit,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "domstring", .kind = .string },
        .{ .field = "buffer_source", .kind = .buffer_source },
        .{ .field = "ndefmessage_init", .kind = .dictionary },
    };
};
