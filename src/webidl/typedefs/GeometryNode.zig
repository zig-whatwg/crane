//! WebIDL typedef: GeometryNode
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");

pub const GeometryNode = union(enum) {
    text: *runtime.Instance,
    element: *runtime.Instance,
    csspseudo_element: *runtime.Instance,
    document: *runtime.Instance,
};
