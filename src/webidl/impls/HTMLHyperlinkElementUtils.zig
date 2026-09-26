//! Implementation for the HTMLHyperlinkElementUtils mixin: the URL
//! decomposition members of `a` and `area` elements.
//!
//! Spec: https://html.spec.whatwg.org/multipage/links.html#api-for-a-and-area-elements
//!
//! An element's "url" is its href content attribute parsed relative to its
//! node document ("set the url"). It is parsed afresh on every access rather
//! than cached, which is what "reinitialize url" amounts to for everything
//! but a revoked blob: URL. The components are read and written through a
//! URL object (the URL interface's getters and setters run the same basic URL
//! parser state overrides these setters name), and a setter ends with
//! "update href": the href content attribute becomes the URL, serialized.
//!
//! Its includers - HTMLAnchorElement, HTMLAreaElement - inherit these members
//! by alias; `this` is the element.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const HTMLHyperlinkElementUtils = interfaces.HTMLHyperlinkElementUtils;

const ElementImpl = @import("Element.zig");

pub const State = HTMLHyperlinkElementUtils.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for implementation-specific data. None: the url is
/// recomputed from the href attribute on every access.
pub const InternalState = struct {};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    return runtime.Instance.init(allocator, StateType, vtable, ctx);
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    _ = instance; // GC layer handles slab freeing - do NOT call runtime.Instance.deinit()
}

// =============================================================================
// The element's url
// =============================================================================

/// The href content attribute's value, borrowed from the attribute, or null.
fn hrefAttribute(element: *runtime.Instance) ?[]const u8 {
    const internal = ElementImpl.getInternal(element) orelse return null;
    const entry = internal.findAttribute(null, "href") orelse return null;
    return entry.value;
}

/// HTML "set the url": the href attribute parsed relative to the element's
/// node document, as a URL object the caller releases with
/// `runtime.Instance.deinit`; null when there is no href attribute or it does
/// not parse.
fn elementUrl(element: *runtime.Instance) ?*runtime.Instance {
    const href = hrefAttribute(element) orelse return null;
    const base = interfaces.Node.get_baseURI(element) catch return null;
    defer element.ctx.allocator.free(base);
    const base_arg = if (base.len > 0)
        webidl.Opt(runtime.USVString).passed(base)
    else
        webidl.Opt(runtime.USVString).notPassed();
    return interfaces.URL.call_static_parse(element, href, base_arg) catch null;
}

/// A component of the element's url, or `fallback` (copied) when it has none.
fn component(
    element: *runtime.Instance,
    comptime getter: fn (*runtime.Instance) anyerror!runtime.USVString,
    fallback: []const u8,
) !runtime.USVString {
    const url = elementUrl(element) orelse return element.ctx.allocator.dupe(u8, fallback);
    defer runtime.Instance.deinit(url);
    return getter(url);
}

/// Change a component of the element's url with `setter`, then "update
/// href". Nothing happens when the element has no url.
fn updateComponent(
    element: *runtime.Instance,
    value: runtime.USVString,
    comptime setter: fn (*runtime.Instance, runtime.USVString) anyerror!void,
) !void {
    const url = elementUrl(element) orelse return;
    defer runtime.Instance.deinit(url);
    try setter(url, value);
    // "Update href": set the href content attribute to the serialized url.
    const serialized = try interfaces.URL.get_href(url);
    defer url.ctx.allocator.free(serialized);
    try ElementImpl.call_setAttribute(element, runtime.DOMString.initInterned("href"), runtime.DOMString.initInterned(serialized));
}

// =============================================================================
// Getters
// =============================================================================

/// Getter for href: "1. Reinitialize url. 2. Let url be this's url. 3. If url
/// is null and this has no href content attribute, return the empty string.
/// 4. Otherwise, if url is null, return this's href content attribute's
/// value. 5. Return url, serialized."
pub fn get_href(instance: *runtime.Instance) anyerror!runtime.USVString {
    if (elementUrl(instance)) |url| {
        defer runtime.Instance.deinit(url);
        return interfaces.URL.get_href(url);
    }
    return instance.ctx.allocator.dupe(u8, hrefAttribute(instance) orelse "");
}

