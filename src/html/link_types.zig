//! A link element's link types and `as`/`type` attribute rules, as its
//! "fetch and process the linked resource" steps read them (HTML 4.6.7) -
//! shared by the link element and the speculative HTML parser (13.2.8: a
//! speculative link fetches only what the element would).
//!
//! Moved unchanged from src/webidl/impls/HTMLLinkElement.zig (lane pscan1):
//! a helper two callers share lives outside src/webidl/impls/ (the impls
//! boundary).
//!
//! Spec: https://html.spec.whatwg.org/multipage/links.html#linkTypes

const std = @import("std");

pub const LinkType = enum { none, stylesheet, preload, modulepreload, prefetch, icon };

/// The `as` attribute's state, a potential destination, as a destination;
/// null when it is in no state. "fetch" is the empty destination, which is
/// not script-like.
pub fn asDestination(as: ?[]const u8) ?Destination {
    const value = as orelse return null;
    if (std.ascii.eqlIgnoreCase(value, "fetch")) return .empty;
    inline for (@typeInfo(Destination).@"enum".field_names, @typeInfo(Destination).@"enum".field_values) |field_name, field_value| {
        if (field_value != @backingInt(Destination.empty) and keywordIs(field_name, value)) {
            return @field(Destination, field_name);
        }
    }
    return null;
}

/// The destination a preload of the `as` attribute's value fetches with: its
/// state - one of the keywords `as` reflects (`potential_destinations`),
/// ASCII case-insensitively - translated ("fetch" is the empty string), or
/// null when it is in no state.
///
/// HTML's "translate a preload destination" returns null for every keyword
/// but "fetch", "font", "image", "script", "style" and "track" - 8 of the 14
/// keywords its own `as` attribute accepts (the module preload destinations)
/// - and its preload then returns with no fetch and no event, so a page that
/// sets one of them waits forever: fetch/api/request/destination/
/// fetch-destination.https.html cannot finish (wpt.fyi at 71b58bb191: Chrome
/// 30/30 and Safari 28/30 never reach the wait - their `as` reflects none of
/// those values - and Firefox 29/30). Firefox preloads every value its `as`
/// reflects, with that destination (nsNetUtil.cpp's kAsAttributeTable: json,
/// audio, video and text among them). The user's ruling (2026-11-18): Crane
/// takes Firefox's model - rel=preload runs for every value `as` accepts -
/// and keeps its reflection (every potential destination).
pub fn preloadDestination(as: ?[]const u8) ?Destination {
    const value = as orelse return null;
    for (potential_destinations) |keyword| {
        if (std.ascii.eqlIgnoreCase(value, keyword)) return asDestination(keyword);
    }
    return null;
}

pub const Destination = @import("fetch").internal.Destination;

/// The preload link type's "matches": whether the type attribute's value
/// suits `destination`. Absent or empty, or for "fetch", it does; otherwise
/// by its essence - text/css for style, a JavaScript MIME type for script,
/// image/*, font/* and text/vtt for image, font and track.
pub fn typeMatches(type_attr: ?[]const u8, destination: Destination) bool {
    const value = type_attr orelse return true;
    if (value.len == 0 or destination == .empty) return true;
    const essence = std.mem.trim(u8, value[0 .. std.mem.indexOfScalar(u8, value, ';') orelse value.len], " \t\n\x0C\r");
    var buffer: [128]u8 = undefined;
    if (essence.len > buffer.len) return false;
    const lower = std.ascii.lowerString(&buffer, essence);
    return switch (destination) {
        .style => std.mem.eql(u8, lower, "text/css"),
        .script => @import("mimesniff").predicates.isJavaScriptMimeTypeEssenceMatch(lower),
        .image => std.mem.startsWith(u8, lower, "image/"),
        .font => std.mem.startsWith(u8, lower, "font/") or std.mem.startsWith(u8, lower, "application/font-"),
        .track => std.mem.eql(u8, lower, "text/vtt"),
        else => false,
    };
}

/// Whether the space-separated `value` has `keyword`, ASCII
/// case-insensitively.
pub fn hasToken(value: []const u8, keyword: []const u8) bool {
    var tokens = std.mem.tokenizeAny(u8, value, " \t\n\x0C\r");
    while (tokens.next()) |token| {
        if (std.ascii.eqlIgnoreCase(token, keyword)) return true;
    }
    return false;
}

/// 4.2.4.2: whether the type attribute's value is a type the stylesheet
/// link type supports. Absent, it is the link type's default type,
/// text/css. The empty string is taken as the default too, as browsers do
/// (Blink's LinkStyle), and parameters do not change the type.
pub fn supportedType(value: ?[]const u8) bool {
    const v = value orelse return true;
    const essence = std.mem.trim(u8, v[0 .. std.mem.indexOfScalar(u8, v, ';') orelse v.len], " \t\n\x0C\r");
    return essence.len == 0 or std.ascii.eqlIgnoreCase(essence, "text/css");
}

/// Whether `value` is the keyword an enum field `name` stands for - its
/// underscores hyphens - ASCII case-insensitively.
pub fn keywordIs(name: []const u8, value: []const u8) bool {
    if (name.len != value.len) return false;
    for (name, value) |n, c| {
        const want: u8 = if (n == '_') '-' else n;
        if (std.ascii.toLower(c) != want) return false;
    }
    return true;
}

/// The link type a rel value makes the element fetch (`linkType`).
pub fn relLinkType(rel: ?[]const u8) LinkType {
    const value = rel orelse return .none;
    if (hasToken(value, "stylesheet")) return .stylesheet;
    if (hasToken(value, "preload")) return .preload;
    if (hasToken(value, "modulepreload")) return .modulepreload;
    if (hasToken(value, "prefetch")) return .prefetch;
    if (hasToken(value, "icon")) return .icon;
    return .none;
}

/// Fetch's potential destinations: "fetch" and the destinations.
pub const potential_destinations = [_][]const u8{
    "fetch",  "audio",         "audioworklet", "document", "embed",  "font",         "frame",
    "iframe", "image",         "json",         "manifest", "object", "paintworklet", "report",
    "script", "serviceworker", "sharedworker", "style",    "track",  "video",        "webidentity",
    "worker", "xslt",
};
