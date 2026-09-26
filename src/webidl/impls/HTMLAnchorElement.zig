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
const webidl = @import("webidl");
const HTMLAnchorElement = interfaces.HTMLAnchorElement;

// Import related impls for attribute access
const ElementImpl = @import("Element.zig");
const DOMTokenListImpl = @import("DOMTokenList.zig");

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
    // Its activation behaviour: following its hyperlink (dom.activation).
    @import("dom").activation.install(.{ .has = &hasActivationBehavior, .run = &runActivationBehavior });

    const instance = try HTMLElementImpl.init(allocator, StateType, vtable, ctx);
    errdefer interfaces.HTMLElement.deinit(instance);

    // Initialize HTMLAnchorElement's own internal state in registry
    const ArenaAllocator = @import("runtime").ArenaAllocator;
    // The registry owns this block, so `Registry.remove` returns it to the
    // arena. With `set` it was dropped from the map and held to process
    // exit - 904 bytes per discarded element, measured.
    const internal = try Registry.createIn(instance, ArenaAllocator.get());
    internal.* = .{};

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

/// Getter for target: reflects the target content attribute.
pub fn get_target(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return reflectGet(instance, "target");
}

/// Getter for download: reflects the download content attribute.
pub fn get_download(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return reflectGet(instance, "download");
}

