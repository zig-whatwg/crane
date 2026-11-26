//! Implementation for the DocumentOrShadowRoot mixin (DOM §4.2.5 / CSSOM /
//! Fullscreen / Pointer Lock / Picture-in-Picture / Web Animations / HTML):
//! activeElement, styleSheets, adoptedStyleSheets, fullscreenElement,
//! pictureInPictureElement, pointerLockElement, customElementRegistry, and
//! getAnimations(), shared by Document and ShadowRoot.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const html = @import("html");
const DocumentOrShadowRoot = interfaces.DocumentOrShadowRoot;

pub const State = DocumentOrShadowRoot.State;

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
};

pub const InternalState = struct {};

fn ensureInitialized(instance: *runtime.Instance) !void {
    if (dom.document_internals.getInternal(instance) != null) return;
    if (instance.stateAs(interfaces.ShadowRoot.State) != null and dom.shadow_hosts.hasInternal(instance)) return;
    return error.InvalidStateError;
}

/// Getter for activeElement (HTML §6.6.3).
pub fn get_activeElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    try ensureInitialized(instance);
    return html.focus.activeElement(instance);
}

/// Getter for styleSheets (CSSOM §6.4.3).
pub fn get_styleSheets(instance: *runtime.Instance) anyerror!*runtime.Instance {
    if (dom.document_internals.getInternal(instance)) |internal| {
        const sheets = internal.style_sheets_kept.get() orelse blk: {
            const made = interfaces.StyleSheetList.initWith(internal.allocator, instance.ctx, .{ .sheets_of = instance }) catch return error.OutOfMemory;
            internal.style_sheets_kept.made(made);
            break :blk made;
        };
        internal.style_sheets_kept.handOut(instance, sheets, .{ .name = "styleSheets" });
        return sheets;
    }
    if (instance.stateAs(interfaces.ShadowRoot.State) != null) {
        return dom.shadow_hosts.styleSheetsOf(instance);
    }
    return error.InvalidStateError;
}

/// Getter for adoptedStyleSheets (CSSOM §6.4.3).
pub fn get_adoptedStyleSheets(instance: *runtime.Instance) anyerror!runtime.JSValue {
    try ensureInitialized(instance);
    return dom.style.adopted.get(instance);
}

/// Setter for adoptedStyleSheets (CSSOM §6.4.3).
pub fn set_adoptedStyleSheets(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
    try ensureInitialized(instance);
    try dom.style.adopted.set(instance, value);
}

/// Getter for fullscreenElement (Fullscreen §3).
pub fn get_fullscreenElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    try ensureInitialized(instance);
    return dom.designated_elements.of(instance, .fullscreen);
}

/// Getter for pictureInPictureElement (Picture-in-Picture §4).
pub fn get_pictureInPictureElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    try ensureInitialized(instance);
    return dom.designated_elements.of(instance, .picture_in_picture);
}

/// Getter for pointerLockElement (Pointer Lock §6).
pub fn get_pointerLockElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    try ensureInitialized(instance);
    return dom.designated_elements.of(instance, .pointer_lock);
}

/// Getter for customElementRegistry (DOM §4.2.5).
pub fn get_customElementRegistry(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    if (dom.document_internals.getInternal(instance)) |internal| {
        return internal.custom_element_registry.get();
    }
    if (instance.stateAs(interfaces.ShadowRoot.State) != null) {
        return dom.shadow_hosts.customElementRegistryOf(instance);
    }
    return error.InvalidStateError;
}

/// Operation: getAnimations (Web Animations §6.9).
pub fn call_getAnimations(instance: *runtime.Instance) anyerror!runtime.JSValue {
    return dom.animations.rootAnimations(instance);
}
