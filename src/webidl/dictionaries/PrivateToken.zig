//! WebIDL dictionary: PrivateToken
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const PrivateToken = struct {
    version: anyopaque,
    operation: anyopaque,
    refreshPolicy: ?anyopaque = null,
    issuers: ?anyopaque = null,
};
