//! WebIDL dictionary: TableDescriptor
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const TableDescriptor = struct {
    element: *const anyopaque,
    initial: *const anyopaque,
    maximum: ?*const anyopaque = null,
    address: ?*const anyopaque = null,
};
