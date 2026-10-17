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

/// The hooks this type owns (src/dom), installed once, at process start,
/// by crane.Process through the generated interface (docs/instances.md).
pub fn installHooks() void {
    @import("dom").extract_origin.install(.svg_anchor, .{ .owns = &ownsOriginExtraction, .extract = &extractOrigin });
    // Its activation behaviour: following its hyperlink (dom.activation).
    @import("dom").activation.install(.{ .has = &hasActivationBehavior, .run = &runActivationBehavior });
}

fn ownsOriginExtraction(instance: *runtime.Instance) bool {
    return instance.stateAs(State) != null;
}

/// SVG includes HTMLHyperlinkElementUtils (SVG.idl:674), whose extraction
/// steps return null for a null URL and the URL's origin otherwise (HTML
/// "API for a and area elements"). Chrome 154 rejects SVG extraction;
/// Safari 27 supports it (aligned stable WPT, 2026-10-06: 1/51 vs 51/51).
/// Firefox does not ship Origin, so the shipping-browser tie follows SVG.
fn extractOrigin(instance: *runtime.Instance) !?*@import("dom").origin_record.OriginRecord {
    // Share SVGAnimatedString's scalar reflection steps without acquiring a
    // cached animated object that a native caller never wraps or owns.
    const href = (try @import("dom").reflected_with_fallback.value(instance, "href", xlink_namespace)) orelse return null;
    const serialized = (try @import("dom").encoding_parse.encodingParseAndSerialize(instance, href)) orelse return null;
    defer instance.ctx.allocator.free(serialized);
    return @import("dom").extract_origin.ownedRecordForUrl(instance.ctx.allocator, serialized);
}

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    // Through its ancestors: SVGElement's init chains to Element, Node and
    // EventTarget, whose state an a element in a tree needs. (SVGGraphicsElement,
    // between them, keeps no state.)
    return interfaces.SVGElement.initWithState(allocator, StateType, vtable, ctx);
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
    const has_href = interfaces.Element.call_hasAttribute(target, runtime.DOMString.initInterned("href")) catch false;
    const has_xlink_href = interfaces.Element.call_hasAttributeNS(target, runtime.DOMString.initInterned(xlink_namespace), runtime.DOMString.initInterned("href")) catch false;
    if (!has_href and !has_xlink_href) return;
    const navigables = @import("dom").navigables;
    // "With userInvolvement set to event's user navigation involvement."
    navigables.followHyperlink(target, @import("html").user_activation.userNavigationInvolvement(event));
}

/// Deinitialize instance, through its ancestors: SVGElement's deinit frees
/// what Element, Node and EventTarget keep.
pub fn deinit(instance: *runtime.Instance) void {
    interfaces.SVGElement.deinit(instance);
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

/// Setter for referrerPolicy
pub fn set_referrerPolicy(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}
