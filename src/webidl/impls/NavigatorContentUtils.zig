//! Implementation for NavigatorContentUtils interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const dom = @import("dom");
const NavigatorContentUtils = interfaces.NavigatorContentUtils;

pub const State = NavigatorContentUtils.State;

pub const ImplError = error{
    NotImplemented,
    SecurityError,
    SyntaxError,
    InvalidStateError,
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
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    // TODO: Initialize your instance state here if needed
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // TODO: Clean up your instance resources here
    _ = instance; // GC layer handles slab freeing - do NOT call runtime.Instance.deinit()
}

/// Operation: unregisterProtocolHandler (HTML 8.10.1.4).
pub fn call_unregisterProtocolHandler(instance: *runtime.Instance, scheme: runtime.DOMString, url: runtime.USVString) anyerror!void {
    // 1. "Let (normalizedScheme, normalizedURLString) be the result of
    // running normalize protocol handler parameters with scheme, url, and
    // this's relevant settings object."
    try normalizeProtocolHandlerParameters(instance, scheme.asSlice(), url);
    // 2. "In parallel: unregister the handler described by normalizedScheme
    // and normalizedURLString." - this user agent registered none
    // (registerProtocolHandler), so there is nothing to unregister.
}

/// Operation: registerProtocolHandler (HTML 8.10.1.4).
pub fn call_registerProtocolHandler(instance: *runtime.Instance, scheme: runtime.DOMString, url: runtime.USVString) anyerror!void {
    // 1. Normalize the parameters: the exceptions are web-observable.
    try normalizeProtocolHandlerParameters(instance, scheme.asSlice(), url);
    // 2. "In parallel: register a protocol handler ... User agents may,
    // within the constraints described, do whatever they like ... or cancel
    // the request." Headless Crane has no user to accept a registration and
    // uses no handler for a navigation, so it declines the request: nothing
    // is kept and nothing is observable (the registerProtocolHandler()
    // automation mode, a WebDriver extension, is not modelled).
}

/// The safelisted schemes (HTML 8.10.1.4, "normalize protocol handler
/// parameters" step 2).
const safelisted_schemes = std.StaticStringMap(void).initComptime(.{
    .{ "bitcoin", {} }, .{ "ftp", {} },         .{ "ftps", {} },   .{ "geo", {} },    .{ "im", {} },   .{ "irc", {} },
    .{ "ircs", {} },    .{ "magnet", {} },      .{ "mailto", {} }, .{ "matrix", {} }, .{ "mms", {} },  .{ "news", {} },
    .{ "nntp", {} },    .{ "openpgp4fpr", {} }, .{ "sftp", {} },   .{ "sip", {} },    .{ "sms", {} },  .{ "smsto", {} },
    .{ "ssh", {} },     .{ "tel", {} },         .{ "urn", {} },    .{ "webcal", {} }, .{ "wtai", {} }, .{ "xmpp", {} },
});

/// HTML 8.10.1.4 "normalize protocol handler parameters" given `scheme`,
/// `url` and the relevant settings object of `navigator`: its exceptions.
/// (The normalized pair itself is used by no step: the request is declined.)
fn normalizeProtocolHandlerParameters(navigator: *runtime.Instance, scheme: []const u8, url: []const u8) anyerror!void {
    const allocator = navigator.ctx.allocator;
    // 1. "Set scheme to scheme, converted to ASCII lowercase."
    const lower = try std.ascii.allocLowerString(allocator, scheme);
    defer allocator.free(lower);
    // 2. "If scheme is neither a safelisted scheme nor a string starting
    // with "web+" followed by one or more ASCII lower alphas, then throw a
    // "SecurityError" DOMException."
    if (!safelisted_schemes.has(lower) and !isWebPlusScheme(lower)) return error.SecurityError;
    // 3. "If url does not contain "%s", then throw a "SyntaxError"."
    if (std.mem.indexOf(u8, url, "%s") == null) return error.SyntaxError;
    // 4. "Let urlRecord be the result of encoding-parsing a URL given url,
    // relative to environment" - a Window's: its associated Document.
    const global = relevantGlobal(navigator) orelse return error.InvalidStateError;
    const document = (interfaces.Window.get_document(global) catch null) orelse return error.InvalidStateError;
    // 5. "If urlRecord is failure, then throw a "SyntaxError"."
    const serialized = (try dom.encoding_parse.encodingParseAndSerializeWithAllocator(allocator, document, url)) orelse return error.SyntaxError;
    defer allocator.free(serialized);
    // 6. "If urlRecord's scheme is not an HTTP(S) scheme or urlRecord's
    // origin is not same origin with environment's origin, then throw a
    // "SecurityError"." Both origins serialized; an opaque one ("null") is
    // same origin with no other.
    if (!std.mem.startsWith(u8, serialized, "http:") and !std.mem.startsWith(u8, serialized, "https:")) return error.SecurityError;
    const record = (try interfaces.URL.call_static_parse(navigator, serialized, webidl.Opt(runtime.USVString).notPassed())) orelse return error.SyntaxError;
    defer runtime.Instance.deinit(record);
    const url_origin = try interfaces.URL.get_origin(record);
    defer allocator.free(url_origin);
    const environment_origin = try interfaces.Window.get_origin(global);
    defer allocator.free(environment_origin);
    if (std.mem.eql(u8, environment_origin, "null") or !std.mem.eql(u8, url_origin, environment_origin)) return error.SecurityError;
    // 7. The URL is potentially trustworthy: implied by step 6 in a secure
    // context ([SecureContext] interface).
}

/// "a string starting with "web+" followed by one or more ASCII lower
/// alphas".
fn isWebPlusScheme(scheme: []const u8) bool {
    if (!std.mem.startsWith(u8, scheme, "web+") or scheme.len == 4) return false;
    for (scheme[4..]) |c| if (!std.ascii.isLower(c)) return false;
    return true;
}

/// The Navigator's relevant global object, a Window (NavigatorContentUtils
/// is exposed on Window only).
fn relevantGlobal(navigator: *runtime.Instance) ?*runtime.Instance {
    const realm = navigator.ctx.getRealm() orelse return null;
    const global: *runtime.Instance = @ptrCast(@alignCast(realm.global_object orelse return null));
    if (global.stateAs(interfaces.Window.State) == null) return null;
    return global;
}
