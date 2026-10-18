//! Clear Site Data: the `Clear-Site-Data` response header, as fetch parses
//! it (4.1 Parsing) and acts on it (4.2 "clear site data for response"),
//! which HTTP-network fetch runs for a response from the network when the
//! request includes credentials (3.2 Fetch Integration; http_fetch.zig,
//! after step 16's `Set-Cookie`).
//!
//! Fetch knows no storage. What is cleared is the request's Browser's: the
//! request carries its Browser's network context (`InternalRequest.network`,
//! as it carries the cookie jar), and the Browser gave its context a
//! `Clearer` before any realm existed (src/browser/clear_site_data.zig) -
//! Chromium's shape, where the network service hands the header to its
//! NetworkContextClient (OnClearSiteData) and the browser's
//! ClearSiteDataHandler clears each storage
//! (content/browser/browsing_data/clear_site_data_handler.cc). It runs on
//! the fetching thread before the response is returned: "data MUST be
//! cleared before rendering the response to the user".
//!
//! Only HTTP-network fetch runs it, so a response a service worker makes
//! never clears anything (5.2), and a service worker's own update fetch does
//! (1.1.4's kill switch).
//!
//! Spec: https://w3c.github.io/webappsec-clear-site-data/

const std = @import("std");
const Allocator = std.mem.Allocator;
const HeaderList = @import("../internal/header_list.zig").HeaderList;
const mixed_content = @import("../mixed_content.zig");
const origins = @import("../internal/origins.zig");

/// The header's name.
pub const header_name = "Clear-Site-Data";

/// 4.1's list of types, as a set (each is appended at most once in effect:
/// 4.2 switches on each and clearing twice is clearing once).
pub const Types = packed struct {
    cache: bool = false,
    cookies: bool = false,
    storage: bool = false,
    execution_contexts: bool = false,
    client_hints: bool = false,

    pub fn isEmpty(self: Types) bool {
        return !(self.cache or self.cookies or self.storage or self.execution_contexts or self.client_hints);
    }
};

/// What a Browser clears for an origin: 4.2 steps 4-6 for `origin` (a
/// serialized tuple origin, BORROWED for the call) and `types` (never
/// empty). Runs on the fetching thread, whichever of the Browser's threads
/// that is; it may only change shared state under that state's own lock and
/// queue what a realm must see as a task of that realm.
pub const Clearer = struct {
    context: *anyopaque,
    clear: *const fn (context: *anyopaque, origin: []const u8, types: Types) void,
};

/// 4.1 "parse response's Clear-Site-Data header", over a response's header
/// list `headers`.
///
/// The spec extracts the header list values (Fetch), which fails - and
/// clears nothing - when an element is not a quoted-string. The browsers
/// match each comma-separated element on its own and ignore what they do
/// not know, malformed or not: Chrome ClearSiteDataHandler::ParseHeader
/// (net::ClearSiteDataHeaderContents splits on ',' and trims; each element
/// is compared with its quotes, "Unrecognized type" skipped), Firefox
/// ClearSiteData::ParseHeader (nsCCharSeparatedTokenizer on ',', whitespace
/// stripped, EqualsLiteral("\"storage\"")...), WebKit
/// parseClearSiteDataHeader in HTTPParsers.cpp (split(','), trimmed, compared
/// with "\"storage\""_s...; unknown values skipped). No newer spec is
/// involved: golden rule 2, the browsers (all three). Matching is exact and
/// case-sensitive in all three.
pub fn parseHeader(headers: *const HeaderList) Types {
    // 1. Let types be an empty list.
    var types: Types = .{};
    // 2-3. Each `Clear-Site-Data` header's value, in order - several header
    // lines combine, as a header list's values do.
    for (headers.iterator()) |header| {
        if (!std.ascii.eqlIgnoreCase(header.name, header_name)) continue;
        var elements = std.mem.splitScalar(u8, header.value, ',');
        while (elements.next()) |raw| {
            // 4. For each type, the first matching statement.
            const element = std.mem.trim(u8, raw, " \t");
            if (std.mem.eql(u8, element, "\"cache\"")) {
                types.cache = true;
                types.client_hints = true;
            } else if (std.mem.eql(u8, element, "\"cookies\"")) {
                types.cookies = true;
                types.client_hints = true;
            } else if (std.mem.eql(u8, element, "\"storage\"")) {
                types.storage = true;
            } else if (std.mem.eql(u8, element, "\"executionContexts\"")) {
                types.execution_contexts = true;
            } else if (std.mem.eql(u8, element, "\"clientHints\"")) {
                types.client_hints = true;
            } else if (std.mem.eql(u8, element, "\"*\"")) {
                types = .{ .cache = true, .cookies = true, .storage = true, .client_hints = true, .execution_contexts = true };
            }
            // Anything else: an unknown type, ignored.
        }
    }
    // 5. Return types.
    return types;
}

/// 4.2 "clear site data for response", for a response whose URL is
/// `response_url` and whose header list is `headers`: `clearer` (the
/// request's Browser's) clears steps 4-6 for the response URL's origin.
pub fn clearSiteDataForResponse(allocator: Allocator, clearer: Clearer, response_url: []const u8, headers: *const HeaderList) Allocator.Error!void {
    // 1. If response's url is not an a priori authenticated URL, then
    // break. (Chrome checks network::IsUrlPotentiallyTrustworthy, WebKit
    // shouldTreatAsPotentiallyTrustworthy: the same answer for every URL
    // HTTP-network fetch sees.)
    if (!try mixed_content.isAPrioriAuthenticated(allocator, response_url)) return;
    // 2. Let types be the result of parsing response's Clear-Site-Data
    // header. Nothing recognized: nothing to clear (Chrome's ParseHeader
    // returns false, "No recognized types specified").
    const types = parseHeader(headers);
    if (types.isEmpty()) return;
    // 3. Let origin be response's url's origin. An opaque one names no
    // storage (Chrome: "Not supported for unique origins").
    const origin = origins.serializedOriginOf(allocator, response_url) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        // No origin to serialize: nothing to clear.
        else => return,
    };
    defer allocator.free(origin);
    if (std.mem.eql(u8, origin, "null")) return;
    // 4-6. Prepare, clear each type, reload: the Browser's.
    clearer.clear(clearer.context, origin, types);
}
