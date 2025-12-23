//! Auto-generated mixin: CanvasSettings
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const CanvasSettingsImpl = @import("impls").CanvasSettings;

// Re-export types from impl
pub const impl = @import("impls").CanvasSettings;

pub fn call_getContextAttributes(instance: *runtime.Instance) anyerror!dictionaries.CanvasRenderingContext2DSettings {
    return CanvasSettingsImpl.call_getContextAttributes(instance);
}

