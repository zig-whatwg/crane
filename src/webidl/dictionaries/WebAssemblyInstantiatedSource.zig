//! WebIDL dictionary: WebAssemblyInstantiatedSource
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const WebAssemblyInstantiatedSource = struct {
    module: *runtime.Instance,
    instance: *runtime.Instance,

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "module", "Module" },
        .{ "instance", "Instance" },
    };
};
