//! WPT MANIFEST.json Parser
//!
//! This module parses the official WPT MANIFEST.json file to resolve
//! test URLs to source files. The manifest is the authoritative source
//! for test discovery in WPT.
//!
//! ## Manifest Structure
//!
//! The MANIFEST.json has this structure:
//! ```json
//! {
//!   "version": 8,
//!   "url_base": "/",
//!   "items": {
//!     "testharness": {
//!       "url": {
//!         "url-searchparams.any.js": [
//!           "hash",
//!           ["url/url-searchparams.any.html", {}],
//!           ["url/url-searchparams.any.worker.html", {}]
//!         ]
//!       }
//!     }
//!   }
//! }
//! ```
//!
//! Two details of this format matter and are easy to miss:
//!
//! 1. The tree under a harness type nests to arbitrary depth. `url/` happens to
//!    be flat, but `dom/abort/...` and `html/dom/elements/...` are not, and most
//!    of the corpus lives below the second level.
//!
//! 2. A URL of `null` means the test URL *is* the source path:
//!    ```json
//!    "Node-appendChild.html": ["hash", [null, {}]]
//!    ```
//!    Only generated tests carry an explicit URL. For .any.js files, the
//!    manifest maps the source file to multiple virtual test URLs
//!    (.any.html, .any.worker.html, etc.). Roughly two thirds of the
//!    testharness corpus uses the null form.

const std = @import("std");
const Allocator = std.mem.Allocator;

const log = std.log.scoped(.wpt_manifest);

/// URL list type for storing test URLs per source file
const UrlList = std.ArrayListUnmanaged([]const u8);

