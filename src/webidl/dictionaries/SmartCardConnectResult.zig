//! WebIDL dictionary: SmartCardConnectResult
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const SmartCardConnectResult = struct {
    connection: *runtime.Instance,
    activeProtocol: ?enums.SmartCardProtocol = null,
};
