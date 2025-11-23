//! WebIDL dictionary: SmartCardConnectResult
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const SmartCardConnectResult = struct {
    connection: *const anyopaque,
    activeProtocol: ?*const anyopaque = null,
};
