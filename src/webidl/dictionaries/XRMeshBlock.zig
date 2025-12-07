//! WebIDL dictionary: XRMeshBlock
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");

pub const XRMeshBlock = struct {
    vertices: *const anyopaque,
    indices: *const anyopaque,
    normals: ?*const anyopaque = null,
};
