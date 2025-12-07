//! WebIDL dictionary: LanguageDetectorCreateOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const callbacks = @import("callbacks");
const LanguageDetectorCreateCoreOptions = @import("LanguageDetectorCreateCoreOptions.zig").LanguageDetectorCreateCoreOptions;

pub const LanguageDetectorCreateOptions = struct {
    // Inherited from LanguageDetectorCreateCoreOptions
    base: LanguageDetectorCreateCoreOptions,

    signal: ?*runtime.Instance = null,
    monitor: ?callbacks.CreateMonitorCallback = null,
};
