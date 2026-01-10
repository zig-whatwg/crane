//! Implementation for HTMLAnchorElement interface
//!
//! Spec: https://html.spec.whatwg.org/multipage/text-level-semantics.html#htmlanchorelement
//!
//! HTMLAnchorElement represents the <a> element. It includes HTMLHyperlinkElementUtils
//! mixin for URL decomposition attributes.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const HTMLAnchorElement = interfaces.HTMLAnchorElement;

// Import related impls for attribute access
const ElementImpl = @import("Element.zig");
const DOMTokenListImpl = @import("DOMTokenList.zig");
const HTMLHyperlinkElementUtilsImpl = @import("HTMLHyperlinkElementUtils.zig");

pub const State = HTMLAnchorElement.State;

pub const ImplError = error{
    NotImplemented,
    InvalidState,
    OutOfMemory,
};

// Use shared InstanceRegistry utility for internal state management
const utils = @import("webidl").utils;
const Registry = utils.InstanceRegistry(InternalState);

/// Internal state for HTMLAnchorElement implementation
/// Stores cached relList DOMTokenList instance
pub const InternalState = struct {
    /// Cached relList DOMTokenList instance
    rel_list: ?*runtime.Instance = null,

    pub fn deinit(self: *InternalState) void {
        // Note: rel_list is owned by V8/GC, not us
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

    // Initialize HTMLAnchorElement's own internal state in registry
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
    const instance = try init(ctx.allocator, State, &HTMLAnchorElement.vtable, ctx);
    errdefer deinit(instance);

    // TODO: Implement constructor logic with parameters

    return instance;
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
/// Spec: https://html.spec.whatwg.org/multipage/text-level-semantics.html#dom-a-rel
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
/// Spec: https://html.spec.whatwg.org/multipage/text-level-semantics.html#dom-a-rellist
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

/// Getter for hreflang
pub fn get_hreflang(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for type
pub fn get_type(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for text
pub fn get_text(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for referrerPolicy
pub fn get_referrerPolicy(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for attributionSourceId
pub fn get_attributionSourceId(instance: *runtime.Instance) anyerror!u32 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for attributionDestination
pub fn get_attributionDestination(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for coords
pub fn get_coords(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for charset
pub fn get_charset(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for name
pub fn get_name(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for rev
pub fn get_rev(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for shape
pub fn get_shape(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for attributionSrc
pub fn get_attributionSrc(instance: *runtime.Instance) anyerror!runtime.USVString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for href
/// Delegates to HTMLHyperlinkElementUtils mixin
pub fn get_href(instance: *runtime.Instance) anyerror!runtime.USVString {
    return HTMLHyperlinkElementUtilsImpl.get_href(instance);
}

/// Getter for origin
/// Delegates to HTMLHyperlinkElementUtils mixin
pub fn get_origin(instance: *runtime.Instance) anyerror!runtime.USVString {
    return HTMLHyperlinkElementUtilsImpl.get_origin(instance);
}

/// Getter for protocol
/// Delegates to HTMLHyperlinkElementUtils mixin
pub fn get_protocol(instance: *runtime.Instance) anyerror!runtime.USVString {
    return HTMLHyperlinkElementUtilsImpl.get_protocol(instance);
}

/// Getter for username
/// Delegates to HTMLHyperlinkElementUtils mixin
pub fn get_username(instance: *runtime.Instance) anyerror!runtime.USVString {
    return HTMLHyperlinkElementUtilsImpl.get_username(instance);
}

/// Getter for password
/// Delegates to HTMLHyperlinkElementUtils mixin
pub fn get_password(instance: *runtime.Instance) anyerror!runtime.USVString {
    return HTMLHyperlinkElementUtilsImpl.get_password(instance);
}

/// Getter for host
/// Delegates to HTMLHyperlinkElementUtils mixin
pub fn get_host(instance: *runtime.Instance) anyerror!runtime.USVString {
    return HTMLHyperlinkElementUtilsImpl.get_host(instance);
}

/// Getter for hostname
/// Delegates to HTMLHyperlinkElementUtils mixin
pub fn get_hostname(instance: *runtime.Instance) anyerror!runtime.USVString {
    return HTMLHyperlinkElementUtilsImpl.get_hostname(instance);
}

/// Getter for port
/// Delegates to HTMLHyperlinkElementUtils mixin
pub fn get_port(instance: *runtime.Instance) anyerror!runtime.USVString {
    return HTMLHyperlinkElementUtilsImpl.get_port(instance);
}

/// Getter for pathname
/// Delegates to HTMLHyperlinkElementUtils mixin
pub fn get_pathname(instance: *runtime.Instance) anyerror!runtime.USVString {
    return HTMLHyperlinkElementUtilsImpl.get_pathname(instance);
}

/// Getter for search
/// Delegates to HTMLHyperlinkElementUtils mixin
pub fn get_search(instance: *runtime.Instance) anyerror!runtime.USVString {
    return HTMLHyperlinkElementUtilsImpl.get_search(instance);
}

/// Getter for hash
/// Delegates to HTMLHyperlinkElementUtils mixin
pub fn get_hash(instance: *runtime.Instance) anyerror!runtime.USVString {
    return HTMLHyperlinkElementUtilsImpl.get_hash(instance);
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
/// Spec: https://html.spec.whatwg.org/multipage/text-level-semantics.html#dom-a-rel
/// Sets the rel attribute.
pub fn set_rel(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    // Use Element's setAttribute through the interface
    try interfaces.Element.call_setAttribute(instance, runtime.DOMString.initInterned("rel"), value);
}

/// Setter for hreflang
pub fn set_hreflang(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for type
pub fn set_type(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for text
pub fn set_text(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
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

/// Setter for attributionSourceId
pub fn set_attributionSourceId(instance: *runtime.Instance, value: u32) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for attributionDestination
pub fn set_attributionDestination(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
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

/// Setter for charset
pub fn set_charset(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
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

/// Setter for rev
pub fn set_rev(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
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

/// Setter for attributionSrc
pub fn set_attributionSrc(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for href
/// Delegates to HTMLHyperlinkElementUtils mixin
pub fn set_href(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    return HTMLHyperlinkElementUtilsImpl.set_href(instance, value);
}

/// Setter for protocol
/// Delegates to HTMLHyperlinkElementUtils mixin
pub fn set_protocol(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    return HTMLHyperlinkElementUtilsImpl.set_protocol(instance, value);
}

/// Setter for username
/// Delegates to HTMLHyperlinkElementUtils mixin
pub fn set_username(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    return HTMLHyperlinkElementUtilsImpl.set_username(instance, value);
}

/// Setter for password
/// Delegates to HTMLHyperlinkElementUtils mixin
pub fn set_password(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    return HTMLHyperlinkElementUtilsImpl.set_password(instance, value);
}

/// Setter for host
/// Delegates to HTMLHyperlinkElementUtils mixin
pub fn set_host(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    return HTMLHyperlinkElementUtilsImpl.set_host(instance, value);
}

/// Setter for hostname
/// Delegates to HTMLHyperlinkElementUtils mixin
pub fn set_hostname(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    return HTMLHyperlinkElementUtilsImpl.set_hostname(instance, value);
}

/// Setter for port
/// Delegates to HTMLHyperlinkElementUtils mixin
pub fn set_port(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    return HTMLHyperlinkElementUtilsImpl.set_port(instance, value);
}

/// Setter for pathname
/// Delegates to HTMLHyperlinkElementUtils mixin
pub fn set_pathname(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    return HTMLHyperlinkElementUtilsImpl.set_pathname(instance, value);
}

/// Setter for search
/// Delegates to HTMLHyperlinkElementUtils mixin
pub fn set_search(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    return HTMLHyperlinkElementUtilsImpl.set_search(instance, value);
}

/// Setter for hash
/// Delegates to HTMLHyperlinkElementUtils mixin
pub fn set_hash(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    return HTMLHyperlinkElementUtilsImpl.set_hash(instance, value);
}
