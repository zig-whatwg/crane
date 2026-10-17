//! WebIDL dictionary: LanguageModelCreateOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const LanguageModelMessage = @import("LanguageModelMessage.zig").LanguageModelMessage;
const callbacks = @import("callbacks");
const LanguageModelCreateCoreOptions = @import("LanguageModelCreateCoreOptions.zig").LanguageModelCreateCoreOptions;

pub const LanguageModelCreateOptions = struct {
    // Inherited from LanguageModelCreateCoreOptions
    base: LanguageModelCreateCoreOptions,

    signal: ?*runtime.Instance = null,
    monitor: ?callbacks.CreateMonitorCallback = null,
    initialPrompts: ?[]const LanguageModelMessage = null,

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "signal", "AbortSignal" },
    };
};
