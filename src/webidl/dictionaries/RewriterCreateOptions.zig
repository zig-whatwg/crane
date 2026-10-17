//! WebIDL dictionary: RewriterCreateOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const callbacks = @import("callbacks");
const RewriterCreateCoreOptions = @import("RewriterCreateCoreOptions.zig").RewriterCreateCoreOptions;

pub const RewriterCreateOptions = struct {
    // Inherited from RewriterCreateCoreOptions
    base: RewriterCreateCoreOptions,

    signal: ?*runtime.Instance = null,
    monitor: ?callbacks.CreateMonitorCallback = null,
    sharedContext: ?runtime.DOMString = null,

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "signal", "AbortSignal" },
    };
};