/// Getter for origin: the serialization of the url's origin, or "".
pub fn get_origin(instance: *runtime.Instance) anyerror!runtime.USVString {
    return component(instance, interfaces.URL.get_origin, "");
}

/// Getter for protocol: the url's scheme followed by ":", or ":".
pub fn get_protocol(instance: *runtime.Instance) anyerror!runtime.USVString {
    return component(instance, interfaces.URL.get_protocol, ":");
}

/// Getter for username.
pub fn get_username(instance: *runtime.Instance) anyerror!runtime.USVString {
    return component(instance, interfaces.URL.get_username, "");
}

/// Getter for password.
pub fn get_password(instance: *runtime.Instance) anyerror!runtime.USVString {
    return component(instance, interfaces.URL.get_password, "");
}

/// Getter for host: host and port, serialized, or "".
pub fn get_host(instance: *runtime.Instance) anyerror!runtime.USVString {
    return component(instance, interfaces.URL.get_host, "");
}

/// Getter for hostname.
pub fn get_hostname(instance: *runtime.Instance) anyerror!runtime.USVString {
    return component(instance, interfaces.URL.get_hostname, "");
}

/// Getter for port.
pub fn get_port(instance: *runtime.Instance) anyerror!runtime.USVString {
    return component(instance, interfaces.URL.get_port, "");
}

/// Getter for pathname.
pub fn get_pathname(instance: *runtime.Instance) anyerror!runtime.USVString {
    return component(instance, interfaces.URL.get_pathname, "");
}

/// Getter for search: "?" and the query, or "" when it is null or empty.
pub fn get_search(instance: *runtime.Instance) anyerror!runtime.USVString {
    return component(instance, interfaces.URL.get_search, "");
}

/// Getter for hash: "#" and the fragment, or "" when it is null or empty.
pub fn get_hash(instance: *runtime.Instance) anyerror!runtime.USVString {
    return component(instance, interfaces.URL.get_hash, "");
}

// =============================================================================
// Setters
// =============================================================================

/// Setter for href: "set this's href content attribute's value to the given
/// value."
pub fn set_href(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    try ElementImpl.call_setAttribute(instance, runtime.DOMString.initInterned("href"), runtime.DOMString.initInterned(value));
}

/// Setter for protocol: basic URL parse the value followed by ":" with the
/// scheme start state as state override, then update href.
pub fn set_protocol(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    return updateComponent(instance, value, interfaces.URL.set_protocol);
}

/// Setter for username: nothing when the url cannot have a username.
pub fn set_username(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    return updateComponent(instance, value, interfaces.URL.set_username);
}

/// Setter for password: nothing when the url cannot have a password.
pub fn set_password(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    return updateComponent(instance, value, interfaces.URL.set_password);
}

/// Setter for host: nothing when the url has an opaque path.
pub fn set_host(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    return updateComponent(instance, value, interfaces.URL.set_host);
}

/// Setter for hostname: nothing when the url has an opaque path.
pub fn set_hostname(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    return updateComponent(instance, value, interfaces.URL.set_hostname);
}

/// Setter for port: the empty string removes the port.
pub fn set_port(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    return updateComponent(instance, value, interfaces.URL.set_port);
}

/// Setter for pathname: nothing when the url has an opaque path.
pub fn set_pathname(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    return updateComponent(instance, value, interfaces.URL.set_pathname);
}

/// Setter for search: the empty string removes the query; a leading "?" is
/// dropped.
pub fn set_search(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    return updateComponent(instance, value, interfaces.URL.set_search);
}

/// Setter for hash: the empty string removes the fragment; a leading "#" is
/// dropped.
pub fn set_hash(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    return updateComponent(instance, value, interfaces.URL.set_hash);
}
