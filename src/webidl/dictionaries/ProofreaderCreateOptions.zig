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
};