/// WPT Manifest - maps test URLs to source files
pub const Manifest = struct {
    allocator: Allocator,
    /// Maps test URL (e.g., "url/url-searchparams.any.html") to source file (e.g., "url/url-searchparams.any.js")
    url_to_source: std.StringHashMap([]const u8),
    /// Maps source file to list of test URLs
    source_to_urls: std.StringHashMap(UrlList),

    pub fn init(allocator: Allocator) Manifest {
        return .{
            .allocator = allocator,
            .url_to_source = std.StringHashMap([]const u8).init(allocator),
            .source_to_urls = std.StringHashMap(UrlList).init(allocator),
        };
    }

    pub fn deinit(self: *Manifest) void {
        // Free url_to_source keys and values
        var url_iter = self.url_to_source.iterator();
        while (url_iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.url_to_source.deinit();

        // Free source_to_urls
        var source_iter = self.source_to_urls.iterator();
        while (source_iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            for (entry.value_ptr.items) |url| {
                self.allocator.free(url);
            }
            entry.value_ptr.deinit(self.allocator);
        }
        self.source_to_urls.deinit();
    }

    /// Resolve a test URL to its source file
    /// Returns null if the URL is not found in the manifest
    pub fn resolveUrlToSource(self: *Manifest, test_url: []const u8) ?[]const u8 {
        // Strip leading slash if present (WPT URLs can have leading /)
        const url = if (test_url.len > 0 and test_url[0] == '/') test_url[1..] else test_url;

        // Try exact match first
        if (self.url_to_source.get(url)) |source| {
            return source;
        }

        // If no exact match, check if this URL is the base of a URL with query parameters
        // e.g., "url/url-constructor.any.html" should match "url/url-constructor.any.html?include=file"
        var iter = self.url_to_source.iterator();
        while (iter.next()) |entry| {
            const manifest_url = entry.key_ptr.*;
            // Check if manifest URL starts with our URL and has a '?' after it
            if (manifest_url.len > url.len and
                std.mem.startsWith(u8, manifest_url, url) and
                manifest_url[url.len] == '?')
            {
                return entry.value_ptr.*;
            }
        }

        return null;
    }

    /// Get all test URLs for a source file
    pub fn getUrlsForSource(self: *Manifest, source_file: []const u8) ?[]const []const u8 {
        if (self.source_to_urls.get(source_file)) |list| {
            return list.items;
        }
        return null;
    }

    /// Total number of test URLs in the manifest.
    ///
    /// This is the authoritative denominator for a compliance score: WPT's
    /// manifest is what classifies a file as a testharness test in the first
    /// place, and it already expands `.any.js` sources into their per-global
    /// variants (`.any.html`, `.any.worker.html`, ...).
    pub fn urlCount(self: *const Manifest) usize {
        return self.url_to_source.count();
    }

    /// Number of test URLs whose path is under `dir` (for example "dom").
    pub fn urlCountUnder(self: *const Manifest, dir: []const u8) usize {
        var n: usize = 0;
        var iter = self.url_to_source.keyIterator();
        while (iter.next()) |key| {
            const url = key.*;
            if (url.len > dir.len and
                std.mem.startsWith(u8, url, dir) and
                url[dir.len] == '/')
            {
                n += 1;
            }
        }
        return n;
    }
};

/// Load and parse the WPT MANIFEST.json file
pub fn loadManifest(allocator: Allocator, wpt_root: []const u8) !Manifest {
    // Build path to MANIFEST.json
    const manifest_path = try std.fs.path.join(allocator, &.{ wpt_root, "MANIFEST.json" });
    defer allocator.free(manifest_path);

    // Read the manifest file
    const file = std.fs.cwd().openFile(manifest_path, .{}) catch |err| {
        log.warn("Could not open MANIFEST.json: {}", .{err});
        log.warn("  Path: {s}", .{manifest_path});
        log.warn("  Run 'wpt manifest' to generate it.", .{});
        return Manifest.init(allocator); // Return empty manifest
    };
    defer file.close();

    // Read file contents
    const stat = try file.stat();
    const contents = try allocator.alloc(u8, stat.size);
    defer allocator.free(contents);
    _ = try file.readAll(contents);

    return parseManifestBytes(allocator, contents);
}

/// Parse MANIFEST.json contents already held in memory.
///
/// Split out from `loadManifest` so the parsing rules can be tested without
/// a 21 MB fixture on disk.
pub fn parseManifestBytes(allocator: Allocator, contents: []const u8) !Manifest {
    var manifest = Manifest.init(allocator);
    errdefer manifest.deinit();

    // Parse JSON
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, contents, .{}) catch |err| {
        log.warn("Failed to parse MANIFEST.json: {}", .{err});
        return manifest;
    };
    defer parsed.deinit();

    const root = parsed.value;
    if (root != .object) return manifest;

    // Navigate to items.testharness
    const items = root.object.get("items") orelse return manifest;
    if (items != .object) return manifest;
    const testharness = items.object.get("testharness") orelse return manifest;

    // The testharness node is a directory tree of arbitrary depth. Walk it.
    try parseNode(allocator, &manifest, "", testharness);

    return manifest;
}

/// Recursively walk a manifest directory node.
///
/// Interior nodes are objects keyed by path segment; leaves are arrays of the
/// form `[hash, [url, extras], ...]`. `path_prefix` accumulates the segments
/// walked so far, so a leaf's prefix is its full source path (for example
/// `dom/abort/AbortSignal.any.js`).
fn parseNode(
    allocator: Allocator,
    manifest: *Manifest,
    path_prefix: []const u8,
    node: std.json.Value,
) !void {
    switch (node) {
        .object => |obj| {
            var iter = obj.iterator();
            while (iter.next()) |entry| {
                const segment = entry.key_ptr.*;
                const child_path = if (path_prefix.len == 0)
                    try allocator.dupe(u8, segment)
                else
                    try std.fmt.allocPrint(allocator, "{s}/{s}", .{ path_prefix, segment });
                defer allocator.free(child_path);

                try parseNode(allocator, manifest, child_path, entry.value_ptr.*);
            }
        },
        .array => |arr| {
            // Leaf: [hash, [url, extras], ...]. Anything shorter has no URLs.
            if (arr.items.len < 2) return;
            try addSourceUrls(allocator, manifest, path_prefix, arr.items[1..]);
        },
        else => {},
    }
}