/// Getter for ping: reflects the ping content attribute.
pub fn get_ping(instance: *runtime.Instance) anyerror!runtime.USVString {
    return reflectGetUsv(instance, "ping");
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

/// Getter for hreflang: reflects the hreflang content attribute.
pub fn get_hreflang(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return reflectGet(instance, "hreflang");
}

/// Getter for type: reflects the type content attribute.
pub fn get_type(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return reflectGet(instance, "type");
}

/// Getter for text: HTML "the same as the textContent IDL attribute".
pub fn get_text(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return (try interfaces.Node.get_textContent(instance)) orelse runtime.DOMString.initEmpty();
}

/// Getter for referrerPolicy: reflects the referrerpolicy content attribute.
pub fn get_referrerPolicy(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return reflectReferrerPolicy(instance);
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

/// Getter for coords: reflects the coords content attribute.
pub fn get_coords(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return reflectGet(instance, "coords");
}

/// Getter for charset: reflects the charset content attribute.
pub fn get_charset(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return reflectGet(instance, "charset");
}

/// Getter for name: reflects the name content attribute.
pub fn get_name(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return reflectGet(instance, "name");
}

/// Getter for rev: reflects the rev content attribute.
pub fn get_rev(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return reflectGet(instance, "rev");
}

/// Getter for shape: reflects the shape content attribute.
pub fn get_shape(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return reflectGet(instance, "shape");
}

/// Getter for attributionSrc
pub fn get_attributionSrc(instance: *runtime.Instance) anyerror!runtime.USVString {
    _ = instance;
    return error.NotImplemented;
}

/// Setter for target: sets the target content attribute.
pub fn set_target(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    return reflectSet(instance, "target", value);
}

/// Setter for download: sets the download content attribute.
pub fn set_download(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    return reflectSet(instance, "download", value);
}

/// Setter for ping: sets the ping content attribute.
pub fn set_ping(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    return reflectSet(instance, "ping", runtime.DOMString.initInterned(value));
}

/// Setter for rel
/// Spec: https://html.spec.whatwg.org/multipage/text-level-semantics.html#dom-a-rel
/// Sets the rel attribute.
pub fn set_rel(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    // Use Element's setAttribute through the interface
    try interfaces.Element.call_setAttribute(instance, runtime.DOMString.initInterned("rel"), value);
}

/// Setter for hreflang: sets the hreflang content attribute.
pub fn set_hreflang(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    return reflectSet(instance, "hreflang", value);
}

/// Setter for type: sets the type content attribute.
pub fn set_type(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    return reflectSet(instance, "type", value);
}

/// Setter for text: the textContent setter.
pub fn set_text(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    return interfaces.Node.set_textContent(instance, value);
}

/// Setter for referrerPolicy: sets the referrerpolicy content attribute.
pub fn set_referrerPolicy(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    return reflectSet(instance, "referrerpolicy", value);
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

/// Setter for coords: sets the coords content attribute.
pub fn set_coords(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    return reflectSet(instance, "coords", value);
}

/// Setter for charset: sets the charset content attribute.
pub fn set_charset(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    return reflectSet(instance, "charset", value);
}

/// Setter for name: sets the name content attribute.
pub fn set_name(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    return reflectSet(instance, "name", value);
}

/// Setter for rev: sets the rev content attribute.
pub fn set_rev(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    return reflectSet(instance, "rev", value);
}

/// Setter for shape: sets the shape content attribute.
pub fn set_shape(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    return reflectSet(instance, "shape", value);
}

/// Setter for attributionSrc
pub fn set_attributionSrc(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

// =============================================================================
// Reflection (HTML 2.6.1) and activation behaviour
// =============================================================================

/// A DOMString attribute reflecting content attribute `name`: its value, or
/// the empty string. A copy - the binding frees what a getter returns.
fn reflectGet(instance: *runtime.Instance, comptime name: []const u8) !runtime.DOMString {
    const elem_internal = ElementImpl.getInternal(instance) orelse return error.InvalidState;
    if (elem_internal.findAttribute(null, name)) |entry| {
        return runtime.DOMString.initDupe(instance.ctx.allocator, entry.value);
    }
    return runtime.DOMString.initEmpty();
}

/// The USVString form of `reflectGet`, owned by the context allocator.
fn reflectGetUsv(instance: *runtime.Instance, comptime name: []const u8) ![]const u8 {
    const elem_internal = ElementImpl.getInternal(instance) orelse return error.InvalidState;
    const value = if (elem_internal.findAttribute(null, name)) |entry| entry.value else "";
    return instance.ctx.allocator.dupe(u8, value);
}

/// A boolean attribute: whether content attribute `name` is present.
fn reflectHas(instance: *runtime.Instance, comptime name: []const u8) !bool {
    const elem_internal = ElementImpl.getInternal(instance) orelse return error.InvalidState;
    return elem_internal.findAttribute(null, name) != null;
}

/// Set content attribute `name` to `value`.
fn reflectSet(instance: *runtime.Instance, comptime name: []const u8, value: runtime.DOMString) !void {
    try ElementImpl.call_setAttribute(instance, runtime.DOMString.initInterned(name), value);
}

/// A boolean attribute's setter: add the content attribute, or remove it.
fn reflectSetBool(instance: *runtime.Instance, comptime name: []const u8, value: bool) !void {
    if (value) {
        try ElementImpl.call_setAttribute(instance, runtime.DOMString.initInterned(name), runtime.DOMString.initInterned(""));
    } else {
        try ElementImpl.call_removeAttribute(instance, runtime.DOMString.initInterned(name));
    }
}

/// referrerPolicy: an enumerated attribute limited to the referrer policy
/// keywords, with no missing or invalid value default (the empty string).
fn reflectReferrerPolicy(instance: *runtime.Instance) !runtime.DOMString {
    const elem_internal = ElementImpl.getInternal(instance) orelse return error.InvalidState;
    const entry = elem_internal.findAttribute(null, "referrerpolicy") orelse return runtime.DOMString.initEmpty();
    const keywords = [_][]const u8{
        "no-referrer",                     "no-referrer-when-downgrade", "same-origin",
        "origin",                          "strict-origin",              "origin-when-cross-origin",
        "strict-origin-when-cross-origin", "unsafe-url",
    };
    for (keywords) |keyword| {
        if (std.ascii.eqlIgnoreCase(entry.value, keyword)) return runtime.DOMString.initInterned(keyword);
    }
    return runtime.DOMString.initEmpty();
}

/// dom.activation: every a element has activation behaviour.
fn hasActivationBehavior(target: *runtime.Instance) bool {
    return target.stateAs(State) != null;
}

/// dom.activation: the a element's activation behaviour (HTML 4.6.4): "if
/// element has no href attribute, then return"; otherwise follow the
/// hyperlink (dom.navigables). Downloading (the download attribute) and the
/// image map coordinates of an ismap image are not modelled.
fn runActivationBehavior(target: *runtime.Instance, event: *runtime.Instance) void {
    _ = event;
    const elem_internal = ElementImpl.getInternal(target) orelse return;
    if (elem_internal.findAttribute(null, "href") == null) return;
    const navigables = @import("dom").navigables;
    // The navigables are the iframe's to run; a page that never made an
    // iframe has not installed them yet.
    if (!navigables.isInstalled()) {
        const document = (interfaces.Node.get_ownerDocument(target) catch null) orelse return;
        const installer = interfaces.Document.call_createElement(document, runtime.DOMString.initInterned("iframe"), webidl.Opt(runtime.JSValue).notPassed()) catch return;
        installer.releaseIfUnwrapped(runtime.SlabAllocator.generationOf(installer));
    }
    navigables.followHyperlink(target);
}
