//! Implementation for HTMLAreaElement interface
//!
//! Spec: https://html.spec.whatwg.org/multipage/image-maps.html#htmlareaelement
//!
//! HTMLAreaElement represents the <area> element in an image map.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const HTMLAreaElement = interfaces.HTMLAreaElement;

// Import related impls for attribute access
const ElementImpl = @import("Element.zig");
const DOMTokenListImpl = @import("DOMTokenList.zig");
const HTMLHyperlinkElementUtilsImpl = @import("HTMLHyperlinkElementUtils.zig");

pub const State = HTMLAreaElement.State;

pub const ImplError = error{
    NotImplemented,
    InvalidState,
    OutOfMemory,
};

// Use shared InstanceRegistry utility for internal state management
const utils = @import("webidl").utils;
const Registry = utils.InstanceRegistry(InternalState);

/// Internal state for HTMLAreaElement implementation
pub const InternalState = struct {
    /// Cached relList DOMTokenList instance
    rel_list: ?*runtime.Instance = null,

    pub fn deinit(self: *InternalState) void {
        _ = self;
    }
};

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
    errdefer interfaces.HTMLElement.deinit(instance);

    // Initialize HTMLAreaElement's own internal state in registry
    const ArenaAllocator = @import("runtime").ArenaAllocator;
    const internal = try ArenaAllocator.get().create(InternalState);
    internal.* = .{};
    try Registry.set(instance, internal);

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // Clean up from registry
    if (Registry.get(instance)) |internal| {
        internal.deinit();
    }
    Registry.remove(instance);

    // Chain to parent class (via interface per Golden Rule #13)
    interfaces.HTMLElement.deinit(instance);
}

/// Constructor implementation
/// This is called when the interface is constructed from JavaScript
pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
    // Create instance through init()
    const instance = try init(ctx.allocator, State, &HTMLAreaElement.vtable, ctx);
    errdefer deinit(instance);

    // TODO: Implement constructor logic with parameters

    return instance;
}

