//! WebIDL typedef: ElementOrDocument
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");

pub const ElementOrDocument = union(enum) {
    element: *runtime.Instance,
    document: *runtime.Instance,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "element", .kind = .{ .interface = "Element" } },
        .{ .field = "document", .kind = .{ .interface = "Document" } },
    };
};
