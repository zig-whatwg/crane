//! Auto-generated mixin: CanvasSettings
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CanvasSettingsImpl = @import("impls").CanvasSettings;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const CanvasRenderingContext2DSettings = @import("dictionaries").CanvasRenderingContext2DSettings;

pub const impl = @import("impls").CanvasSettings;

/// The impl's process-wide hooks, installed once at process start
/// (crane.Process, through the root's process_hooks).
pub fn installHooks() void {
    const impls = @import("impls");
    if (comptime @hasDecl(impls, "CanvasSettings")) {
        if (comptime @hasDecl(impls.CanvasSettings, "installHooks")) impls.CanvasSettings.installHooks();
    }
}

pub fn call_getContextAttributes(instance: *runtime.Instance) anyerror!CanvasRenderingContext2DSettings {
    return try CanvasSettingsImpl.call_getContextAttributes(instance);
}
