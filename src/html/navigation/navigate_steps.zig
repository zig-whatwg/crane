//! The decisions HTML "navigate" makes before anything is fetched.
//!
//! Spec: https://html.spec.whatwg.org/multipage/browsing-the-web.html#navigate
//!
//! "Navigate" resolves its history handling (steps 12-13), recognises a
//! fragment navigation (step 14) and a `javascript:` URL (step 20) from the
//! target URL and the navigable's active document alone. Those steps are pure
//! functions of serialized URLs, so they live here, engine-free and tested
//! with `std.testing`; the steps that fetch, create documents and fire events
//! are the engine's (`impls/HTMLIFrameElement.zig`).
//!
//! Every URL passed in is SERIALIZED - the output of the URL serializer -
//! which makes URL equality string equality and puts the fragment after the
//! first '#'.

const std = @import("std");

/// `NavigationHistoryBehavior`: what the caller of "navigate" asked for.
pub const HistoryBehavior = enum { auto, push, replace };

/// A "history handling behavior": `NavigationHistoryBehavior` resolved away
/// from "auto".
pub const HistoryHandling = enum { push, replace };

/// A navigable's "ongoing navigation": a navigation ID, "traversal", or null.
/// Spec: https://html.spec.whatwg.org/multipage/browsing-the-web.html#ongoing-navigation
pub const OngoingNavigation = union(enum) {
    none,
    id: u64,
    traversal,

    pub fn eql(self: OngoingNavigation, other: OngoingNavigation) bool {
        return switch (self) {
            .none => other == .none,
            .traversal => other == .traversal,
            .id => |a| switch (other) {
                .id => |b| a == b,
                else => false,
            },
        };
    }
};

/// `url` without its fragment: everything before the first '#'.
pub fn withoutFragment(url: []const u8) []const u8 {
    const hash = std.mem.indexOfScalar(u8, url, '#') orelse return url;
    return url[0..hash];
}

/// `url`'s fragment - what follows the first '#' - or null when it has none.
/// An empty fragment ("x#") is the empty string, not null.
pub fn fragmentOf(url: []const u8) ?[]const u8 {
    const hash = std.mem.indexOfScalar(u8, url, '#') orelse return null;
    return url[hash + 1 ..];
}

/// URL "equals" with *exclude fragments* set to true.
pub fn equalsExcludingFragments(a: []const u8, b: []const u8) bool {
    return std.mem.eql(u8, withoutFragment(a), withoutFragment(b));
}

/// The scheme of a serialized URL (lowercase, as the serializer writes it),
/// or the empty string when there is no ':'.
pub fn schemeOf(url: []const u8) []const u8 {
    const colon = std.mem.indexOfScalar(u8, url, ':') orelse return "";
    return url[0..colon];
}

/// URL "matches about:blank": its scheme is "about", its path is "blank",
/// and it has no username, password or host. The query and fragment may be
/// anything - `about:blank?foo#bar` matches.
/// Spec: https://html.spec.whatwg.org/multipage/urls-and-fetching.html#matches-about:blank
pub fn matchesAboutBlank(url: []const u8) bool {
    const prefix = "about:blank";
    if (!std.mem.startsWith(u8, url, prefix)) return false;
    if (url.len == prefix.len) return true;
    return url[prefix.len] == '?' or url[prefix.len] == '#';
}

/// URL "matches about:srcdoc", the same test for the path "srcdoc".
pub fn matchesAboutSrcdoc(url: []const u8) bool {
    const prefix = "about:srcdoc";
    if (!std.mem.startsWith(u8, url, prefix)) return false;
    if (url.len == prefix.len) return true;
    return url[prefix.len] == '?' or url[prefix.len] == '#';
}

/// Whether `url`'s scheme is "javascript".
pub fn isJavascript(url: []const u8) bool {
    return std.mem.eql(u8, schemeOf(url), "javascript");
}

/// Whether `url`'s scheme is a fetch scheme: "about", "blob", "data",
/// "file", or an HTTP(S) scheme.
/// Spec: https://fetch.spec.whatwg.org/#fetch-scheme
pub fn isFetchScheme(url: []const u8) bool {
    const scheme = schemeOf(url);
    const fetch_schemes = [_][]const u8{ "about", "blob", "data", "file", "http", "https" };
    for (fetch_schemes) |s| {
        if (std.mem.eql(u8, scheme, s)) return true;
    }
    return false;
}

/// What the navigable's active document looks like to "navigate" steps 12-13.
pub const ActiveDocument = struct {
    /// Its URL, serialized.
    url: []const u8,
    /// Its "is initial about:blank".
    is_initial_about_blank: bool,
};

/// "Navigate" steps 12-13: resolve `behavior` to "push" or "replace".
///
/// Step 12: "auto" becomes "replace" when `url` equals the active document's
/// URL and the initiator is same origin with it, and "push" otherwise.
/// Step 13: "the navigation must be a replace" when `url` is a `javascript:`
/// URL or the active document is the initial about:blank - whatever was asked.
pub fn resolveHistoryHandling(
    behavior: HistoryBehavior,
    url: []const u8,
    active: ActiveDocument,
    initiator_same_origin: bool,
) HistoryHandling {
    var handling: HistoryHandling = switch (behavior) {
        .push => .push,
        .replace => .replace,
        .auto => if (std.mem.eql(u8, url, active.url) and initiator_same_origin) .replace else .push,
    };
    if (isJavascript(url) or active.is_initial_about_blank) handling = .replace;
    return handling;
}

/// "Navigate" step 14: a navigation with no document resource and no
/// response, to a URL that equals the active session history entry's URL
/// with fragments excluded and that HAS a fragment, is a fragment navigation.
pub fn isFragmentNavigation(url: []const u8, active_entry_url: []const u8, has_document_resource: bool) bool {
    if (has_document_resource) return false;
    if (fragmentOf(url) == null) return false;
    return equalsExcludingFragments(url, active_entry_url);
}
