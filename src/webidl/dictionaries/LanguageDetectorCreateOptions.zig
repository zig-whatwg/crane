//! WebIDL dictionary: LanguageDetectorCreateOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const callbacks = @import("callbacks");
const LanguageDetectorCreateCoreOptions = @import("LanguageDetectorCreateCoreOptions.zig").LanguageDetectorCreateCoreOptions;

pub const LanguageDetectorCreateOptions = struct {
    // Inherited from LanguageDetectorCreateCoreOptions
    base: LanguageDetectorCreateCoreOptions,

    signal: ?*runtime.Instance = null,
    monitor: ?callbacks.CreateMonitorCallback = null,

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "signal", "AbortSignal" },
    };
};
