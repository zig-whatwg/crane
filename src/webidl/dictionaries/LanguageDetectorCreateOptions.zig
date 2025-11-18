//! WebIDL dictionary: LanguageDetectorCreateOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const LanguageDetectorCreateCoreOptions = @import("LanguageDetectorCreateCoreOptions.zig").LanguageDetectorCreateCoreOptions;

pub const LanguageDetectorCreateOptions = struct {
    // Inherited from LanguageDetectorCreateCoreOptions
    base: LanguageDetectorCreateCoreOptions,

    signal: ?anyopaque = null,
    monitor: ?anyopaque = null,
};
