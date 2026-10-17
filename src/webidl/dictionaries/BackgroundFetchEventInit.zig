//! WebIDL dictionary: BackgroundFetchEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const ExtendableEventInit = @import("ExtendableEventInit.zig").ExtendableEventInit;

pub const BackgroundFetchEventInit = struct {
    // Inherited from ExtendableEventInit
    base: ExtendableEventInit,

    registration: *runtime.Instance,

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "registration", "BackgroundFetchRegistration" },
    };
};
