//! WebIDL dictionary: FunctionParameter
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const FunctionParameter = struct {
    name: *const anyopaque,
    type: *const anyopaque,
    defaultValue: ?*const anyopaque = null,
};
