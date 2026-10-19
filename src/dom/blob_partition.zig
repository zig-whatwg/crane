//! What a blob URL's storage partition decides outside the blob URL store
//! itself (src/file/blob_url_store.zig compares the keys):
//!
//! - the storage key of the environment a frame's blob: navigation is
//!   fetched for - its reserved environment, which is not yet a settings
//!   object (`nestedStorageKey`);
//! - HTML's noopener rule for a blob URL another site made
//!   (`forcesNoopener`).
//!
//! Shared by Window (window.open) and the navigable containers (hyperlinks,
//! frame navigations), so it lives here, reaching them through
//! dom.global_settings.
//!
//! Spec: https://w3c.github.io/FileAPI/#partitioning
//! Spec: https://html.spec.whatwg.org/multipage/nav-history-apis.html#get-noopener-for-window-open

const std = @import("std");
const runtime = @import("runtime");
const cookiestore = @import("cookiestore");
const storage = @import("storage");
const global_settings = @import("global_settings.zig");
const browser_state = @import("browser_state.zig");

/// The storage key for non-storage purposes, serialized
/// (storage.StorageKey.serialize), of a new environment of `origin` (a
/// serialized origin) nested in a container whose environment's key is
/// `container`: the container's top-level site, and HTML's "has cross-site
/// ancestor" for a window ("2-3. If parentDocument's relevant settings
/// object's has cross-site ancestor is true, then return true. 4. If
/// parentDocument's origin is not same site with window's associated
/// Document's origin, then return true. 5. Return false."). What a frame's
/// navigation to a blob URL obtains the blob for: Fetch "determining the
/// environment" is the request's reserved client, whose creation URL is the
/// blob URL and whose origin is therefore the blob URL's. OWNED (`allocator`).
pub fn nestedStorageKey(allocator: std.mem.Allocator, container: storage.StorageKey, origin: []const u8) error{OutOfMemory}![]u8 {
    const has_cross_site_ancestor = container.has_cross_site_ancestor or !try sameSite(allocator, container.origin, origin);
    return storage.StorageKey.initBorrowed(origin, container.top_level_site, has_cross_site_ancestor).serialize(allocator);
}

/// HTML "same site" for two serialized origins. Crane has no identity for an
/// opaque origin here, so one ("null") is same site with nothing: the answer
/// that shares less.
fn sameSite(allocator: std.mem.Allocator, a: []const u8, b: []const u8) error{OutOfMemory}!bool {
    if (isOpaque(a) or isOpaque(b)) return false;
    if (std.mem.eql(u8, a, b)) return true;
    return cookiestore.sameSite(allocator, a, b) catch |err| {
        if (err == error.OutOfMemory) return error.OutOfMemory;
        return false;
    };
}

fn isOpaque(origin: []const u8) bool {
    return origin.len == 0 or std.mem.eql(u8, origin, "null");
}

/// The origin a blob URL names - "blob:" + the creator's serialized origin
/// + "/" + a UUID (File API "generate a new blob URL"), fragment excluded -
/// or null for a URL of any other shape.
pub fn blobURLOrigin(url: []const u8) ?[]const u8 {
    if (url.len < "blob:".len or !std.ascii.eqlIgnoreCase(url[0.."blob:".len], "blob:")) return null;
    const rest = url["blob:".len..];
    const end = std.mem.indexOfScalar(u8, rest, '#') orelse rest.len;
    const slash = std.mem.lastIndexOfScalar(u8, rest[0..end], '/') orelse return null;
    if (slash == 0) return null;
    return rest[0..slash];
}

/// HTML "get noopener for window open" step 1, and "get an element's
/// noopener" step 3, for `url` (serialized) and the source - `source`, the
/// global whose relevant settings object is the source document's or the
/// element's: "If url's blob URL entry is not null: let blobOrigin be url's
/// blob URL entry's environment's origin; let topLevelOrigin be [the
/// source's] relevant settings object's top-level origin; if blobOrigin is
/// not same site with topLevelOrigin, then return true." The entry is the
/// one in `source`'s Browser's store, live now (Crane resolves a URL's entry
/// when it is used, not when it is parsed - row 53 Q3 (a)); its
/// environment's origin is the one the URL names. All three browsers'
/// shipping behaviour for a top-level navigation to a cross-site blob URL
/// (FileAPI/BlobURL/cross-partition-navigation.https.html: Chrome 5/5).
pub fn forcesNoopener(source: *runtime.Instance, url: []const u8) bool {
    const blob_origin = blobURLOrigin(url) orelse return false;
    const store = browser_state.existingBlobURLStoreOf(source.ctx) orelse return false;
    if (!store.hasEntry(url)) return false;
    const allocator = source.ctx.allocator;
    // An opaque or unknown top-level origin is same site with no blob's.
    const top_level_origin = (global_settings.topLevelOriginOf(source) catch return true) orelse return true;
    defer allocator.free(top_level_origin);
    return !(sameSite(allocator, blob_origin, top_level_origin) catch return true);
}

test "a nested environment's key: the container's top-level site, and a cross-site ancestor when either is" {
    const allocator = std.testing.allocator;
    const top = storage.StorageKey.initBorrowed("https://web-platform.test", "https://web-platform.test", false);

    const same = try nestedStorageKey(allocator, top, "https://www1.web-platform.test");
    defer allocator.free(same);
    try std.testing.expectEqualStrings("https://www1.web-platform.test https://web-platform.test 0", same);

    const cross = try nestedStorageKey(allocator, top, "https://not-web-platform.test");
    defer allocator.free(cross);
    try std.testing.expectEqualStrings("https://not-web-platform.test https://web-platform.test 1", cross);

    // A-in-B-in-A: the top-level site is its own, but an ancestor is
    // cross-site.
    const b_in_a = storage.StorageKey.parse(cross).?;
    const aba = try nestedStorageKey(allocator, b_in_a, "https://web-platform.test");
    defer allocator.free(aba);
    try std.testing.expectEqualStrings("https://web-platform.test https://web-platform.test 1", aba);

    const opaque_child = try nestedStorageKey(allocator, top, "null");
    defer allocator.free(opaque_child);
    try std.testing.expectEqualStrings("null https://web-platform.test 1", opaque_child);
}

test "a blob URL's origin is the text between blob: and its last slash" {
    try std.testing.expectEqualStrings("https://a.test:8443", blobURLOrigin("blob:https://a.test:8443/9b2c").?);
    try std.testing.expectEqualStrings("null", blobURLOrigin("blob:null/9b2c#frag/ment").?);
    try std.testing.expect(blobURLOrigin("https://a.test/x") == null);
    try std.testing.expect(blobURLOrigin("blob:/x") == null);
}
