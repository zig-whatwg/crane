//! Implementation for HTMLImageElement interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const fetch = @import("fetch");
const HTMLImageElement = interfaces.HTMLImageElement;
const Element = interfaces.Element;
const EventTarget = interfaces.EventTarget;
const Event = interfaces.Event;

pub const State = HTMLImageElement.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for implementation-specific data
/// Implementations can replace this with a real struct containing:
/// - Private data not exposed via WebIDL attributes
/// - Cached computations, buffers, etc.
pub const InternalState = struct {};

/// Initialize instance (creates the instance)
/// Chains to parent class: HTMLElement -> Element -> Node -> EventTarget
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    // Chain to parent class (HTMLElement)
    const HTMLElementImpl = @import("HTMLElement.zig");
    const instance = try HTMLElementImpl.init(allocator, StateType, vtable, ctx);
    // HTMLImageElement has no additional initialization
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // HTMLImageElement has no additional cleanup
    // Chain to parent class
    const HTMLElementImpl = @import("HTMLElement.zig");
    HTMLElementImpl.deinit(instance);
}

/// Constructor implementation
/// This is called when the interface is constructed from JavaScript
pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
    // Create instance through init()
    const instance = try init(ctx.allocator, State, &HTMLImageElement.vtable, ctx);
    errdefer deinit(instance);

    // TODO: Implement constructor logic with parameters

    return instance;
}

