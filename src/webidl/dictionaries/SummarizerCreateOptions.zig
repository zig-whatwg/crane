//! WebIDL dictionary: SummarizerCreateOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const callbacks = @import("callbacks");
const SummarizerCreateCoreOptions = @import("SummarizerCreateCoreOptions.zig").SummarizerCreateCoreOptions;

pub const SummarizerCreateOptions = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    // Inherited from SummarizerCreateCoreOptions
    base: SummarizerCreateCoreOptions,

    signal: ?*runtime.Instance = null,
    monitor: ?callbacks.CreateMonitorCallback = null,
    sharedContext: ?runtime.DOMString = null,

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "signal", "AbortSignal" },
    };
};
