//! Implementation for HTMLMetaElement interface
//!
//! HTMLMetaElement represents a <meta> element in the DOM.
//! All attributes are reflected content attributes per HTML spec.
//! Spec: https://html.spec.whatwg.org/multipage/semantics.html#the-meta-element

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const HTMLMetaElement = interfaces.HTMLMetaElement;
const Element = interfaces.Element;

pub const State = HTMLMetaElement.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for implementation-specific data
/// Implementations can replace this with a real struct containing:
/// - Private data not exposed via WebIDL attributes
/// - Cached computations, buffers, etc.
pub const InternalState = struct {};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    // TODO: Initialize your instance state here if needed
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // TODO: Clean up your instance resources here
    _ = instance; // GC layer handles slab freeing - do NOT call runtime.Instance.deinit()
}

/// Constructor implementation
/// This is called when the interface is constructed from JavaScript
pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
    // Create instance through init()
    const instance = try init(ctx.allocator, State, &HTMLMetaElement.vtable, ctx);
    errdefer deinit(instance);

    // TODO: Implement constructor logic with parameters

    return instance;
}

// =============================================================================
// Reflected Content Attributes
// =============================================================================
// All HTMLMetaElement attributes are reflected content attributes.
// Spec: https://html.spec.whatwg.org/multipage/semantics.html#the-meta-element

/// Getter for name - reflects the "name" content attribute
pub fn get_name(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return (try Element.call_getAttribute(instance, runtime.DOMString.initInterned("name"))) orelse runtime.DOMString.initEmpty();
}

/// Getter for httpEquiv - reflects the "http-equiv" content attribute
pub fn get_httpEquiv(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return (try Element.call_getAttribute(instance, runtime.DOMString.initInterned("http-equiv"))) orelse runtime.DOMString.initEmpty();
}

/// Getter for content - reflects the "content" content attribute
pub fn get_content(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return (try Element.call_getAttribute(instance, runtime.DOMString.initInterned("content"))) orelse runtime.DOMString.initEmpty();
}

/// Getter for media - reflects the "media" content attribute
pub fn get_media(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return (try Element.call_getAttribute(instance, runtime.DOMString.initInterned("media"))) orelse runtime.DOMString.initEmpty();
}

/// Getter for scheme - reflects the "scheme" content attribute (obsolete but still in spec)
pub fn get_scheme(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return (try Element.call_getAttribute(instance, runtime.DOMString.initInterned("scheme"))) orelse runtime.DOMString.initEmpty();
}

/// Setter for name - sets the "name" content attribute
pub fn set_name(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try Element.call_setAttribute(instance, runtime.DOMString.initInterned("name"), value);
}

/// Setter for httpEquiv - sets the "http-equiv" content attribute
pub fn set_httpEquiv(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try Element.call_setAttribute(instance, runtime.DOMString.initInterned("http-equiv"), value);
}

/// Setter for content - sets the "content" content attribute
pub fn set_content(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try Element.call_setAttribute(instance, runtime.DOMString.initInterned("content"), value);
}

/// Setter for media - sets the "media" content attribute
pub fn set_media(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try Element.call_setAttribute(instance, runtime.DOMString.initInterned("media"), value);
}

/// Setter for scheme - sets the "scheme" content attribute (obsolete but still in spec)
pub fn set_scheme(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try Element.call_setAttribute(instance, runtime.DOMString.initInterned("scheme"), value);
}
