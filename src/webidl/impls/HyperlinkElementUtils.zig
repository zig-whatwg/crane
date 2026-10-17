//! Implementation for the HyperlinkElementUtils mixin: the URL
//! decomposition members of hyperlink elements - HTML's `a` and `area`,
//! SVG's `a` and MathML's `a`.
//!
//! Spec: https://html.spec.whatwg.org/multipage/links.html#api-for-a-and-area-elements
//! (4.6.3 "API for hyperlink elements")
//!
//! A hyperlink element's "url" is its href content attribute parsed relative
//! to its node document ("set the url"). It is parsed afresh on every access
//! rather than cached, which is what "reinitialize url" amounts to for
//! everything but a revoked blob: URL. The components are read and written
//! through a URL object (the URL interface's getters and setters run the same
//! basic URL parser state overrides these setters name), and a setter ends
//! with "update href": the href content attribute becomes the URL,
//! serialized.
//!
//! Its includers inherit these members by alias; `this` is the element.
//! hreflang and type are [Reflect]: the generated mixin reflects them.
//! href and target stay in HTMLHyperlinkElementUtils (HTML's `a` and `area`).

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const interfaces = @import("interfaces");
const HyperlinkElementUtils = interfaces.HyperlinkElementUtils;

// The element's href attribute, read in place (dom.element_data, which
// Element installs).
const element_data = @import("dom").element_data;
const html = @import("html");

pub const State = HyperlinkElementUtils.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for implementation-specific data. None: the url is
/// recomputed from the href attribute on every access.
pub const InternalState = struct {};

// =============================================================================
// The element's url
// =============================================================================

/// The XLink namespace, where SVG's deprecated `xlink:href` lives.
const xlink_namespace = "http://www.w3.org/1999/xlink";
const svg_namespace = "http://www.w3.org/2000/svg";

/// The href content attribute's value, borrowed from the attribute, or null.
/// SVG's `a` falls back to its deprecated xlink:href when it has no href
/// (SVG 2 16.2, the 'href' attribute of 'a', as SVGURIReference reflects it).
fn hrefAttribute(element: *runtime.Instance) ?[]const u8 {
    const data = element_data.of(element) orelse return null;
    if (element_data.getAttributeByNamespaceAndLocalName(data, null, "href")) |entry| return entry.value;
    const namespace = data.namespaceSlice() orelse return null;
    if (!std.mem.eql(u8, namespace, svg_namespace)) return null;
    const entry = element_data.getAttributeByNamespaceAndLocalName(data, xlink_namespace, "href") orelse return null;
    return entry.value;
}

/// HTML "set the url": the href attribute encoding-parsed relative to the
/// element's node document - with the document's character encoding, which
/// a query is percent-encoded with - as a URL object the caller releases
/// with `runtime.Instance.deinit`; null when there is no href attribute or
/// it does not parse.
///
/// The URL object holds the parsed URL's serialization, parsed again: every
/// non-ASCII code point of a serialized URL is percent-encoded already, so
/// that parse (UTF-8, as the URL API's always is) gives back the same URL.
fn elementUrl(element: *runtime.Instance) ?*runtime.Instance {
    const href = hrefAttribute(element) orelse return null;
    const serialized = (html.encoding_parse.encodingParseAndSerialize(element, href) catch return null) orelse return null;
    defer element.ctx.allocator.free(serialized);
    return interfaces.URL.call_static_parse(element, serialized, webidl.Opt(runtime.USVString).notPassed()) catch null;
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
    try interfaces.Element.call_setAttribute(element, runtime.DOMString.initInterned("href"), .{ .domstring = runtime.DOMString.initInterned(serialized) });
}

// =============================================================================
// Getters
// =============================================================================

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
