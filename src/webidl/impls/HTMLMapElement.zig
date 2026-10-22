//! Implementation for HTMLMapElement interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const HTMLMapElement = interfaces.HTMLMapElement;

pub const State = HTMLMapElement.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for implementation-specific data
/// Implementations can replace this with a real struct containing:
/// - Private data not exposed via WebIDL attributes
/// - Cached computations, buffers, etc.
pub const InternalState = struct {};

/// Constructor implementation
/// This is called when the interface is constructed from JavaScript
pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
    // Create instance through init()
    const instance = try HTMLMapElement.init(ctx.allocator, ctx);
    errdefer HTMLMapElement.deinit(instance);

    // TODO: Implement constructor logic with parameters

    return instance;
}

/// HTML 4.8.12: the live collection rooted at this map, matching area elements.
/// The generated [SameObject] getter caches and traces this collection; its
/// existing HTMLCollection implementation retains the root and tracks mutations.
/// WebKit uses the same rooted collection design in HTMLMapElement::areas:
/// https://github.com/WebKit/WebKit/blob/main/Source/WebCore/html/HTMLMapElement.cpp
pub fn get_areas(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return interfaces.Element.call_getElementsByTagNameNS(instance, runtime.DOMString.initInterned("http://www.w3.org/1999/xhtml"), .initInterned("area"));
}
