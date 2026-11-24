//! WebIDL typedef: GeometryNode
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");

pub const GeometryNode = union(enum) {
    text: *runtime.Instance,
    element: *runtime.Instance,
    csspseudo_element: *runtime.Instance,
    document: *runtime.Instance,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "text", .kind = .{ .interface = "Text" } },
        .{ .field = "element", .kind = .{ .interface = "Element" } },
        .{ .field = "csspseudo_element", .kind = .{ .interface = "CSSPseudoElement" } },
        .{ .field = "document", .kind = .{ .interface = "Document" } },
    };
};
