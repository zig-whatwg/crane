//! WebIDL dictionary: SmartCardConnectResult
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const SmartCardConnectResult = struct {
    connection: *runtime.Instance,
    activeProtocol: ?enums.SmartCardProtocol = null,

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "connection", "SmartCardConnection" },
    };
};
