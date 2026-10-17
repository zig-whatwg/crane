//! WebIDL dictionary: TranslatorCreateOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const callbacks = @import("callbacks");
const TranslatorCreateCoreOptions = @import("TranslatorCreateCoreOptions.zig").TranslatorCreateCoreOptions;

pub const TranslatorCreateOptions = struct {
    // Inherited from TranslatorCreateCoreOptions
    base: TranslatorCreateCoreOptions,

    signal: ?*runtime.Instance = null,
    monitor: ?callbacks.CreateMonitorCallback = null,

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "signal", "AbortSignal" },
    };
};