/// Record every test URL a single source file expands into.
fn addSourceUrls(
    allocator: Allocator,
    manifest: *Manifest,
    source_path: []const u8,
    url_entries: []const std.json.Value,
) !void {
    var url_list: UrlList = .{};
    errdefer {
        for (url_list.items) |url| allocator.free(url);
        url_list.deinit(allocator);
    }

    for (url_entries) |entry| {
        if (entry != .array) continue;
        const url_array = entry.array.items;
        if (url_array.len == 0) continue;

        // WPT writes null when the test URL is simply the source path. Only
        // generated tests (.any.js and friends, which fan out into per-global
        // variants) carry an explicit URL. Two thirds of the corpus is null.
        const test_url = switch (url_array[0]) {
            .string => |s| s,
            .null => source_path,
            else => continue,
        };

        // url_to_source owns both key and value. A duplicate URL replaces the
        // value in place so the existing key stays the one the map owns.
        if (manifest.url_to_source.getEntry(test_url)) |existing| {
            const source_value = try allocator.dupe(u8, source_path);
            allocator.free(existing.value_ptr.*);
            existing.value_ptr.* = source_value;
        } else {
            const url_key = try allocator.dupe(u8, test_url);
            errdefer allocator.free(url_key);
            const source_value = try allocator.dupe(u8, source_path);
            errdefer allocator.free(source_value);
            try manifest.url_to_source.put(url_key, source_value);
        }

        try url_list.append(allocator, try allocator.dupe(u8, test_url));
    }

    if (url_list.items.len == 0) {
        url_list.deinit(allocator);
        return;
    }

    if (manifest.source_to_urls.getEntry(source_path)) |existing| {
        for (existing.value_ptr.items) |url| allocator.free(url);
        existing.value_ptr.deinit(allocator);
        existing.value_ptr.* = url_list;
    } else {
        const source_key = try allocator.dupe(u8, source_path);
        errdefer allocator.free(source_key);
        try manifest.source_to_urls.put(source_key, url_list);
    }
}

// Tests
test "Manifest init and deinit" {
    const allocator = std.testing.allocator;
    var manifest = Manifest.init(allocator);
    defer manifest.deinit();
}

test "parseManifestBytes walks nested directories" {
    const allocator = std.testing.allocator;

    // "url" is flat (file directly under the top-level dir); "dom" and "html"
    // nest, which is the shape of most of the real corpus.
    const json =
        \\{"items":{"testharness":{
        \\ "url":{"flat.any.js":["h",["url/flat.any.html",{}],["url/flat.any.worker.html",{}]]},
        \\ "dom":{"abort":{"AbortSignal.any.js":["h",["dom/abort/AbortSignal.any.html",{}]]}},
        \\ "html":{"dom":{"elements":{"deep.html":["h",["html/dom/elements/deep.html",{}]]}}}
        \\}}}
    ;

    var manifest = try parseManifestBytes(allocator, json);
    defer manifest.deinit();

    // 2 flat + 1 one-level-deep + 1 three-levels-deep
    try std.testing.expectEqual(@as(usize, 4), manifest.urlCount());

    try std.testing.expectEqualStrings(
        "url/flat.any.js",
        manifest.resolveUrlToSource("url/flat.any.html").?,
    );
    try std.testing.expectEqualStrings(
        "dom/abort/AbortSignal.any.js",
        manifest.resolveUrlToSource("dom/abort/AbortSignal.any.html").?,
    );
    try std.testing.expectEqualStrings(
        "html/dom/elements/deep.html",
        manifest.resolveUrlToSource("html/dom/elements/deep.html").?,
    );
}

test "parseManifestBytes expands .any.js into per-global variants" {
    const allocator = std.testing.allocator;

    const json =
        \\{"items":{"testharness":{
        \\ "dom":{"abort":{"a.any.js":["h",["dom/abort/a.any.html",{}],["dom/abort/a.any.worker.html",{}]]}}
        \\}}}
    ;

    var manifest = try parseManifestBytes(allocator, json);
    defer manifest.deinit();

    const urls = manifest.getUrlsForSource("dom/abort/a.any.js").?;
    try std.testing.expectEqual(@as(usize, 2), urls.len);
    try std.testing.expectEqual(@as(usize, 2), manifest.urlCountUnder("dom"));
    try std.testing.expectEqual(@as(usize, 0), manifest.urlCountUnder("url"));
}

