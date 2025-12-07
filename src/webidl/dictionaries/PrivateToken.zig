//! WebIDL dictionary: PrivateToken
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const enums = @import("enums");

pub const PrivateToken = struct {
    version: enums.TokenVersion,
    operation: enums.OperationType,
    refreshPolicy: ?enums.RefreshPolicy = null,
    issuers: ?[]const runtime.USVString = null,
};
