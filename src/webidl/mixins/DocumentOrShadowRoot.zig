//! Auto-generated mixin: DocumentOrShadowRoot
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const DocumentOrShadowRootImpl = @import("impls").DocumentOrShadowRoot;

// Re-export types from impl
pub const impl = @import("impls").DocumentOrShadowRoot;

pub fn get_customElementRegistry(instance: *runtime.Instance) !?*runtime.Instance {
    return DocumentOrShadowRootImpl.get_customElementRegistry(instance);
}

pub fn get_fullscreenElement(instance: *runtime.Instance) !?*runtime.Instance {
    return DocumentOrShadowRootImpl.get_fullscreenElement(instance);
}

pub fn get_pictureInPictureElement(instance: *runtime.Instance) !?*runtime.Instance {
    return DocumentOrShadowRootImpl.get_pictureInPictureElement(instance);
}

pub fn get_pointerLockElement(instance: *runtime.Instance) !?*runtime.Instance {
    return DocumentOrShadowRootImpl.get_pointerLockElement(instance);
}

pub fn get_styleSheets(instance: *runtime.Instance) !*runtime.Instance {
    return DocumentOrShadowRootImpl.get_styleSheets(instance);
}

pub fn get_adoptedStyleSheets(instance: *runtime.Instance) anyerror!void {
    return DocumentOrShadowRootImpl.get_adoptedStyleSheets(instance);
}

pub fn set_adoptedStyleSheets(instance: *runtime.Instance, value: runtime.JSValue) !void {
    return DocumentOrShadowRootImpl.set_adoptedStyleSheets(instance, value);
}

pub fn get_activeElement(instance: *runtime.Instance) !?*runtime.Instance {
    return DocumentOrShadowRootImpl.get_activeElement(instance);
}

pub fn call_getAnimations(instance: *runtime.Instance) anyerror!void {
    return DocumentOrShadowRootImpl.call_getAnimations(instance);
}

