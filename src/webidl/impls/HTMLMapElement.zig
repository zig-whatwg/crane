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
///
/// It is the map's OWN collection, not the one getElementsByTagNameNS keeps
/// for the same filter (dom.live_collections.newCollection, lane perf2):
/// Blink's areas() is EnsureCachedCollection<HTMLCollection>(kMapAreas), a
/// collection type of its own, and in all three browsers
/// `map.areas !== map.getElementsByTagNameNS(HTML, "area")`.
pub fn get_areas(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return @import("dom").live_collections.newCollection(instance, .{ .namespace_local_name = .{ .namespace = "http://www.w3.org/1999/xhtml", .local_name = "area" } });
}
