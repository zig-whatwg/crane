//! Implementation for SVGAElement interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const SVGAElement = interfaces.SVGAElement;

pub const State = SVGAElement.State;

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
    // Its activation behaviour: following its hyperlink (dom.activation).
    @import("dom").activation.install(.{ .has = &hasActivationBehavior, .run = &runActivationBehavior });
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    // TODO: Initialize your instance state here if needed
    return instance;
}

/// dom.activation: every SVG a element has activation behaviour.
fn hasActivationBehavior(target: *runtime.Instance) bool {
    return target.stateAs(State) != null;
}

/// The XLink namespace, where SVG's legacy `xlink:href` lives.
const xlink_namespace = "http://www.w3.org/1999/xlink";

/// dom.activation: the SVG a element's activation behaviour - SVG 2's a
/// element follows its hyperlink as HTML's a does (HTML 4.6.4): with no URL
/// to follow, neither an href nor an xlink:href attribute, nothing;
/// otherwise follow the hyperlink (dom.navigables).
fn runActivationBehavior(target: *runtime.Instance, event: *runtime.Instance) void {
    _ = event;
    const has_href = interfaces.Element.call_hasAttribute(target, runtime.DOMString.initInterned("href")) catch false;
    const has_xlink_href = interfaces.Element.call_hasAttributeNS(target, runtime.DOMString.initInterned(xlink_namespace), runtime.DOMString.initInterned("href")) catch false;
    if (!has_href and !has_xlink_href) return;
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

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // TODO: Clean up your instance resources here
    _ = instance; // GC layer handles slab freeing - do NOT call runtime.Instance.deinit()
}

/// Getter for target
pub fn get_target(instance: *runtime.Instance) anyerror!*runtime.Instance {
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
pub fn get_rel(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for relList
pub fn get_relList(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
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

/// Getter for referrerPolicy
pub fn get_referrerPolicy(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
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
pub fn set_rel(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
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

/// Setter for referrerPolicy
pub fn set_referrerPolicy(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}
