//! Auto-generated mixin: DocumentOrShadowRoot
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const DocumentOrShadowRootImpl = @import("impls").DocumentOrShadowRoot;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const Element = @import("interfaces").Element;
const StyleSheetList = @import("interfaces").StyleSheetList;
const CustomElementRegistry = @import("interfaces").CustomElementRegistry;
const CSSStyleSheet = @import("interfaces").CSSStyleSheet;
const Animation = @import("interfaces").Animation;

pub const impl = @import("impls").DocumentOrShadowRoot;

/// The impl's process-wide hooks, installed once at process start
/// (crane.Process, through the root's process_hooks).
pub fn installHooks() void {
    const impls = @import("impls");
    if (comptime @hasDecl(impls, "DocumentOrShadowRoot")) {
        if (comptime @hasDecl(impls.DocumentOrShadowRoot, "installHooks")) impls.DocumentOrShadowRoot.installHooks();
    }
}

pub fn get_customElementRegistry(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    return try DocumentOrShadowRootImpl.get_customElementRegistry(instance);
}

/// Extended attributes: [SameObject]
pub fn get_styleSheets(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return try DocumentOrShadowRootImpl.get_styleSheets(instance);
}

pub fn get_adoptedStyleSheets(instance: *runtime.Instance) anyerror!runtime.JSValue {
    return try DocumentOrShadowRootImpl.get_adoptedStyleSheets(instance);
}

pub fn set_adoptedStyleSheets(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
    try DocumentOrShadowRootImpl.set_adoptedStyleSheets(instance, value);
}

/// Extended attributes: [LegacyLenientSetter]
pub fn get_fullscreenElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    return try DocumentOrShadowRootImpl.get_fullscreenElement(instance);
}

/// Extended attributes: [LegacyLenientSetter]
pub fn set_fullscreenElement(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
    // [LegacyLenientSetter] - Silently do nothing (no-op setter)
    // Per WebIDL §4.3.10: The setter steps are to return.
    _ = instance;
    _ = value;
}

pub fn get_activeElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    return try DocumentOrShadowRootImpl.get_activeElement(instance);
}

pub fn get_pictureInPictureElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    return try DocumentOrShadowRootImpl.get_pictureInPictureElement(instance);
}

pub fn get_pointerLockElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    return try DocumentOrShadowRootImpl.get_pointerLockElement(instance);
}

pub fn call_getAnimations(instance: *runtime.Instance) anyerror!runtime.JSValue {
    return try DocumentOrShadowRootImpl.call_getAnimations(instance);
}