/// Getter for alt
pub fn get_alt(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for src - reflects the "src" content attribute
/// Spec: https://html.spec.whatwg.org/multipage/embedded-content.html#dom-img-src
pub fn get_src(instance: *runtime.Instance) anyerror!runtime.USVString {
    // Get the src attribute value, returning empty string if not set
    const attr_value = try Element.call_getAttribute(instance, runtime.DOMString.initInterned("src"));
    if (attr_value) |val| {
        // USVString is []const u8, DOMString has asSlice() method
        return val.asSlice();
    }
    return "";
}

/// Getter for srcset
pub fn get_srcset(instance: *runtime.Instance) anyerror!runtime.USVString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for sizes
pub fn get_sizes(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for crossOrigin
pub fn get_crossOrigin(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    _ = instance;
    return null;
}

/// Getter for useMap
pub fn get_useMap(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for isMap
pub fn get_isMap(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for width
pub fn get_width(instance: *runtime.Instance) anyerror!u32 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for height
pub fn get_height(instance: *runtime.Instance) anyerror!u32 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for naturalWidth
pub fn get_naturalWidth(instance: *runtime.Instance) anyerror!u32 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for naturalHeight
pub fn get_naturalHeight(instance: *runtime.Instance) anyerror!u32 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for complete
pub fn get_complete(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for currentSrc
pub fn get_currentSrc(instance: *runtime.Instance) anyerror!runtime.USVString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for referrerPolicy
pub fn get_referrerPolicy(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for decoding
pub fn get_decoding(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for loading
pub fn get_loading(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for fetchPriority
pub fn get_fetchPriority(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for name
pub fn get_name(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for lowsrc
pub fn get_lowsrc(instance: *runtime.Instance) anyerror!runtime.USVString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for align
pub fn get_align(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for hspace
pub fn get_hspace(instance: *runtime.Instance) anyerror!u32 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for vspace
pub fn get_vspace(instance: *runtime.Instance) anyerror!u32 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for longDesc
pub fn get_longDesc(instance: *runtime.Instance) anyerror!runtime.USVString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for border
pub fn get_border(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for x
pub fn get_x(instance: *runtime.Instance) anyerror!i32 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for y
pub fn get_y(instance: *runtime.Instance) anyerror!i32 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for attributionSrc
pub fn get_attributionSrc(instance: *runtime.Instance) anyerror!runtime.USVString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for sharedStorageWritable
pub fn get_sharedStorageWritable(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Setter for alt
pub fn set_alt(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for src - sets the "src" content attribute and fetches the image
/// Spec: https://html.spec.whatwg.org/multipage/embedded-content.html#dom-img-src
///
/// When src is set:
/// 1. Store the src attribute on the element
/// 2. Initiate a fetch for the image resource
/// 3. On success (HTTP 200-299): fire 'load' event
/// 4. On error: fire 'error' event
pub fn set_src(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    // Step 1: Set the src attribute using Element.setAttribute
    // USVString is []const u8, need to convert to DOMString
    const dom_value = runtime.DOMString.initInterned(value);
    try Element.call_setAttribute(instance, runtime.DOMString.initInterned("src"), dom_value);

    // Step 2: Get the URL string from the value (USVString is already []const u8)
    const url_str = value;

    // Skip empty URLs
    if (url_str.len == 0) {
        return;
    }

    // Step 3: Initiate the fetch
    const allocator = instance.ctx.allocator;
    var fetch_result = fetch.webidl.globalFetch(allocator, .{ .url = url_str }, .{});
    defer fetch_result.deinit();

    // Step 4: Create and dispatch the appropriate event based on the result
    switch (fetch_result) {
        .response => |response| {
            // Check if the response indicates success (HTTP 200-299)
            if (response.ok()) {
                // Fire 'load' event
                fireEventOnElement(instance, "load") catch {};
            } else {
                // HTTP error status - fire 'error' event
                fireEventOnElement(instance, "error") catch {};
            }
        },
        .err => {
            // Network error - fire 'error' event
            fireEventOnElement(instance, "error") catch {};
        },
    }
}

/// Helper function to create and dispatch an event on an element
fn fireEventOnElement(instance: *runtime.Instance, event_type: []const u8) !void {
    const allocator = instance.ctx.allocator;
    const ctx = instance.ctx;

    // Create the event using the interface's init function (2 args, not 4)
    const event = try Event.init(allocator, ctx);
    errdefer Event.deinit(event);

    // Initialize the event with the given type
    // Per spec: bubbles = true for load/error events on elements, cancelable = false
    const event_type_str = runtime.DOMString.initInterned(event_type);
    const bubbles = webidl.Opt(bool).passed(true);
    const cancelable = webidl.Opt(bool).passed(false);
    try Event.call_initEvent(event, event_type_str, bubbles, cancelable);

    // Dispatch the event on the element
    // HTMLImageElement inherits from Element which inherits from EventTarget
    _ = try EventTarget.call_dispatchEvent(instance, event);
}

/// Setter for srcset
pub fn set_srcset(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for sizes
pub fn set_sizes(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for crossOrigin
pub fn set_crossOrigin(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for useMap
pub fn set_useMap(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for isMap
pub fn set_isMap(instance: *runtime.Instance, value: bool) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for width
pub fn set_width(instance: *runtime.Instance, value: u32) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for height
pub fn set_height(instance: *runtime.Instance, value: u32) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for referrerPolicy
pub fn set_referrerPolicy(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for decoding
pub fn set_decoding(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for loading
pub fn set_loading(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for fetchPriority
pub fn set_fetchPriority(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for name
pub fn set_name(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for lowsrc
pub fn set_lowsrc(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for align
pub fn set_align(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for hspace
pub fn set_hspace(instance: *runtime.Instance, value: u32) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for vspace
pub fn set_vspace(instance: *runtime.Instance, value: u32) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for longDesc
pub fn set_longDesc(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for border
pub fn set_border(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for attributionSrc
pub fn set_attributionSrc(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for sharedStorageWritable
pub fn set_sharedStorageWritable(instance: *runtime.Instance, value: bool) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Operation: decode
pub fn call_decode(instance: *runtime.Instance) anyerror!runtime.JSValue {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: setAttribute override
/// Intercepts src attribute changes to trigger image loading per HTML spec.
/// For all other attributes, delegates to Element.call_setAttribute.
/// Spec: https://html.spec.whatwg.org/multipage/images.html#update-the-image-data
pub fn call_setAttribute(instance: *runtime.Instance, qualifiedName: runtime.DOMString, value: runtime.DOMString) anyerror!void {
    // Delegate to parent (Element) for the actual attribute storage
    try Element.call_setAttribute(instance, qualifiedName, value);

    // Check if this is the "src" attribute - if so, trigger image loading
    const attr_name = qualifiedName.asSlice();
    if (std.mem.eql(u8, attr_name, "src")) {
        const url_str = value.asSlice();

        // Skip empty URLs
        if (url_str.len == 0) {
            return;
        }

        // Initiate the fetch for the image
        const allocator = instance.ctx.allocator;
        var fetch_result = fetch.webidl.globalFetch(allocator, .{ .url = url_str }, .{});
        defer fetch_result.deinit();

        // Create and dispatch the appropriate event based on the result
        switch (fetch_result) {
            .response => |response| {
                // Check if the response indicates success (HTTP 200-299)
                if (response.ok()) {
                    // Fire 'load' event
                    fireEventOnElement(instance, "load") catch {};
                } else {
                    // HTTP error status - fire 'error' event
                    fireEventOnElement(instance, "error") catch {};
                }
            },
            .err => {
                // Network error - fire 'error' event
                fireEventOnElement(instance, "error") catch {};
            },
        }
    }
}
