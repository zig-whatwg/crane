//! WebIDL typedef: DOMStringOrSharedWorkerOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");
const dictionaries = @import("dictionaries");

pub const DOMStringOrSharedWorkerOptions = union(enum) {
    domstring: runtime.DOMString,
    shared_worker_options: dictionaries.SharedWorkerOptions,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "domstring", .kind = .string },
        .{ .field = "shared_worker_options", .kind = .dictionary },
    };
};