/// Getter for alt
pub fn get_alt(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for coords
pub fn get_coords(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for shape
pub fn get_shape(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for target
pub fn get_target(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for download
pub fn get_download(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ping
pub fn get_ping(instance: *runtime.Instance) anyerror!runtime.USVString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for rel
/// Spec: https://html.spec.whatwg.org/multipage/image-maps.html#dom-area-rel
/// Reflects the rel attribute.
pub fn get_rel(instance: *runtime.Instance) anyerror!runtime.DOMString {
    // Use Element's attribute access
    const elem_internal = ElementImpl.getInternal(instance) orelse return error.InvalidState;

    // Look for the "rel" attribute
    if (elem_internal.findAttribute(null, "rel")) |entry| {
        return runtime.DOMString.initDupe(instance.ctx.allocator, entry.value) catch return error.OutOfMemory;
    }

    return runtime.DOMString.initEmpty();
}

/// Getter for relList
/// Spec: https://html.spec.whatwg.org/multipage/image-maps.html#dom-area-rellist
/// Returns a DOMTokenList reflecting the rel attribute.
pub fn get_relList(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = Registry.get(instance) orelse return error.InvalidState;
    const elem_internal = ElementImpl.getInternal(instance) orelse return error.InvalidState;

    // Return cached DOMTokenList if it exists
    if (internal.rel_list) |existing| {
        return existing;
    }

    // Create a new DOMTokenList
    const token_list = interfaces.DOMTokenList.init(elem_internal.allocator, instance.ctx) catch return error.OutOfMemory;
    errdefer interfaces.DOMTokenList.deinit(token_list);

    // Initialize with current rel attribute value
    if (elem_internal.findAttribute(null, "rel")) |entry| {
        interfaces.DOMTokenList.set_value(token_list, runtime.DOMString.initInterned(entry.value)) catch return error.OutOfMemory;
    }

    // Associate with this element and the "rel" attribute
    DOMTokenListImpl.setElement(token_list, instance, runtime.DOMString.initInterned("rel"));

    // Cache for future access
    internal.rel_list = token_list;

    return token_list;
}

/// Getter for referrerPolicy
pub fn get_referrerPolicy(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for noHref
pub fn get_noHref(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for attributionSrc
pub fn get_attributionSrc(instance: *runtime.Instance) anyerror!runtime.USVString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for href - delegate to HTMLHyperlinkElementUtils mixin
pub fn get_href(instance: *runtime.Instance) anyerror!runtime.USVString {
    return HTMLHyperlinkElementUtilsImpl.get_href(instance);
}

/// Getter for origin - delegate to HTMLHyperlinkElementUtils mixin
pub fn get_origin(instance: *runtime.Instance) anyerror!runtime.USVString {
    return HTMLHyperlinkElementUtilsImpl.get_origin(instance);
}

/// Getter for protocol - delegate to HTMLHyperlinkElementUtils mixin
pub fn get_protocol(instance: *runtime.Instance) anyerror!runtime.USVString {
    return HTMLHyperlinkElementUtilsImpl.get_protocol(instance);
}

/// Getter for username - delegate to HTMLHyperlinkElementUtils mixin
pub fn get_username(instance: *runtime.Instance) anyerror!runtime.USVString {
    return HTMLHyperlinkElementUtilsImpl.get_username(instance);
}

/// Getter for password - delegate to HTMLHyperlinkElementUtils mixin
pub fn get_password(instance: *runtime.Instance) anyerror!runtime.USVString {
    return HTMLHyperlinkElementUtilsImpl.get_password(instance);
}

/// Getter for host - delegate to HTMLHyperlinkElementUtils mixin
pub fn get_host(instance: *runtime.Instance) anyerror!runtime.USVString {
    return HTMLHyperlinkElementUtilsImpl.get_host(instance);
}

/// Getter for hostname - delegate to HTMLHyperlinkElementUtils mixin
pub fn get_hostname(instance: *runtime.Instance) anyerror!runtime.USVString {
    return HTMLHyperlinkElementUtilsImpl.get_hostname(instance);
}

/// Getter for port - delegate to HTMLHyperlinkElementUtils mixin
pub fn get_port(instance: *runtime.Instance) anyerror!runtime.USVString {
    return HTMLHyperlinkElementUtilsImpl.get_port(instance);
}

/// Getter for pathname - delegate to HTMLHyperlinkElementUtils mixin
pub fn get_pathname(instance: *runtime.Instance) anyerror!runtime.USVString {
    return HTMLHyperlinkElementUtilsImpl.get_pathname(instance);
}

/// Getter for search - delegate to HTMLHyperlinkElementUtils mixin
pub fn get_search(instance: *runtime.Instance) anyerror!runtime.USVString {
    return HTMLHyperlinkElementUtilsImpl.get_search(instance);
}

/// Getter for hash - delegate to HTMLHyperlinkElementUtils mixin
pub fn get_hash(instance: *runtime.Instance) anyerror!runtime.USVString {
    return HTMLHyperlinkElementUtilsImpl.get_hash(instance);
}

/// Setter for alt
pub fn set_alt(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for coords
pub fn set_coords(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for shape
pub fn set_shape(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for target
pub fn set_target(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for download
pub fn set_download(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ping
pub fn set_ping(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for rel
/// Spec: https://html.spec.whatwg.org/multipage/image-maps.html#dom-area-rel
/// Sets the rel attribute.
pub fn set_rel(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    // Use Element's setAttribute through the interface
    try interfaces.Element.call_setAttribute(instance, runtime.DOMString.initInterned("rel"), value);
}

/// Setter for referrerPolicy
pub fn set_referrerPolicy(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for noHref
pub fn set_noHref(instance: *runtime.Instance, value: bool) anyerror!void {
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

/// Setter for href
pub fn set_href(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for protocol
pub fn set_protocol(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for username
pub fn set_username(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for password
pub fn set_password(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for host
pub fn set_host(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for hostname
pub fn set_hostname(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for port
pub fn set_port(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for pathname
pub fn set_pathname(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for search
pub fn set_search(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for hash
pub fn set_hash(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}
