//! WebIDL typedef: HTMLCollectionOrElement
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");

pub const HTMLCollectionOrElement = union(enum) {
    htmlcollection: *runtime.Instance,
    element: *runtime.Instance,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "htmlcollection", .kind = .{ .interface = "HTMLCollection" } },
        .{ .field = "element", .kind = .{ .interface = "Element" } },
    };
};
