//! WebIDL dictionary: ProofreaderCreateOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const callbacks = @import("callbacks");
const ProofreaderCreateCoreOptions = @import("ProofreaderCreateCoreOptions.zig").ProofreaderCreateCoreOptions;

pub const ProofreaderCreateOptions = struct {
    // Inherited from ProofreaderCreateCoreOptions
    base: ProofreaderCreateCoreOptions,

    signal: ?*runtime.Instance = null,
    monitor: ?callbacks.CreateMonitorCallback = null,

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "signal", "AbortSignal" },
    };
};