test "parseManifestBytes treats a null URL as the source path" {
    const allocator = std.testing.allocator;

    const json =
        \\{"items":{"testharness":{
        \\ "dom":{"nodes":{"Node-appendChild.html":["h",[null,{}]]}},
        \\ "html":{"slow.html":["h",[null,{"timeout":"long"}]]}
        \\}}}
    ;

    var manifest = try parseManifestBytes(allocator, json);
    defer manifest.deinit();

    try std.testing.expectEqual(@as(usize, 2), manifest.urlCount());
    try std.testing.expectEqualStrings(
        "dom/nodes/Node-appendChild.html",
        manifest.resolveUrlToSource("dom/nodes/Node-appendChild.html").?,
    );
    try std.testing.expectEqualStrings(
        "html/slow.html",
        manifest.resolveUrlToSource("/html/slow.html").?,
    );
}

test "parseManifestBytes tolerates malformed and empty nodes" {
    const allocator = std.testing.allocator;

    const json =
        \\{"items":{"testharness":{
        \\ "a":{"short.js":["h"]},
        \\ "b":{"notarray.js":42},
        \\ "c":{"nourl.js":["h",[]]},
        \\ "d":{"ok.js":["h",["d/ok.html",{}]]}
        \\}}}
    ;

    var manifest = try parseManifestBytes(allocator, json);
    defer manifest.deinit();

    try std.testing.expectEqual(@as(usize, 1), manifest.urlCount());
    try std.testing.expectEqualStrings("d/ok.js", manifest.resolveUrlToSource("d/ok.html").?);
}

test "parseManifestBytes returns empty manifest when items.testharness is absent" {
    const allocator = std.testing.allocator;

    var manifest = try parseManifestBytes(allocator, "{\"items\":{\"reftest\":{}}}");
    defer manifest.deinit();

    try std.testing.expectEqual(@as(usize, 0), manifest.urlCount());
}

test "real MANIFEST.json is enumerated at full depth" {
    const allocator = std.testing.allocator;

    // Only meaningful when run from the repo root with the WPT checkout present.
    std.fs.cwd().access("tests/wpt/MANIFEST.json", .{}) catch return error.SkipZigTest;

    var manifest = try loadManifest(allocator, "tests/wpt");
    defer manifest.deinit();

    // Regression guard. A parser that only walked the top two levels of the
    // tree saw 7316 of 36553 URLs, and *zero* under html/ or fetch/ - both of
    // which nest immediately. Floors rather than exact counts, because the
    // upstream corpus grows.
    // Regression guards for two separate parsing bugs, using floors rather
    // than exact counts because the vendored corpus grows:
    //
    // 1. Walking only the top two levels of the tree saw 7316 of 36553 URLs,
    //    and *zero* under html/ or fetch/ - both of which nest immediately.
    // 2. Ignoring null URLs saw 12310 of 36553; null is the form used by
    //    plain .html tests, about two thirds of the corpus.
    try std.testing.expect(manifest.urlCount() > 30_000);
    try std.testing.expect(manifest.urlCountUnder("html") > 5_000);
    try std.testing.expect(manifest.urlCountUnder("fetch") > 500);
    try std.testing.expect(manifest.urlCountUnder("dom") > 500);

    // A nested test in null form: exercises both fixes at once.
    try std.testing.expectEqualStrings(
        "dom/nodes/Node-appendChild.html",
        manifest.resolveUrlToSource("dom/nodes/Node-appendChild.html").?,
    );
    // A nested test in explicit-URL form.
    try std.testing.expectEqualStrings(
        "dom/abort/AbortSignal.any.js",
        manifest.resolveUrlToSource("dom/abort/AbortSignal.any.html").?,
    );
}

test "resolveUrlToSource strips leading slash" {
    const allocator = std.testing.allocator;
    var manifest = Manifest.init(allocator);
    defer manifest.deinit();

    // Add a test mapping
    const url = try allocator.dupe(u8, "url/test.any.html");
    const source = try allocator.dupe(u8, "url/test.any.js");
    try manifest.url_to_source.put(url, source);

    // Should resolve with or without leading slash
    try std.testing.expectEqualStrings("url/test.any.js", manifest.resolveUrlToSource("url/test.any.html").?);
    try std.testing.expectEqualStrings("url/test.any.js", manifest.resolveUrlToSource("/url/test.any.html").?);
}
