//! WebIDL dictionary: TranslatorCreateOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const callbacks = @import("callbacks");
const TranslatorCreateCoreOptions = @import("TranslatorCreateCoreOptions.zig").TranslatorCreateCoreOptions;

pub const TranslatorCreateOptions = struct {
    // Inherited from TranslatorCreateCoreOptions
    base: TranslatorCreateCoreOptions,

    signal: ?*runtime.Instance = null,
    monitor: ?callbacks.CreateMonitorCallback = null,
};
