//! WebIDL dictionary: PrivateToken
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const PrivateToken = struct {
    version: *const anyopaque,
    operation: *const anyopaque,
    refreshPolicy: ?*const anyopaque = null,
    issuers: ?*const anyopaque = null,
};
