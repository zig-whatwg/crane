//! WebIDL dictionary: TranslatorCreateOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const TranslatorCreateCoreOptions = @import("TranslatorCreateCoreOptions.zig").TranslatorCreateCoreOptions;

pub const TranslatorCreateOptions = struct {
    // Inherited from TranslatorCreateCoreOptions
    base: TranslatorCreateCoreOptions,

    signal: ?anyopaque = null,
    monitor: ?anyopaque = null,
};
